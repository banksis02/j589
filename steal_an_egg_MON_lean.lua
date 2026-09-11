-- ============================================================
-- monthonsova/Steal-An-Egg — รันแบบ LEAN (ฟามทำงาน แต่ปิด ESP = ไม่แลค)
-- ต่อแค่ Heartbeat(AutoFarm.Tick) ไม่ต่อ RenderStepped(วาด ESP)
-- ยืนบน "ฐาน/plot ของตัวเอง" ก่อนรัน (จะตั้ง standby = จุดนั้น)
-- ★ เวอร์ชันนี้: เอา noclip(ทะลุกำแพง)ออก + เก็บไข่แล้วออกทันที (ลด settle กันยามตี)
-- ============================================================

local BASE = "https://raw.githubusercontent.com/monthonsova/Steal-An-Egg/HEAD/"
local ROOT = "Steal-An-Egg/"
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local player     = Players.LocalPlayer

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

-- โหลดไฟล์ (ข้ามถ้ามีแล้ว เพื่อความเร็ว; ใส่ true บรรทัดล่างเพื่อโหลดใหม่ทั้งหมด)
local FORCE = false
local ok,fail = 0,0
for _, f in ipairs(FILES) do
    local exists = type(isfile)=="function" and isfile(ROOT..f)
    if FORCE or not exists then
        local o, body = pcall(function() return game:HttpGet(BASE..f) end)
        if o and type(body)=="string" and #body>0 then pcall(function() writefile(ROOT..f, body) end); ok=ok+1
        else fail=fail+1; warn("โหลดพลาด: "..f) end
    else ok=ok+1 end
end
print(("[LEAN] ไฟล์พร้อม %d พลาด %d"):format(ok,fail))
if fail>0 then warn("[LEAN] มีไฟล์พลาด — รันซ้ำอีกรอบ"); return end

getgenv().__HUB_FORCE_DRAWING = true   -- ไม่ใช้ VoidUI (กัน HttpGet/plugin)
pcall(function() if setthreadidentity then setthreadidentity(8) end end)  -- เหมือน hub_loader (ให้ clone/bypass ทำงาน)

local API = loadstring(readfile(ROOT.."EggESP.lua"), "@EggESP")()
if type(API) ~= "table" then warn("[LEAN] init ไม่คืน API") return end

-- ⭐ ปิด automation อื่นทั้งหมด — เก็บไข่อย่างเดียว (กัน "เอาไข่ในกระเป๋ามาวาง" ฯลฯ)
pcall(function()
    local c = API.GetConfig().Runtime
    c.autoPlaceEnabled       = false   -- ห้ามเอาไข่ในกระเป๋ามาวาง
    c.autoSellEnabled        = false
    c.autoDumpWorstEggsEnabled = false
    c.autoPetCareEnabled     = false
    c.autoHatchEnabled       = false
    c.autoEquipBest          = false
    c.autoFuseEnabled        = false
    c.autoUpgradeBasePen     = false
    c.autoFeedParasiteEnabled= false
    c.speedBypassOnAutoFarm  = false   -- ใช้ tween ไม่ใช่ SpeedBypass (พัง tween)
    c.tweenSpeed             = 900     -- ★ เร็วขึ้น (ไข่ไกล X>4000 ต้องอุ้มถึงบ้านใน ~8วิ ก่อนเด้ง); tween=humanoid clone ปลอดภัย
    -- ★ หยุดให้ "ลึกในโซน" เป๊ะ: สำเร็จเมื่อจบตรง(440,-362); เฟลเมื่อเบี้ยวออก X>450 (นอกเขต)
    c.standbyArriveRadius    = 3       -- แคบลง (เดิม 6 → หยุดนอกโซนบ้าง)
    c.standbyStartRadius     = 3

    -- ★★ เก็บไข่แล้วออกทันที (กันยามตี) — ยามตื่นใช้ 0.63 วิ ต้องขโมยเสร็จ+ออกให้ไว
    --   settle เดิม 4 ticks (~0.4 วิ นิ่งตรงไข่) → ลดเหลือ 1 (sync แว้บเดียวพอ ไม่แช่)
    c.pickupSyncSettleTicks  = 1
    c.autoFarmWalkPickupSync = true    -- คงไว้ (จำเป็นให้ขโมยติดชัวร์ ไม่ desync)
    c.guardZoneForceWalk     = false   -- ห้ามชะลอเดินในเขตยาม (บินผ่านเต็มสปีด)
end)

-- ปิด ESP visual + ตัดแลค: ให้ DataCollector คืนว่าง = ไม่มีอะไรให้วาด (render loop เบา)
pcall(function() API.SetShowTreadmill(false); API.SetShowTraps(false) end)
pcall(function()
    if API.Modules and API.Modules.DataCollector then
        API.Modules.DataCollector.Collect = function() return {} end
    end
end)

-- ★★ จุดฝาก (standby) = ต้องอยู่ "บนฐานเรา" (เขตฝากไข่) ไม่งั้นฝากไม่ได้ ไข่เด้งคืนรัง!
--   จาก probe: ฐานเราอยู่ ~(440,-362); จุดที่เคยตั้ง (538) ห่างฐาน 80+ = พลาด
--   ปรับเอง: getgenv().SAE_HOME = Vector3.new(x,y,z)  หรือยืนตรงจุดฝากแล้วสั่ง SAE_SETHOME_HERE()
local HOME = getgenv().SAE_HOME or Vector3.new(425, 70, -362)  -- ★ ลึกเข้าในโซน (เดิม 440=ขอบ เฟลบ่อย)
pcall(function() API.GetConfig().Runtime.standbyPosition = HOME end)
print("[LEAN] จุดฝาก(standby) = "..tostring(HOME).."  (ปรับ: SAE_SETHOME_HERE() ตอนยืนบนฐาน)")
getgenv().SAE_SETHOME_HERE = function()
    local c=player.Character; local h=c and c:FindFirstChild("HumanoidRootPart")
    if h then
        getgenv().SAE_HOME = h.Position
        pcall(function() API.GetConfig().Runtime.standbyPosition = h.Position end)
        print("[LEAN] ✅ ตั้งจุดฝากใหม่ = "..tostring(h.Position))
    end
end

-- ⭐ รัน Controller เต็ม (2 loop เหมือน full hub → movement ลื่น ไม่เด้ง + deposit ทำงาน)
--   แต่ ESP ไม่วาดอะไร (DataCollector ว่าง) = เบา
pcall(function() API.Start() end)
pcall(function() API.StartAutoFarm() end)

-- ❌ เอา NOCLIP (ทะลุกำแพง) ออกแล้ว — มันทำให้ไม่มีพื้น โดนตีร่วงตกแมพ
-- ⭐ แทนด้วย ANTI-ล้ม อย่างเดียว: กันสะดุด/ล้ม ไข่หลุด (ไม่ทะลุกำแพง มีพื้นยืนปกติ)
getgenv().__SAE_ANTIRAGDOLL = true
task.spawn(function()
    local ST = Enum.HumanoidStateType
    while getgenv().__SAE_ANTIRAGDOLL do
        local ch = player.Character
        local h  = ch and ch:FindFirstChildOfClass("Humanoid")
        if h then pcall(function()
            h:SetStateEnabled(ST.FallingDown, false)
            h:SetStateEnabled(ST.Ragdoll, false)
            h:SetStateEnabled(ST.PlatformStanding, false)
            h.PlatformStand = false
        end) end
        RunService.Stepped:Wait()
    end
end)

print("[LEAN] ✅ รันแล้ว — เก็บไข่อย่างเดียว + ANTI-ล้ม(ไม่ทะลุกำแพง) + settle=1(ออกไว) + ESP ปิด")
print("[LEAN] หยุด: getgenv().EggESP.StopAutoFarm()  /  ปิด anti-ล้ม: getgenv().__SAE_ANTIRAGDOLL=false")
