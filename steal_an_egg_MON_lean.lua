-- ============================================================
-- monthonsova/Steal-An-Egg — รันแบบ LEAN (ฟามทำงาน แต่ปิด ESP = ไม่แลค)
-- ต่อแค่ Heartbeat(AutoFarm.Tick) ไม่ต่อ RenderStepped(วาด ESP)
-- ยืนบน "ฐาน/plot ของตัวเอง" ก่อนรัน (จะตั้ง standby = จุดนั้น)
-- ============================================================

local BASE = "https://raw.githubusercontent.com/monthonsova/Steal-An-Egg/HEAD/"
local ROOT = "Steal-An-Egg/"
local RunService = game:GetService("RunService")

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
    c.tweenSpeed             = 500     -- ลดจาก 1000 (ไวไปอาจกระตุก AC → เด้ง)
end)

-- ปิด ESP visual + ตัดแลค: ให้ DataCollector คืนว่าง = ไม่มีอะไรให้วาด (render loop เบา)
pcall(function() API.SetShowTreadmill(false); API.SetShowTraps(false) end)
pcall(function()
    if API.Modules and API.Modules.DataCollector then
        API.Modules.DataCollector.Collect = function() return {} end
    end
end)

-- standby = ตำแหน่งที่ยืน (ยืนบนฐาน/plot ตัวเองก่อนรัน)
pcall(function() API.SetStandbyFromPlayer() end)

-- ⭐ รัน Controller เต็ม (2 loop เหมือน full hub → movement ลื่น ไม่เด้ง + deposit ทำงาน)
--   แต่ ESP ไม่วาดอะไร (DataCollector ว่าง) = เบา
pcall(function() API.Start() end)
pcall(function() API.StartAutoFarm() end)

-- ⭐ NOCLIP — ทะลุทุกอย่าง (ไม่ชน/ไม่ล้ม/มอนตีไม่ล้ม) แก้ "วิ่งกลับแล้วล้ม ไข่หลุด"
getgenv().__SAE_NOCLIP = true
task.spawn(function()
    while getgenv().__SAE_NOCLIP do
        local ch = player.Character
        if ch then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    pcall(function() p.CanCollide = false end)
                end
            end
        end
        RunService.Stepped:Wait()
    end
end)

-- ⭐ ANTI-KNOCKBACK / ANTI-FALL — กัน guard(มอน)ตีแล้วปลิว/ตกแมพ
--   noclip = ไม่มีพื้น → โดนแรงกระแทกจาก guard แล้วร่วงทะลุแมพ
--   บล็อก ragdoll/ล้ม + ล้างความเร็วทุกเฟรม (tween ยังคุมตำแหน่งได้ปกติ)
getgenv().__SAE_ANTIFALL = true
task.spawn(function()
    local ST = Enum.HumanoidStateType
    local block = { ST.FallingDown, ST.Ragdoll, ST.PlatformStanding, ST.Physics, ST.GettingUp, ST.Seated }
    while getgenv().__SAE_ANTIFALL do
        local ch  = player.Character
        local h   = ch and ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if h and hrp then
            pcall(function()
                for _, s in ipairs(block) do h:SetStateEnabled(s, false) end
                h.PlatformStand = false
                hrp.AssemblyLinearVelocity  = Vector3.zero   -- ล้าง knockback (กันปลิว)
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        RunService.Stepped:Wait()
    end
end)

print("[LEAN] ✅ รันแล้ว — เก็บไข่อย่างเดียว + NOCLIP + ANTI-FALL(กันตกแมพ) + ESP ปิด (เบา)")
print("[LEAN] หยุด: getgenv().EggESP.StopAutoFarm()  /  noclip: getgenv().__SAE_NOCLIP=false  /  antifall: getgenv().__SAE_ANTIFALL=false")
