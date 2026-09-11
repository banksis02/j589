-- ============================================================
-- monthonsova/Steal-An-Egg — โหลดเพื่อใช้ "Movement" (ขยับลื่น จัดการ lagback)
-- ★ ไม่รัน AutoFarm เดิม — ใช้ลำดับของเราแทน:
--   1) ยืนหน้าจุดเซฟโซน  2) วาปไปไข่จุดแรก อุ้ม 1 ใบ → ปล่อยตรงนั้น
--   3) วาปไปไข่เป้าหมาย(tier) อุ้ม → ปล่อยตรงนั้น  → วน
-- ============================================================
local BASE = "https://raw.githubusercontent.com/monthonsova/Steal-An-Egg/HEAD/"
local ROOT = "Steal-An-Egg/"
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G

assert(type(writefile)=="function" and type(readfile)=="function", "executor ต้องมี writefile/readfile")

local FILES = {
    "EggESP.lua","EggESP/init.lua",
    "EggESP/core/Loader.lua","EggESP/core/Config.lua","EggESP/core/Util.lua","EggESP/core/Diagnostics.lua","EggESP/core/FarmFilters.lua",
    "EggESP/automation/AutoFarm.lua","EggESP/automation/BasePenAutomation.lua","EggESP/automation/DayCycle.lua","EggESP/automation/GuardZone.lua","EggESP/automation/InventoryManager.lua","EggESP/automation/Movement.lua","EggESP/automation/Passthrough.lua","EggESP/automation/PetAutomation.lua","EggESP/automation/SpeedBypass.lua",
    "EggESP/esp/BoundingBoxPool.lua","EggESP/esp/BoundingBoxRenderer.lua","EggESP/esp/Controller.lua","EggESP/esp/DataCollector.lua","EggESP/esp/DrawingPool.lua","EggESP/esp/EggData.lua","EggESP/esp/ObstacleData.lua","EggESP/esp/PathService.lua","EggESP/esp/Renderer.lua","EggESP/esp/StackLayout.lua","EggESP/esp/TextLayout.lua","EggESP/esp/TrapData.lua","EggESP/esp/TreadmillData.lua",
    "EggESP/navigation/Pathfinder.lua",
    "EggESP/ui/FarmFilterUI.lua","EggESP/ui/Hub.lua","EggESP/ui/VoidUI.lua","EggESP/ui/VoidUIHub.lua","EggESP/ui/void_build.lua",
}
local DIRS = { "Steal-An-Egg","Steal-An-Egg/EggESP","Steal-An-Egg/EggESP/core","Steal-An-Egg/EggESP/automation","Steal-An-Egg/EggESP/esp","Steal-An-Egg/EggESP/navigation","Steal-An-Egg/EggESP/ui" }
for _, d in ipairs(DIRS) do pcall(function() if makefolder then makefolder(d) end end) end

local ok,fail = 0,0
for _, f in ipairs(FILES) do
    local exists = type(isfile)=="function" and isfile(ROOT..f)
    if not exists then
        local o, body = pcall(function() return game:HttpGet(BASE..f) end)
        if o and type(body)=="string" and #body>0 then pcall(function() writefile(ROOT..f, body) end); ok=ok+1
        else fail=fail+1; warn("โหลดพลาด: "..f) end
    else ok=ok+1 end
end
print(("[SEQ] ไฟล์พร้อม %d พลาด %d"):format(ok,fail))
if fail>0 then warn("[SEQ] มีไฟล์พลาด — รันซ้ำอีกรอบ"); return end

ENV.__HUB_FORCE_DRAWING = true
pcall(function() if setthreadidentity then setthreadidentity(8) end end)

local API = loadstring(readfile(ROOT.."EggESP.lua"), "@EggESP")()
if type(API) ~= "table" then warn("[SEQ] init ไม่คืน API") return end

-- ปิด automation อื่น + ESP (เบา) — เราจะขับเอง ไม่รัน AutoFarm
pcall(function()
    local c = API.GetConfig().Runtime
    c.speedBypassOnAutoFarm=false; c.tweenSpeed=500
end)
pcall(function() if API.Modules and API.Modules.DataCollector then API.Modules.DataCollector.Collect=function() return {} end end)

-- ===== ตัวช่วยของเรา =====
local Move = API.Modules and API.Modules.Movement
local ES, Assets
pcall(function() ES = require(RS:WaitForChild("Client"):WaitForChild("EggState")) end)
pcall(function() Assets = require(RS:WaitForChild("Data"):WaitForChild("Assets")) end)
print("[SEQ] Move="..tostring(Move~=nil).." ES="..tostring(ES~=nil).." Assets="..tostring(Assets~=nil))
if not Move then warn("[SEQ] ❌ ไม่เจอ Movement API — หยุด") return end
if not ES   then warn("[SEQ] ❌ ไม่เจอ EggState — หยุด") return end

local function log(t) print("[SEQ] "..tostring(t)) end
local function rootPart() return (Move.GetRootPart and Move.GetRootPart()) or (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) end

-- rarity map
local rarityOf = {}
pcall(function()
    if Assets and Assets.Directory then
        for k,e in pairs(Assets.Directory) do local r=e and e.Rarity
            if type(r)=="table" then local info={name=r.DisplayName or "?",tier=r.RarityNumber or 0}
                rarityOf[tostring(k)]=info; if e.Name then rarityOf[tostring(e.Name)]=info end end end
    end
end)
local function rarityFor(cat) return rarityOf[tostring(cat)] or {name="?",tier=0} end

-- carry state
local carrying=false
pcall(function() if ES.CarryChanged then ES.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)

-- config เป้าหมาย
local CFG = { RARITY="", MIN_TIER=0, GRAB_T=3.0, ARRIVE=6 }
local HOME = ENV.SAE_HOME or Vector3.new(425,70,-362)

-- อ่านไข่ในสนาม (ไม่ยิง remote — ใช้ cache)
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local function fieldEggs()
    local out={}
    local ok2,data=pcall(function() return ES.ReadFieldEggs() end)
    if ok2 and type(data)=="table" and type(data.Records)=="table" then
        local rp=rootPart(); local myPos=(rp and rp.Position) or Vector3.new()
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

-- ขยับด้วย monthonsova Movement (ลื่น จัดการ lagback) แล้วรอถึง
local function gotoPos(pos, radius, timeout)
    radius=radius or CFG.ARRIVE; timeout=timeout or 15
    local target=Vector3.new(pos.X,pos.Y,pos.Z)
    Move.TweenTo(target)
    local t=os.clock()
    while ENV.SAE_ALIVE~=false and os.clock()-t<timeout do
        local r=rootPart()
        if r and Move.IsNear(r.Position, target, radius) then return true end
        if Move.IsTweening and not Move.IsTweening() then Move.TweenTo(target) end
        RunService.Heartbeat:Wait()
    end
    return false
end

-- ยิง prompt เก็บ (กด E)
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
    gotoPos(egg.pos, CFG.ARRIVE)
    local t=os.clock()
    while ENV.SAE_RUN and not carrying and os.clock()-t<CFG.GRAB_T do
        pcall(function() if ES.CarryFieldEgg then ES.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    return carrying
end
-- "วาง" = ปล่อยไข่ตรงนั้นเลย
local function dropHere()
    pcall(function() if ES.DropFieldEgg then ES.DropFieldEgg() end end)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end
    return not carrying
end

-- ===== COMMANDS =====
ENV.SAE_SETHOME=function() local r=rootPart(); if r then ENV.SAE_HOME=r.Position; HOME=r.Position; log("ตั้ง HOME(เซฟโซน)="..tostring(r.Position)) end end
ENV.SAE_TIER=function(x) CFG.RARITY=x or ""; log("target tier = "..(CFG.RARITY=="" and "ทุกระดับ" or CFG.RARITY)) end
ENV.SAE_LIST=function()
    local e=fieldEggs(); table.sort(e,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    log("ไข่ในสนาม "..#e.." ใบ:")
    for i=1,math.min(#e,12) do local x=e[i] print(("  #%d [%s t%d] %s @%.0f"):format(i,x.rarity,x.tier,x.cat,x.dist)) end
end
ENV.SAE_STOP=function() ENV.SAE_RUN=false log("หยุด") end
ENV.SAE_START=function()
    ENV.SAE_RUN=true; log("▶️ START — ยืนเซฟโซน→วาปเก็บใบแรกปล่อย→วาปเก็บเป้าหมายปล่อย (หยุด SAE_STOP)")
    task.spawn(function()
        while ENV.SAE_RUN do
            gotoPos(HOME, CFG.ARRIVE)                       -- ① ยืนหน้าจุดเซฟโซน
            local first=nearestEgg()                        -- ② วาปเก็บไข่จุดแรก → ปล่อย
            if first then
                log("① วาปเก็บใบแรก: "..first.cat.." @"..math.floor(first.dist))
                if grab(first) then log(dropHere() and "  ✅ ปล่อยแล้ว" or "  ⚠️ ปล่อยไม่ผ่าน") else log("  ⚠️ อุ้มไม่ติด") end
            end
            local tgt=targetEgg()                           -- ③ วาปเก็บเป้าหมาย → ปล่อย
            if tgt then
                log("② วาปเก็บเป้าหมาย: "..tgt.cat.." ["..tgt.rarity.."]")
                if grab(tgt) then log(dropHere() and "  ✅ ปล่อยเป้าหมายแล้ว" or "  ⚠️ ปล่อยไม่ผ่าน") else log("  ⚠️ อุ้มไม่ติด") end
            else log("ไม่มีไข่ตรง tier"); task.wait(1) end
            task.wait(0.2)
        end
        log("⏹️ หยุดลูป")
    end)
end

log("✅ พร้อม — ยืนกลางเซฟโซน → SAE_SETHOME() → SAE_TIER(\"Mythic\") → SAE_START()   (ดูไข่: SAE_LIST())")
