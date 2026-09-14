-- ============================================================
-- STEAL AN EGG — TREADMILL (เอาโค้ด moa456811 auto_training มาตรงๆ)
-- require(RS.Shared.Remotes).Treadmill: AskWearStill(ขึ้น) / AskRenderSnapshot(เช็ค) / AskDoff(ลง)
-- mounted = table.find(snapshot, UserId) (snapshot = array UserId คนบนลู่)
-- cmd: SAE_TREAD_ON() | SAE_TREAD_OFF() | SAE_TREAD_STATUS()
-- ============================================================
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[TREAD] "..tostring(t)) end

_G.SAE_TREAD_GEN=(_G.SAE_TREAD_GEN or 0)+1
local GEN=_G.SAE_TREAD_GEN
local function alive() return GEN==_G.SAE_TREAD_GEN end

-- ★ เอาแบบ moa: require Shared.Remotes module
local treadmill
pcall(function()
    local shared=RS:FindFirstChild("Shared")
    local mod=shared and shared:FindFirstChild("Remotes")
    if mod and mod:IsA("ModuleScript") then
        local remotes=require(mod)
        if type(remotes)=="table" and type(remotes.Treadmill)=="table" then treadmill=remotes.Treadmill end
    end
end)
if not treadmill then log("❌ require(Shared.Remotes).Treadmill ไม่ได้ — ลอง path อื่น")
else
    local oks={}; for _,k in ipairs({"AskWearStill","AskRenderSnapshot","AskDoff"}) do oks[#oks+1]=k.."="..tostring(treadmill[k]~=nil) end
    log("Treadmill remotes: "..table.concat(oks,", "))
end

local function speedStat() local ls=player:FindFirstChild("leaderstats") local s=ls and ls:FindFirstChild("Speed") return s and s.Value or nil end
-- mounted = UserId อยู่ใน snapshot array (แบบ moa เป๊ะ)
local function mounted()
    if not (treadmill and treadmill.AskRenderSnapshot) then return nil end
    local ok,snap=pcall(function() return treadmill.AskRenderSnapshot:InvokeServer() end)
    if not ok or type(snap)~="table" then return false end
    return table.find(snap, player.UserId)~=nil
end
local function wear() if not (treadmill and treadmill.AskWearStill) then return false end
    return pcall(function() return treadmill.AskWearStill:InvokeServer() end) end

ENV.SAE_TREAD_STATUS=function()
    log("Speed="..tostring(speedStat()).." | mounted="..tostring(mounted()))
end
ENV.SAE_TREAD_ON=function()
    if not treadmill then log("❌ ไม่มี treadmill remotes"); return end
    ENV.SAE_TREAD_RUN=true
    log("🏃 ขึ้นลู่วิ่ง (moa AskWearStill) ...")
    local s0=speedStat() or 0
    task.spawn(function()
        -- ★ loop แบบ moa: ถ้ายังไม่ mount → AskWearStill → ยืนยัน → wait 5
        while alive() and ENV.SAE_TREAD_RUN do
            if not mounted() then
                local ok,acc=wear()
                task.wait(0.5)
                if mounted() then log("✅ server ยืนยัน mount แล้ว") else log("⚠️ ยิง AskWearStill แล้วแต่ server ไม่ยืนยัน mount (acc="..tostring(acc)..")") end
            end
            task.wait(5)
        end
    end)
    -- เช็คยาว 20 วิ ว่า Speed ขึ้นจริงไหม
    task.spawn(function() task.wait(20)
        if alive() and ENV.SAE_TREAD_RUN then
            local now=speedStat() or 0
            log(("เช็ค 20 วิ: Speed +"..tostring((now or 0)-(s0 or 0)).." | mounted="..tostring(mounted())..
                " → "..(((now or 0)>(s0 or 0)) and "ขึ้น✅" or "ไม่ขึ้น (mount เฉยๆไม่พอ ต้องก้าว?)")))
        end
    end)
end
ENV.SAE_TREAD_OFF=function()
    ENV.SAE_TREAD_RUN=false
    if treadmill and treadmill.AskDoff then pcall(function() treadmill.AskDoff:InvokeServer() end) log("ลงลู่ (AskDoff)") else log("หยุด") end
end

-- ═══ COORDINATOR: ขึ้นลู่ตอน "ว่าง" / ลงลู่ตอนสคริปเก็บไข่ทำงาน ═══
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
-- busy = สคริปเก็บไข่กำลังทำงาน: (ก) อุ้มไข่ (Tool egg ในตัว) หรือ (ข) เพิ่งขยับเยอะ (ถูกลากไปเก็บ)
local function carryingEgg()
    local c=player.Character; if not c then return false end
    for _,it in ipairs(c:GetChildren()) do
        if it:IsA("Tool") and (it:GetAttribute("ItemType")=="AssetEgg" or it.Name:lower():find("egg")) then return true end
    end
    return false
end
local lastPos, lastMoveT = nil, 0
local function eggScriptBusy()
    if carryingEgg() then return true end
    local h=hrp()
    if h then
        if lastPos and (h.Position-lastPos).Magnitude>25 then lastMoveT=os.clock() end  -- ขยับเยอะ = ถูกลากไปเก็บ
        lastPos=h.Position
    end
    return (os.clock()-lastMoveT)<4   -- เพิ่งขยับใน 4 วิ = ยังทำงาน
end
ENV.SAE_TREAD_AUTO=function(on)
    if on==false then ENV.SAE_AUTO_RUN=false; ENV.SAE_TREAD_OFF(); log("ปิด auto"); return end
    ENV.SAE_AUTO_RUN=true
    log("🤖 AUTO: ว่าง→ขึ้นลู่ | เก็บไข่/ขยับ→ลงลู่หลบ")
    task.spawn(function()
        local ridingTread=false
        while alive() and ENV.SAE_AUTO_RUN do
            local busy=eggScriptBusy()
            if busy then
                if ridingTread then ENV.SAE_TREAD_OFF(); ridingTread=false; log("   สคริปเก็บไข่ทำงาน → ลงลู่หลบ") end
            else
                if not ridingTread then ENV.SAE_TREAD_ON(); ridingTread=true; log("   ว่าง → ขึ้นลู่วิ่ง") end
            end
            task.wait(2)
        end
    end)
end

pcall(function() for _,n in ipairs({"SAE_TREAD_ON","SAE_TREAD_OFF","SAE_TREAD_STATUS","SAE_TREAD_AUTO"}) do _G[n]=ENV[n] end end)
log("✅ พร้อม (โค้ด moa) — SAE_TREAD_ON() ขึ้นลู่ | SAE_TREAD_AUTO() = auto (ว่างขึ้นลู่/เก็บไข่ลงลู่) | SAE_TREAD_OFF()")
