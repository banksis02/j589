-- ============================================================
-- STEAL AN EGG — SEQUENCE (ตัวเองล้วน ไม่พึ่ง monthonsova = ไม่พังเพราะของเขา)
--   ปิด ObbyAntiTP เอง (ไม่โดนดึงกลับ) + ขยับ CFrame เอง
--   ลำดับ: ยืนเซฟโซน → วาปไปไข่จุดแรก อุ้ม → ปล่อยตรงนั้น → วาปไปไข่เป้าหมาย อุ้ม → ปล่อย → วน
-- ============================================================
local SCRIPT_VERSION = "v3.0"
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G

local function log(t) print("[SEQ "..SCRIPT_VERSION.."] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h=hum() return h~=nil and h.Health>0 end

-- ===== require game modules =====
local EggState, Assets
pcall(function() EggState = require(RS:WaitForChild("Client",10):WaitForChild("EggState",10)) end)
pcall(function() Assets   = require(RS:WaitForChild("Data",10):WaitForChild("Assets",10)) end)
log("EggState="..tostring(EggState~=nil).." Assets="..tostring(Assets~=nil))

-- rarity map
local rarityOf = {}
pcall(function()
    if Assets and Assets.Directory then
        for k,e in pairs(Assets.Directory) do
            local r = e and e.Rarity
            if type(r)=="table" then
                local info = { name=r.DisplayName or "?", tier=r.RarityNumber or 0 }
                rarityOf[tostring(k)] = info
                if e.Name then rarityOf[tostring(e.Name)] = info end
            end
        end
    end
end)
local function rarityFor(cat) return rarityOf[tostring(cat)] or {name="?",tier=0} end

-- ===== ปิด ObbyAntiTP (กันโดนดึงกลับ/lagback) =====
local MARK = {"ObbyAntiTP","ObbyAntiTp"}
local NEU  = {check=true,lagback=true,punish=true,kill=true}
local function srcAnti(s) if type(s)~="string" then return false end for _,m in ipairs(MARK) do if s:find(m,1,true) then return true end end return false end
local metaHook,oldNC,disC,hookF = false,nil,{},{}
ENV.SAE_BLOCK_PIVOT = true
local function destroyAnti(root)
    if not root then return end
    for _,i in ipairs(root:GetDescendants()) do
        if i.Name=="ObbyAntiTPClient" and i:IsA("LocalScript") then pcall(function() i.Disabled=true i:Destroy() end) end
    end
end
local function installHook()
    if metaHook or typeof(getrawmetatable)~="function" then return end
    local ok,mt = pcall(getrawmetatable, game)
    if not ok or not mt or typeof(mt.__namecall)~="function" then return end
    oldNC = mt.__namecall; pcall(setreadonly, mt, false)
    mt.__namecall = function(self,...)
        if getnamecallmethod()=="PivotTo" and ENV.SAE_BLOCK_PIVOT and (self==player.Character or self==hrp()) then return self end
        return oldNC(self,...)
    end
    pcall(setreadonly, mt, true); metaHook=true
end
local function neuter()
    if typeof(getgc)~="function" or typeof(hookfunction)~="function" then return end
    pcall(function()
        for _,fn in ipairs(getgc(true)) do
            if type(fn)=="function" and not hookF[fn] then
                local a,n = pcall(debug.info, fn, "n")
                local b,s = pcall(debug.info, fn, "s")
                if a and NEU[n] and b and srcAnti(s) then hookF[fn]=hookfunction(fn,function() return nil end) end
            end
        end
    end)
end
local function discSig()
    if typeof(getconnections)~="function" then return end
    for _,sig in ipairs({RunService.Heartbeat, RunService.Stepped}) do
        pcall(function()
            for _,c in ipairs(getconnections(sig)) do
                local f=c.Function
                if f then local ok,s=pcall(debug.info,f,"s") if ok and srcAnti(s) and not disC[c] then pcall(function() c:Disable() end) disC[c]=true end end
            end
        end)
    end
end
local function applyBypass()
    pcall(function() WS:SetAttribute("ClientObbyAntiTp", false) end)
    neuter(); discSig()   -- ❌ ตัด installHook (__namecall hook = เสี่ยง BAC ตาม memory)
    destroyAnti(player:FindFirstChild("PlayerScripts")); destroyAnti(player.Character)
end
pcall(applyBypass)
player.CharacterAdded:Connect(function() task.wait(0.5); pcall(applyBypass) end)

-- ===== MOVEMENT: flight controller (CFrame ทุกเฟรม + noclip; ถือตำแหน่ง=ไม่ตกแมพ) =====
local CFG = { FLY_SPEED=380, STAND_Y=3, GRAB_T=3.0, ARRIVE=4, LOOP_GAP=0.2, RARITY="", MIN_TIER=0 }
local HOME = ENV.SAE_HOME or Vector3.new(425,70,-362)
ENV.SAE_ALIVE = true
local MOVE_GOAL = nil
task.spawn(function()   -- noclip
    while ENV.SAE_ALIVE do
        local ch=player.Character
        if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end end end
        RunService.Stepped:Wait()
    end
end)
task.spawn(function()   -- flight
    while ENV.SAE_ALIVE do
        local dt = RunService.Heartbeat:Wait()
        local h = hrp()
        if h then
            if MOVE_GOAL==nil then MOVE_GOAL=h.Position end
            local d = MOVE_GOAL - h.Position; local m = d.Magnitude
            local np = (m<=CFG.FLY_SPEED*dt or m<1) and MOVE_GOAL or (h.Position + d.Unit*(CFG.FLY_SPEED*dt))
            pcall(function() h.CFrame = CFrame.new(np) end)
        end
    end
end)
local function flyTo(pos, arrive)
    MOVE_GOAL = Vector3.new(pos.X, pos.Y+CFG.STAND_Y, pos.Z)
    local dl = os.clock()+20
    while ENV.SAE_ALIVE and alive() do
        local h=hrp(); if not h then return false end
        if (MOVE_GOAL-h.Position).Magnitude < (arrive or 3) then return true end
        if os.clock()>dl then return false end
        RunService.Heartbeat:Wait()
    end
    return false
end

-- ===== EGGS =====
local carrying = false
pcall(function() if EggState and EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local lastSync=0
local function fieldEggs()
    -- ★ ดึงสนามเต็มจาก server (ReadFieldEggs cache มีแต่ไข่ใกล้ตัว = ไม่เห็นไข่ไกล/Mythic)
    if os.clock()-lastSync>0.8 then lastSync=os.clock(); pcall(function() EggState.SyncFieldEggs() end) end
    local out={}
    local ok,data = pcall(function() return EggState and EggState.ReadFieldEggs() end)
    if ok and type(data)=="table" and type(data.Records)=="table" then
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
local function nearestEgg() local e=fieldEggs(); table.sort(e,function(a,b) return a.dist<b.dist end); return e[1] end
-- กองแรกหน้าเซฟโซน = ไข่ที่อยู่ใกล้ HOME(เซฟโซน)ที่สุด
local function frontEgg()   local e=fieldEggs(); table.sort(e,function(a,b) return (a.pos-HOME).Magnitude<(b.pos-HOME).Magnitude end); return e[1] end
local function wantTier(x)
    if CFG.MIN_TIER>0 and x.tier<CFG.MIN_TIER then return false end
    local w=(CFG.RARITY or ""):lower(); if w=="" then return true end
    for name in w:gmatch("[^,]+") do if x.rarity:lower()==name:gsub("%s","") then return true end end
    return false
end
local function targetEgg()
    local e=fieldEggs(); local o={}
    for _,x in ipairs(e) do if wantTier(x) then o[#o+1]=x end end
    table.sort(o,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    return o[1]
end

-- ===== GRAB + DROP =====
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
    flyTo(egg.pos, CFG.ARRIVE)
    local t=os.clock()
    while ENV.SAE_RUN and not carrying and os.clock()-t<CFG.GRAB_T do
        pcall(function() if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    return carrying
end
local function dropHere()
    pcall(function() if EggState and EggState.DropFieldEgg then EggState.DropFieldEgg() end end)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end
    return not carrying
end

-- ===== เอากลับบ้าน (ฝากข้ามเส้น SeparationLine) สำหรับไข่เป้าหมาย =====
local line
pcall(function() local a=WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas"); line=a and a:FindFirstChild("SeparationLine") end)
local function lineNormal() local s=line.Size local n=(s.X<=s.Z) and line.CFrame.RightVector or line.CFrame.LookVector return Vector3.new(n.X,0,n.Z).Unit end
local function signedSide(pos) return (pos-line.Position):Dot(lineNormal()) end
local SAFE_SIGN = line and ((signedSide(HOME)>=0) and 1 or -1) or 1
-- ข้ามเส้น 1 ครั้ง (ไปฝั่งสนาม→ข้ามกลับฝั่งเซฟ ด้วย flight controller = ขยับตัวจริง = server เห็นการข้าม)
local function crossOnce()
    if not line then return end
    local h=hrp(); if not h then return end
    local y=h.Position.Y; local n=lineNormal(); local safeDir=n*SAFE_SIGN
    local foot=h.Position - signedSide(h.Position)*n
    local fieldP=Vector3.new((foot-safeDir*18).X, y, (foot-safeDir*18).Z)
    local safeP =Vector3.new((foot+safeDir*40).X, y, (foot+safeDir*40).Z)
    MOVE_GOAL=fieldP
    local t=os.clock(); while carrying and os.clock()-t<1.2 do local hh=hrp() if hh and (fieldP-hh.Position).Magnitude<3 then break end RunService.Heartbeat:Wait() end
    MOVE_GOAL=safeP
    local t2=os.clock(); while carrying and os.clock()-t2<1.5 do RunService.Heartbeat:Wait() end
end
local function carryHome()
    flyTo(HOME, CFG.ARRIVE)                       -- บินกลับบ้าน (ข้ามเส้นระหว่างทาง = ฝาก)
    local t=os.clock(); while carrying and os.clock()-t<2 do RunService.Heartbeat:Wait() end
    local tries=0                                 -- ยังไม่ฝาก → ข้าม explicit ซ้ำ
    while carrying and ENV.SAE_RUN and tries<5 do tries=tries+1; crossOnce() end
    return not carrying
end

-- ===== COMMANDS (bind แน่นอน) =====
ENV.SAE_SETHOME = function() local h=hrp(); if h then ENV.SAE_HOME=h.Position; HOME=h.Position; if line then SAFE_SIGN=(signedSide(HOME)>=0) and 1 or -1 end log("ตั้ง HOME(เซฟโซน)="..tostring(h.Position)) end end
ENV.SAE_TIER    = function(x) CFG.RARITY=x or ""; log("target tier = "..(CFG.RARITY=="" and "ทุกระดับ" or CFG.RARITY)) end
ENV.SAE_LIST    = function()
    local e=fieldEggs(); table.sort(e,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    log("ไข่ในสนาม "..#e.." ใบ:")
    for i=1,math.min(#e,12) do local x=e[i] print(("  #%d [%s t%d] %s @%.0f"):format(i,x.rarity,x.tier,x.cat,x.dist)) end
end
ENV.SAE_STOP    = function() ENV.SAE_RUN=false log("หยุด") end
ENV.SAE_KILL    = function() ENV.SAE_RUN=false ENV.SAE_ALIVE=false log("ปิดหมด") end
ENV.SAE_START   = function()
    ENV.SAE_RUN=true; log("▶️ START — ยืนเซฟโซน→วาปเก็บใบแรกปล่อย→วาปเก็บเป้าหมายปล่อย (หยุด SAE_STOP)")
    task.spawn(function()
        while ENV.SAE_RUN and ENV.SAE_ALIVE and alive() do
            flyTo(HOME, CFG.ARRIVE)                       -- ① ยืนหน้าจุดเซฟโซน
            local first=frontEgg()                        -- ② วาปไปกองแรกหน้าเซฟโซน อุ้ม → ปล่อย
            if first then
                log("① วาปกองแรกหน้าเซฟโซน: "..first.cat)
                if grab(first) then log(dropHere() and "  ✅ ปล่อยแล้ว" or "  ⚠️ ปล่อยไม่ผ่าน") else log("  ⚠️ อุ้มไม่ติด") end
            end
            local tgt=targetEgg()                         -- ③ วาปเก็บเป้าหมาย → อุ้มกลับบ้าน(ฝาก)
            if tgt then
                log("② วาปเก็บเป้าหมาย: "..tgt.cat.." ["..tgt.rarity.."]")
                if grab(tgt) then log(carryHome() and "  ✅ ฝากเป้าหมายเข้าบ้านแล้ว!" or "  ⚠️ ฝากไม่ผ่าน") else log("  ⚠️ อุ้มไม่ติด") end
            else log("ไม่มีไข่ตรง tier"); task.wait(1) end
            task.wait(CFG.LOOP_GAP)
        end
        log("⏹️ หยุดลูป")
    end)
end

-- ★ bind แบบ global ธรรมดาด้วย (บาง executor เรียก getgenv ตรงๆ ไม่ได้ ต้อง global)
SAE_SETHOME = ENV.SAE_SETHOME
SAE_TIER    = ENV.SAE_TIER
SAE_LIST    = ENV.SAE_LIST
SAE_STOP    = ENV.SAE_STOP
SAE_KILL    = ENV.SAE_KILL
SAE_START   = ENV.SAE_START
pcall(function() _G.SAE_SETHOME=ENV.SAE_SETHOME _G.SAE_TIER=ENV.SAE_TIER _G.SAE_LIST=ENV.SAE_LIST _G.SAE_STOP=ENV.SAE_STOP _G.SAE_KILL=ENV.SAE_KILL _G.SAE_START=ENV.SAE_START end)

log("✅ พร้อม! ยืนกลางเซฟโซน → SAE_SETHOME() → SAE_TIER(\"Mythic\") → SAE_START()   (ดูไข่: SAE_LIST())")
log("ถ้าพิมพ์คำสั่งแล้ว nil → ลองใส่ getgenv(). ข้างหน้า เช่น getgenv().SAE_START()")
