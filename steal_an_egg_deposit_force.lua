-- ============================================================
-- STEAL AN EGG — DEPOSIT FORCER v2 (รันทับ MON_lean)
-- การฝาก = server เช็ค Separates(เก่า,ใหม่) ว่า "ข้ามเส้น SeparationLine" ไหม
-- monthonsova ใช้ tween(humanoid clone) → ไม่นับเป็นการข้าม → ไม่ฝาก
-- แก้: พอไข่ถึงบ้าน → ขยับ "ตัวจริง(HRP)" เดินข้ามเส้นเอง (วนซ้ำจนฝากสำเร็จ)
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer

local function hrp() local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") return h end
local function log(t) print("[DEPOSIT-FORCE] "..tostring(t)) end

-- SeparationLine (เส้นแดง SAFE ZONE)
local line
pcall(function()
    local a = WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas")
    line = a and a:FindFirstChild("SeparationLine")
end)
if not line then log("❌ หา SeparationLine ไม่เจอ — หยุด"); return end
log("✅ SeparationLine @ "..tostring(line.Position).." size="..tostring(line.Size))

-- normal (ตั้งฉากกับเส้น = แกนผอมสุด)
local function lineNormal()
    local s = line.Size
    local n = (s.X<=s.Z) and line.CFrame.RightVector or line.CFrame.LookVector
    return Vector3.new(n.X,0,n.Z).Unit    -- เอาเฉพาะแนวราบ
end
local function signedSide(pos) return (pos - line.Position):Dot(lineNormal()) end
-- ฝั่งเซฟ = ฝั่งฐานเรา (X~425)
local SAFE_SIGN = (signedSide(Vector3.new(425,70,-362))>=0) and 1 or -1

-- carry state
local carrying, carryUid = false, nil
pcall(function()
    local ES = require(RS:WaitForChild("Client"):WaitForChild("EggState"))
    ES.CarryChanged:Connect(function(cs)
        carrying = cs and cs.IsCarrying == true
        carryUid = cs and cs.Uid
    end)
end)

-- ข้ามเส้น 1 ครั้ง: วาร์ปไปฝั่งสนาม(นอกเส้น) → เดินข้ามกลับฝั่งเซฟ ทีละ ~2.5 studs/เฟรม (ตัวจริง)
local function crossOnce()
    local h = hrp(); if not h then return end
    local pos = h.Position
    local y = pos.Y
    local n = lineNormal()
    local safeDir = n * SAFE_SIGN
    local foot = pos - signedSide(pos)*n          -- จุดบนเส้นตรงแนวเรา (คง Z/แนวเดิม)
    local startP = Vector3.new(0,y,0) + (foot - safeDir*16); startP = Vector3.new(startP.X, y, startP.Z)  -- ฝั่งสนาม 16
    local endP   = foot + safeDir*40;              endP   = Vector3.new(endP.X, y, endP.Z)                -- ฝั่งเซฟ 40
    -- วาร์ปไปจุดเริ่มฝั่งสนาม
    pcall(function() h.CFrame = CFrame.new(startP) end)
    RunService.Heartbeat:Wait()
    -- เดินข้ามกลับฝั่งเซฟ ช้าๆ (server เห็นการข้ามชัด)
    local seg = endP - startP
    local steps = math.ceil(seg.Magnitude/2.5)
    for i=1, steps do
        if not carrying then return end
        local hh = hrp(); if not hh then return end
        pcall(function() hh.CFrame = CFrame.new(startP + seg.Unit*math.min(seg.Magnitude, i*2.5)) end)
        RunService.Heartbeat:Wait()
    end
end

-- เฝ้า: พอถืออยู่ + ถึงบ้าน(ใกล้เส้น) → วนข้ามซ้ำจนฝากได้ (override monthonsova)
getgenv().__SAE_DEPFORCE = true
log("✅ เปิด v2 — วนข้ามเส้นจนไข่เข้า (ปิด: getgenv().__SAE_DEPFORCE=false)")
task.spawn(function()
    while getgenv().__SAE_DEPFORCE do
        local h = hrp()
        if carrying and h and math.abs(signedSide(h.Position)) < 160 then
            -- ถึงบ้านแล้ว + ยังถืออยู่ → บังคับข้ามจนกว่าจะฝาก (สู้ tween ที่ดึงกลับ)
            local uid = carryUid
            local tries = 0
            while carrying and carryUid==uid and getgenv().__SAE_DEPFORCE and tries<10 do
                tries = tries + 1
                log("บังคับข้ามเส้น ครั้งที่ "..tries)
                pcall(crossOnce)
                -- รอ server ตอบ redeem
                local t=os.clock(); while carrying and carryUid==uid and os.clock()-t<0.6 do RunService.Heartbeat:Wait() end
            end
            if not carrying then log("✅ ฝากสำเร็จ!") end
        end
        task.wait(0.15)
    end
end)
