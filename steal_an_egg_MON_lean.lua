-- ============================================================
-- STEAL AN EGG — SEQ (ใช้ Movement ของ monthonsova = วาปไกลไม่โดนดึงกลับ)
--   ลำดับ: ยืนเซฟโซน → วาปกองแรกหน้าเซฟโซน ยก1ใบ→วาง(ปล่อย) → ไข่เป้าหมาย(tier) อุ้มกลับบ้าน(ฝาก) → วน
--   ★ ขยับไกล = Move.TweenTo (tween+clone ไม่ lagback) | ฝาก = CFrame สั้นๆ ข้ามเส้นตอนถึงบ้าน
-- ============================================================
local BASE = "https://raw.githubusercontent.com/monthonsova/Steal-An-Egg/HEAD/"
local ROOT = "Steal-An-Egg/"
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G
-- ★ log + auto-copy คลิปบอร์ด (log เด้งเร็ว ดูไม่ทัน → ก๊อปวางมาได้เลย)
local LOGBUF, lastCopy = {}, 0
local function log(t)
    local s="[SEQ] "..tostring(t); print(s)
    LOGBUF[#LOGBUF+1]=s; if #LOGBUF>500 then table.remove(LOGBUF,1) end
    if os.clock()-lastCopy>0.4 then lastCopy=os.clock()
        local txt=table.concat(LOGBUF,"\n")
        for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
        if type(writefile)=="function" then pcall(writefile,"sae_log.txt",txt) end
    end
end

assert(type(writefile)=="function", "executor ต้องมี writefile")
local FILES = {
    "EggESP.lua","EggESP/init.lua",
    "EggESP/core/Loader.lua","EggESP/core/Config.lua","EggESP/core/Util.lua","EggESP/core/Diagnostics.lua","EggESP/core/FarmFilters.lua",
    "EggESP/automation/AutoFarm.lua","EggESP/automation/BasePenAutomation.lua","EggESP/automation/DayCycle.lua","EggESP/automation/GuardZone.lua","EggESP/automation/InventoryManager.lua","EggESP/automation/Movement.lua","EggESP/automation/Passthrough.lua","EggESP/automation/PetAutomation.lua","EggESP/automation/SpeedBypass.lua",
    "EggESP/esp/BoundingBoxPool.lua","EggESP/esp/BoundingBoxRenderer.lua","EggESP/esp/Controller.lua","EggESP/esp/DataCollector.lua","EggESP/esp/DrawingPool.lua","EggESP/esp/EggData.lua","EggESP/esp/ObstacleData.lua","EggESP/esp/PathService.lua","EggESP/esp/Renderer.lua","EggESP/esp/StackLayout.lua","EggESP/esp/TextLayout.lua","EggESP/esp/TrapData.lua","EggESP/esp/TreadmillData.lua",
    "EggESP/navigation/Pathfinder.lua",
    "EggESP/ui/FarmFilterUI.lua","EggESP/ui/Hub.lua","EggESP/ui/VoidUI.lua","EggESP/ui/VoidUIHub.lua","EggESP/ui/void_build.lua",
}
local DIRS = { "Steal-An-Egg","Steal-An-Egg/EggESP","Steal-An-Egg/EggESP/core","Steal-An-Egg/EggESP/automation","Steal-An-Egg/EggESP/esp","Steal-An-Egg/EggESP/navigation","Steal-An-Egg/EggESP/ui" }
for _,d in ipairs(DIRS) do pcall(function() if makefolder then makefolder(d) end end) end
local ok,fail=0,0
for _,f in ipairs(FILES) do
    if not (type(isfile)=="function" and isfile(ROOT..f)) then
        local o,body=pcall(function() return game:HttpGet(BASE..f) end)
        if o and type(body)=="string" and #body>0 then pcall(function() writefile(ROOT..f,body) end); ok=ok+1 else fail=fail+1 end
    else ok=ok+1 end
end
if fail>0 then warn("[SEQ] โหลดไฟล์พลาด "..fail.." — รันซ้ำ"); return end
ENV.__HUB_FORCE_DRAWING=true
pcall(function() if setthreadidentity then setthreadidentity(8) end end)

local API = loadstring(readfile(ROOT.."EggESP.lua"),"@EggESP")()
if type(API)~="table" then warn("[SEQ] init ไม่คืน API"); return end
pcall(function() local c=API.GetConfig().Runtime c.tweenSpeed=500 c.speedBypassOnAutoFarm=false end)
pcall(function() if API.Modules and API.Modules.DataCollector then API.Modules.DataCollector.Collect=function() return {} end end end)

local Move = API.Modules and API.Modules.Movement
local EggState, Assets
pcall(function() EggState = require(RS:WaitForChild("Client",10):WaitForChild("EggState",10)) end)
pcall(function() Assets   = require(RS:WaitForChild("Data",10):WaitForChild("Assets",10)) end)
print("[SEQ] Move="..tostring(Move~=nil).." EggState="..tostring(EggState~=nil).." Assets="..tostring(Assets~=nil))
if not Move or not EggState then warn("[SEQ] ❌ ขาด Move/EggState"); return end

local function hrp() return (Move.GetRootPart and Move.GetRootPart()) or (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) end

-- rarity map
local rarityOf={}
pcall(function() if Assets and Assets.Directory then for k,e in pairs(Assets.Directory) do local r=e and e.Rarity
    if type(r)=="table" then local info={name=r.DisplayName or "?",tier=r.RarityNumber or 0} rarityOf[tostring(k)]=info if e.Name then rarityOf[tostring(e.Name)]=info end end end end end)
local function rarityFor(cat) return rarityOf[tostring(cat)] or {name="?",tier=0} end

-- SeparationLine (เส้นแดง SAFE ZONE) — ฝาก = ข้ามเส้น
local line
pcall(function() local a=WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas"); line=a and a:FindFirstChild("SeparationLine") end)
local function lineNormal() local s=line.Size local n=(s.X<=s.Z) and line.CFrame.RightVector or line.CFrame.LookVector return Vector3.new(n.X,0,n.Z).Unit end
local function signedSide(pos) return (pos-line.Position):Dot(lineNormal()) end
local HOME = ENV.SAE_HOME or Vector3.new(425,70,-362)
local SAFE_SIGN = line and ((signedSide(HOME)>=0) and 1 or -1) or 1

-- noclip เฉพาะตอนข้ามเส้น (ทะลุกำแพงขอบโซน)
ENV.SAE_ALIVE=true
local noclipTemp=false
task.spawn(function()
    while ENV.SAE_ALIVE do
        if noclipTemp then local ch=player.Character if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end end end end
        RunService.Stepped:Wait()
    end
end)

-- carry state
local carrying=false
pcall(function() if EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)

local CFG={ RARITY="", MIN_TIER=0, GRAB_T=5.0, ARRIVE=6, LOOP_GAP=0.2, PRIME=true }

-- ===== อ่านไข่ (Sync จาก server = เห็นไข่ไกล/Mythic) =====
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local lastSync=0
local function fieldEggs()
    if os.clock()-lastSync>0.8 then lastSync=os.clock(); pcall(function() EggState.SyncFieldEggs() end) end
    local out={}
    local ok2,data=pcall(function() return EggState.ReadFieldEggs() end)
    if ok2 and type(data)=="table" and type(data.Records)=="table" then
        local h=hrp(); local myPos=(h and h.Position) or Vector3.new()
        for _,rec in pairs(data.Records) do
            if type(rec)=="table" and rec.Uid then
                local pos=(typeof(rec.BoundsCFrame)=="CFrame") and rec.BoundsCFrame.Position or myPos
                local rr=rarityFor(rec.AssetCategory)
                out[#out+1]={uid=rec.Uid,pos=pos,cat=tostring(rec.AssetCategory),rarity=rr.name,tier=rr.tier,slotKey=slotKey(rec),dist=(pos-myPos).Magnitude}
            end
        end
    end
    return out
end
local function frontEgg() local e=fieldEggs(); table.sort(e,function(a,b) return (a.pos-HOME).Magnitude<(b.pos-HOME).Magnitude end); return e[1] end
local function wantTier(x)
    if CFG.MIN_TIER>0 and x.tier<CFG.MIN_TIER then return false end
    local w=(CFG.RARITY or ""):lower(); if w=="" then return true end
    for name in w:gmatch("[^,]+") do if x.rarity:lower()==name:gsub("%s","") then return true end end
    return false
end
local function targetEgg()
    local e=fieldEggs(); local o={}
    for _,x in ipairs(e) do if wantTier(x) then o[#o+1]=x end end
    -- ★ tier สูงสุดก่อน แล้วเอาใบ "ไกลสุด" ของ tier นั้น (ไข่ไกลที่เลือกระดับไว้)
    table.sort(o,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist>b.dist end)
    return o[1]
end

-- ===== MOVE (monthonsova tween = ไม่ lagback) =====
local function gotoPos(pos, radius, timeout)
    radius=radius or CFG.ARRIVE; timeout=timeout or 30
    local target=Vector3.new(pos.X,pos.Y,pos.Z)
    -- ★ เรียก TweenTo ครั้งเดียว (spam ทุกเฟรม = ทำลาย clone trick → lagback)
    pcall(function() Move.TweenTo(target) end)
    local t=os.clock()
    while ENV.SAE_RUN and os.clock()-t<timeout do
        local r=hrp(); if not r then break end
        if Move.IsNear(r.Position, target, radius) then return true end
        -- re-issue เฉพาะเมื่อ tween จบแล้วแต่ยังไม่ถึง (ไม่ spam)
        local tweening = Move.IsTweening and Move.IsTweening()
        if not tweening then pcall(function() Move.TweenTo(target) end) end
        RunService.Heartbeat:Wait()
    end
    return false
end

-- ===== GRAB / DROP / CARRY-HOME =====
local function firePrompts(pos)
    if typeof(fireproximityprompt)~="function" then return end
    for _,c in ipairs(WS:GetChildren()) do
        if c.Name=="SmartPromptPart" and c:IsA("BasePart") and (c.Position-pos).Magnitude<=22 then
            for _,p in ipairs(c:GetChildren()) do if p:IsA("ProximityPrompt") then pcall(function() p.Enabled=true p.HoldDuration=0 p.MaxActivationDistance=math.max(p.MaxActivationDistance or 0,60) p.RequiresLineOfSight=false fireproximityprompt(p) end) end end
        end
    end
end
local function grab(egg)
    if carrying then return true end
    local reached=gotoPos(egg.pos, CFG.ARRIVE)
    local h=hrp(); local dleft=h and (Vector3.new(egg.pos.X,egg.pos.Y,egg.pos.Z)-h.Position).Magnitude or -1
    if not reached then log("   ⚠️ ไปไม่ถึงไข่! เหลือ "..math.floor(dleft).." studs (โดนดึงกลับ/ติดอะไร)") end
    log(("   grab: %s [%s] dist=%.0f slotKey=%s"):format(egg.cat, egg.rarity, dleft, tostring(egg.slotKey)))
    local eggV=Vector3.new(egg.pos.X,egg.pos.Y,egg.pos.Z)
    local t=os.clock(); local lastReason; local lastReTween=0
    while ENV.SAE_RUN and not carrying and os.clock()-t<CFG.GRAB_T do
        local cur=hrp(); local d=cur and (eggV-cur.Position).Magnitude or 999
        -- ★ ถ้าตำแหน่งเพี้ยน/ไกล → tween กลับไปที่ไข่ใหม่ (แก้ dist โต 4-5 = "Get closer")
        if d>CFG.ARRIVE and os.clock()-lastReTween>0.8 then lastReTween=os.clock(); pcall(function() Move.TweenTo(eggV) end) end
        -- ★ เดินจริงช้าๆ ที่ไข่ = ให้ server เห็นตำแหน่งจริง (แก้ desync)
        pcall(function() if Move.WalkTo then Move.WalkTo(eggV, 1, 30) end end)
        local okc, reason = nil, nil
        pcall(function() if EggState.CarryFieldEgg then okc, reason = EggState.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        if reason~=nil and reason~=lastReason then log("     ↳ server: "..tostring(reason)); lastReason=reason end
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    if not carrying then log("   ❌ เก็บไม่ติด ("..tostring(lastReason)..")") end
    return carrying
end
local function dropHere()
    pcall(function() if EggState.DropFieldEgg then EggState.DropFieldEgg() end end)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end
    return not carrying
end
-- ข้ามเส้นด้วย CFrame สั้นๆ (near home = ไม่ lagback) → ฝาก
local function stepCF(target, per)
    local g=0
    while g<200 and carrying do g=g+1 local h=hrp() if not h then return end local d=target-h.Position local m=d.Magnitude if m<2 then return end pcall(function() h.CFrame=CFrame.new(h.Position+d.Unit*math.min(m,per)) end) RunService.Heartbeat:Wait() end
end
local function crossOnce()
    if not line then return end
    local h=hrp(); if not h then return end
    local y=h.Position.Y; local n=lineNormal(); local safeDir=n*SAFE_SIGN
    local foot=h.Position - signedSide(h.Position)*n
    noclipTemp=true
    stepCF(Vector3.new((foot-safeDir*18).X,y,(foot-safeDir*18).Z), 7)
    stepCF(Vector3.new((foot+safeDir*40).X,y,(foot+safeDir*40).Z), 7)
    noclipTemp=false
end
local function carryHome()
    gotoPos(HOME, CFG.ARRIVE)                     -- วาปกลับบ้าน (tween ไกล ไม่ lagback)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end
    local tries=0                                 -- ฝากด้วยการข้ามเส้น (CFrame สั้น)
    while carrying and ENV.SAE_RUN and tries<5 do tries=tries+1; crossOnce() end
    return not carrying
end

-- ===== COMMANDS (bind global + getgenv) =====
local function bind(name, fn) ENV[name]=fn; pcall(function() _G[name]=fn end) end
bind("SAE_SETHOME", function() local h=hrp(); if h then ENV.SAE_HOME=h.Position; HOME=h.Position; if line then SAFE_SIGN=(signedSide(HOME)>=0) and 1 or -1 end log("ตั้ง HOME="..tostring(h.Position)) end end)
bind("SAE_TIER", function(x) CFG.RARITY=x or ""; log("target tier = "..(CFG.RARITY=="" and "ทุกระดับ(สูงสุดก่อน)" or CFG.RARITY)) end)
bind("SAE_PRIME", function(b) CFG.PRIME=(b==true); log("ยกไข่มั่วหน้าเซฟโซนก่อน = "..tostring(CFG.PRIME)) end)
bind("SAE_LIST", function()
    local e=fieldEggs(); table.sort(e,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    log("ไข่ในสนาม "..#e.." ใบ:")
    for i=1,math.min(#e,15) do local x=e[i] print(("  #%d [%s t%d] %s @%.0f"):format(i,x.rarity,x.tier,x.cat,x.dist)) end
end)
bind("SAE_STOP", function() ENV.SAE_RUN=false log("หยุด") end)
bind("SAE_KILL", function() ENV.SAE_RUN=false ENV.SAE_ALIVE=false log("ปิดหมด") end)
bind("SAE_START", function()
    ENV.SAE_RUN=true; log("▶️ START (หยุด SAE_STOP)")
    task.spawn(function()
        while ENV.SAE_RUN and ENV.SAE_ALIVE do
            gotoPos(HOME, CFG.ARRIVE)                 -- ① ยืนเซฟโซน
            if CFG.PRIME then                         -- ② (ปิดไว้) ยกไข่มั่ว 1 ใบหน้าเซฟโซนแล้ววาง — SAE_PRIME(true) เปิด
                local first=frontEgg()
                if first then log("① กองแรกหน้าเซฟโซน: "..first.cat); if grab(first) then dropHere() end end
            end
            local tgt=targetEgg()                     -- ③ ไข่ไกลระดับสูงสุด → อุ้มกลับบ้าน(ฝาก)
            if tgt then
                log("② เป้าหมาย: "..tgt.cat.." ["..tgt.rarity.."] @"..math.floor(tgt.dist))
                if grab(tgt) then log(carryHome() and "  ✅ ฝากเข้าบ้านแล้ว!" or "  ⚠️ ฝากไม่ผ่าน") else log("  ⚠️ อุ้มไม่ติด/ไปไม่ถึง") end
            else log("ไม่มีไข่ตรง tier"); task.wait(1) end
            task.wait(CFG.LOOP_GAP)
        end
        log("⏹️ หยุดลูป")
    end)
end)

log("✅ พร้อม! ยืนกลางเซฟโซน → SAE_SETHOME() → SAE_TIER(\"Mythic\") → SAE_START()   (ดูไข่: SAE_LIST())")
