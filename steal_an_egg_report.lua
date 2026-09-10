local Core=(function()
-- Pure report logic; runtime adapter supplies game values and transport.
local Core = {}
function Core.item(uid, kind, category, displayName, weight, entry, hex)
    local rarity = entry and entry.Rarity or {}
    local egg = entry and entry.Egg or {}
    return {id=tostring(uid), name=displayName or (kind=="eggs" and egg.DisplayName or entry and entry.DisplayName) or category,
        weight=weight or "", imageAsset=kind=="eggs" and egg.Icon or entry and entry.Icon,
        rarity=rarity.DisplayName or "",rarityColor=hex(rarity.Color),quantity=1}
end
local function matches(a,b)
    return a.AssetColorSeed~=nil and a.AssetScale~=nil and a.AssetCategory~=nil
        and a.AssetColorSeed==b.AssetColorSeed and a.AssetScale==b.AssetScale and a.AssetCategory==b.AssetCategory
end
local function samePosition(a,b)
    if not a or not b then return false end
    local dx,dy,dz=a[1]-b[1],a[2]-b[2],a[3]-b[3]
    return dx*dx+dy*dy+dz*dz<0.25
end
function Core.tracker(userId,emit,clock)
    local attempts={}
    local function finish(a)
        if not a.done and not a.failed and a.owner and a.gone and a.verdict then
            if emit(a)~=false then a.done=true end
        end
    end
    return {
        field=function(rec,position,weight)
            if type(rec)~="table" or not rec.Uid then return end
            local key=tostring(rec.Uid)
            local a=attempts[key]
            if a and rec.Version and a.rec.Version and rec.Version<a.rec.Version then return end
            if rec.State=="Carried" and rec.CarrierUserId==userId then
                if not a or a.failed then
                    a={rec=rec,position=position,weight=weight,started=clock()}; attempts[key]=a
                end
            elseif a and not a.done and (rec.State=="Dropped" or rec.State=="Slot" or rec.State=="GuardCarried"
                or rec.State=="Carried" and rec.CarrierUserId~=userId) then a.failed=true end
        end,
        owner=function(payload)
            if type(payload)~="table" or payload.OwnerUserId~=userId or type(payload.Records)~="table" then return end
            for _,a in pairs(attempts) do
                if not a.done and not a.failed then
                    local uid, record, count=nil,nil,0
                    for k,r in pairs(payload.Records) do
                        if type(r)=="table" and matches(a.rec,r) then uid,record,count=tostring(k),r,count+1 end
                    end
                    if count==1 then a.owner=uid; a.ownedRecord=record; finish(a) end
                end
            end
        end,
        gone=function(uid)
            local a=attempts[tostring(uid)]; if a then a.gone=true; finish(a) end
        end,
        verdict=function(payload,position)
            if type(payload)~="table" then return end
            local candidate, count=nil,0
            for _,a in pairs(attempts) do
                if not a.done and not a.failed and a.rec.AssetCategory==payload.AssetCategory
                    and samePosition(a.position,position) then candidate,count=a,count+1 end
            end
            if count==1 then candidate.verdict=payload; finish(candidate) end
        end,
        sweep=function()
            for key,a in pairs(attempts) do
                if clock()-a.started>120 then attempts[key]=nil else finish(a) end
            end
        end,
    }
end
return Core

end)()
-- Bundled after report-core.lua. Read-only game adapter; sends to the existing report API.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HTTP=game:GetService("HttpService")
local player=Players.LocalPlayer
assert(player,"Run on the game client")
local PG=player:WaitForChild("PlayerGui",10)
local ENV=(type(getgenv)=="function" and getgenv()) or _G
if type(ENV.SAE_REPORT_STOP)=="function" then pcall(ENV.SAE_REPORT_STOP) end
local active=true
local connections={}
local BASE="https://overload-backend-production.up.railway.app"
local function find(root,...)
    for _,key in ipairs({...}) do root=root and root:FindFirstChild(key) end
    return root
end
local function module(...)
    local m=find(RS,...); if not m then return nil end
    local ok,value=pcall(require,m); if ok then return value end
end
local Assets=module("Data","Assets")
local Save=module("Shared","Save")
local EggRecords=module("Shared","Util","EggRecords")
assert(Assets and Assets.Directory,"Game Assets module not ready; retry after loading")
local function hex(c)
    if typeof(c)~="Color3" then return "" end
    return string.format("#%02X%02X%02X",math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5))
end
local function position(p)
    if typeof(p)=="CFrame" then p=p.Position end
    if typeof(p)=="Vector3" then return {p.X,p.Y,p.Z} end
end
local function weightText(value)
    if type(value)=="string" and value:lower():find("kg",1,true) then return value end
    if type(value)~="number" or value~=value or value<0 or value==math.huge then return nil end
    -- Preserve measured instance weight rather than substituting the catalog's base weight.
    local s=string.format("%.2f",value):gsub("0+$",""):gsub("%.$","")
    local whole, decimal=s:match("^(%d+)(.*)$")
    if whole then s=whole:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")..decimal end
    return s.."Kg"
end
local function imageUrl(raw)
    local id=tostring(raw or ""):match("^rbxassetid://(%d+)$")
    return id and (BASE.."/api/asset-image/"..id) or ""
end
local function finishItem(row)
    row.imageUrl=imageUrl(row.imageAsset); row.imageAsset=nil
    return row
end
local state=ENV.SAE_REPORT_STATE
if type(state)~="table" or state.userId~=player.UserId then
    state={userId=player.UserId,pending={},delivered={},lastStatus="starting"}; ENV.SAE_REPORT_STATE=state
end
local function log(message) state.lastStatus=message; print("[SAE REPORT] "..message) end
local function getTools()
    local byId={}
    for _,root in pairs({backpack=player:FindFirstChild("Backpack"),character=player.Character}) do
        for _,tool in ipairs(root:GetChildren()) do
            if tool:IsA("Tool") then
                local uid=tool:GetAttribute("UID")
                if uid then byId[tostring(uid)]=tool end
            end
        end
    end
    return byId
end
local function saveData()
    if Save and type(Save.Get)=="function" then local ok,data=pcall(Save.Get); if ok and type(data)=="table" then return data end end
end
local function rowFor(uid,tool,record,kind)
    local attrs=tool and tool:GetAttributes() or {}
    record=record or {}
    local category=attrs.Category or record.AssetCategory
    local entry=category and Assets.Directory[category]
    if not entry then return nil end
    local name=tool and tool.Name or attrs.DisplayName
    if kind=="eggs" and not name then name=entry.Egg and entry.Egg.DisplayName end
    local weight=weightText(attrs.Weight) or weightText(record.Weight)
    if kind=="eggs" and EggRecords and type(EggRecords.WeightLabel)=="function" and record.AssetCategory then
        local ok,label=pcall(EggRecords.WeightLabel,record)
        if ok and type(label)=="string" then
            label=label:gsub("<[^>]->","")
            local measured=label:match("([%d,%.]+%s*[A-Za-z]*[Kk][Gg])")
            if measured then weight=measured end
        end
    end
    return finishItem(Core.item(uid,kind,category,name,weight,entry,hex))
end
local function snapshots()
    local tools=getTools()
    local data=saveData()
    local eggRecords=data and type(data.EggInventory)=="table" and data.EggInventory or nil
    local report={pets={},eggs=eggRecords and {} or nil}
    local counts={pets=0,eggs=0,missingWeight=0,unmapped=0}
    for uid,tool in pairs(tools) do
        local itemType=tool:GetAttribute("ItemType")
        local kind=itemType=="Asset" and not (eggRecords and eggRecords[uid]) and "pets" or nil
        if not eggRecords and itemType=="AssetEgg" then kind="eggs"; report.eggs=report.eggs or {} end
        if kind then
            local record=kind=="eggs" and data and data.EggInventory and data.EggInventory[uid]
            local row=rowFor(uid,tool,record,kind)
            if row then
                report[kind][#report[kind]+1]=row; counts[kind]=counts[kind]+1
                if row.weight=="" then counts.missingWeight=counts.missingWeight+1 end
            else counts.unmapped=counts.unmapped+1 end
        end
    end
    -- Eggs may be virtual inventory entries, not Instances in Backpack.
    -- Save is authoritative; omit placed/incubating eggs from the bag.
    if eggRecords then
        for uid,record in pairs(eggRecords) do
            if type(record)=="table" and record.Placement==nil then
                local row=rowFor(tostring(uid),tools[tostring(uid)],record,"eggs")
                if row then
                    report.eggs[#report.eggs+1]=row; counts.eggs=counts.eggs+1
                    if row.weight=="" then counts.missingWeight=counts.missingWeight+1 end
                else counts.unmapped=counts.unmapped+1 end
            end
        end
    end
    -- Do not erase a bag when the client inventory is still loading.
    if not data or not player:FindFirstChild("Backpack") then
        if #report.pets==0 then report.pets=nil end
        if report.eggs and #report.eggs==0 then report.eggs=nil end
    end
    if counts.unmapped>0 then report.pets=nil; report.eggs=nil end
    for _,kind in ipairs({"pets","eggs"}) do
        if report[kind] then
            table.sort(report[kind],function(a,b)return a.id<b.id end)
            if #report[kind]>200 then report[kind]=nil; counts.unmapped=counts.unmapped+1 end
        end
    end
    return report,counts,tools
end
local function modelWeight(uid)
    local model=workspace:FindFirstChild(tostring(uid))
        or find(workspace,"AreaEggSlotsClient",tostring(uid))
    if not model then return nil end
    local direct=weightText(model:GetAttribute("Weight")); if direct then return direct end
    for _,obj in ipairs(model:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local text=obj.Text:gsub("<[^>]->","")
            local measured=text:match("([%d,%.]+%s*[A-Za-z]*[Kk][Gg])")
            if measured then return measured end
        end
    end
end
local tracker=Core.tracker(player.UserId,function(a)
    local eventId="sae:"..player.UserId..":"..a.owner
    if state.delivered[eventId] or state.pending[eventId] then return true end
    local count=0; for _ in pairs(state.pending) do count=count+1 end
    if count>=100 then log("Pending queue full; waiting for server acknowledgement"); return false end
    local tools=getTools()
    local data=saveData()
    local record=data and data.EggInventory and data.EggInventory[a.owner] or a.ownedRecord
    local row=rowFor(a.owner,tools[a.owner],record,"eggs")
    if not row then log("Cannot resolve collected category "..tostring(a.rec.AssetCategory)); return false end
    row.id=eventId
    row.name=a.verdict.DisplayName or row.name
    row.rarity=a.verdict.Rarity or row.rarity
    row.rarityColor=hex(a.verdict.Color)
    if row.weight=="" then row.weight=a.weight or "" end
    row.collectedAt=os.date("!%Y-%m-%dT%H:%M:%SZ")
    state.pending[eventId]=row
    state.lastCollectedRecord=record
    log("Collected "..row.name.." | "..(row.weight~="" and row.weight or "weight unavailable").." | "..row.rarity)
    return true
end,os.clock)
local net=find(RS,"Packages","Networking")
assert(net,"Game networking not ready")
local handlers={
    FieldEggShifted=function(rec)
        tracker.field(rec,type(rec)=="table" and position(rec.BottomCFrame),type(rec)=="table" and modelWeight(rec.Uid))
    end,
    OwnerShifted=tracker.owner,
    FieldEggGone=tracker.gone,
    FieldEggRedeemVerdict=function(rec)tracker.verdict(rec,type(rec)=="table" and position(rec.Position))end,
}
for name,handler in pairs(handlers) do
    local remote=net:FindFirstChild("RE/EggWorld/"..name)
    if remote and remote:IsA("RemoteEvent") then
        connections[#connections+1]=remote.OnClientEvent:Connect(function(...)if active then local ok,err=pcall(handler,...); if not ok then log(tostring(err)) end end end)
    else log("Missing event "..name) end
end
local function hud(kind)
    for _,name in ipairs({"GameHUD","TradmilHud"}) do
        local label=find(PG,"HUD",name,"BottomLeft",kind,"Value")
        if label and label.Text~="" then return label.Text:gsub("<[^>]->","") end
    end
end
local busy=false
local diagnosticsCopied=false
local function send()
    if not active or busy then return end
    busy=true
    local ok,err=pcall(function()
        tracker.sweep()
        local report,counts,tools=snapshots()
        local saved=saveData()
        local batch={}
        for id,row in pairs(state.pending) do
            -- Enrich a pending pickup when its exact owned Tool becomes available.
            if row.weight=="" then
                local uid=id:match("([^:]+)$")
                local tool=tools[uid]
                local record=saved and saved.EggInventory and saved.EggInventory[uid]
                local refreshed=rowFor(uid,tool,record,"eggs")
                if refreshed then row.weight=refreshed.weight end
            end
            batch[#batch+1]=row
        end
        report.collectedEggs=#batch>0 and batch or nil
        local money,speed=hud("Money"),hud("Speed")
        local payload={username=player.Name,userId=player.UserId,gameId="steal_an_egg",serviceName="Steal An Egg",farming=true,
            currentStats={money=money,speed=speed},stealReport=report,
            matchInfo={map=tostring(player:GetAttribute("AreaId") or "Steal An Egg"),wave=0,playerCount=#Players:GetPlayers()}}
        -- Empty Lua tables encode as objects: explicitly encode known empty bags as arrays.
        for _,kind in ipairs({"pets","eggs"}) do if report[kind] and #report[kind]==0 then report[kind]="__SAE_EMPTY_ARRAY__" end end
        local body=HTTP:JSONEncode(payload):gsub('"__SAE_EMPTY_ARRAY__"','[]')
        local requestFn=request or http_request or (syn and syn.request)
        local response
        if type(requestFn)=="function" then response=requestFn({Url=BASE.."/api/overload/update",Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
        else response=HTTP:RequestAsync({Url=BASE.."/api/overload/update",Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end
        local code=tonumber(response and response.StatusCode)
        if not code or code<200 or code>=300 then error("HTTP "..tostring(code).." "..tostring(response and response.Body):sub(1,150)) end
        for _,row in ipairs(batch) do state.pending[row.id]=nil; state.delivered[row.id]=os.clock() end
        for id,at in pairs(state.delivered) do if os.clock()-at>3600 then state.delivered[id]=nil end end
        log(string.format("SENT | Pets %d | Eggs %d | Pickups %d | Missing weight %d | Unmapped %d",counts.pets,counts.eggs,#batch,counts.missingWeight,counts.unmapped))
        if not diagnosticsCopied and counts.missingWeight>0 and ENV.SAE_REPORT_DIAGNOSTICS then
            diagnosticsCopied=true
            ENV.SAE_REPORT_DIAGNOSTICS()
        end
    end)
    busy=false
    if not ok then log("Send failed; retry queue kept: "..tostring(err)) end
end
ENV.SAE_REPORT_STOP=function()active=false; for _,c in ipairs(connections)do c:Disconnect()end end
ENV.SAE_REPORT_ONCE=send
ENV.SAE_REPORT_DIAGNOSTICS=function()
    local function safe(value,depth)
        depth=depth or 0
        if type(value)=="number" then return value==value and math.abs(value)<math.huge and value or tostring(value) end
        if type(value)=="string" then return value:sub(1,160) end
        if type(value)=="boolean" or value==nil then return value end
        if type(value)=="function" then
            local ok,args=pcall(debug.info,value,"a")
            return ok and ("function args="..tostring(args)) or "function"
        end
        if type(value)~="table" then return tostring(value):sub(1,160) end
        if depth>=3 then return "table" end
        local out,count={},0
        for k,v in pairs(value) do count=count+1;if count>30 then out._truncated=true;break end;out[tostring(k)]=safe(v,depth+1) end
        return out
    end
    local data={version="1.2",status=state.lastStatus,tools={},eggRecords={},lastCollected=safe(state.lastCollectedRecord)}
    for uid,tool in pairs(getTools()) do
        if tool:GetAttribute("ItemType")=="AssetEgg" and #data.tools<3 then data.tools[#data.tools+1]={id=uid,name=tool.Name,attrs=safe(tool:GetAttributes())} end
    end
    local save=saveData()
    if save and type(save.EggInventory)=="table" then
        for uid,rec in pairs(save.EggInventory) do
            if type(rec)=="table" and rec.Placement==nil and #data.eggRecords<3 then
                data.eggRecords[#data.eggRecords+1]={id=tostring(uid),record=safe(rec)}
            end
        end
    end
    data.eggFunctions=safe(module("Shared","Types","Eggs"))
    data.assetWeightFunctions={}
    for k,v in pairs(Assets) do
        local key=tostring(k):lower()
        if key:find("weight",1,true) or key:find("scale",1,true) then data.assetWeightFunctions[tostring(k)]=safe(v) end
    end
    local ok,text=pcall(HTTP.JSONEncode,HTTP,data)
    if ok then
        text="SAE_REPORT_DIAGNOSTICS\n"..text
        ENV.SAE_REPORT_DIAGNOSTICS_RESULT=text
        local copy=setclipboard or toclipboard
        if type(copy)=="function" then pcall(copy,text) end
        print(text)
        print("[SAE REPORT] Diagnostics copied. Paste into Codex.")
    else print("[SAE REPORT] Diagnostics failed: "..tostring(text)) end
end
log("v1.2 loaded. Egg weights from game EggRecords.WeightLabel; existing notifier and farming continue.")
task.spawn(function()
    task.wait(3)
    while active do send(); for _=1,15 do if not active then break end; task.wait(1) end end
end)
