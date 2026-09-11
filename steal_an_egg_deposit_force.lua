-- ============================================================
-- STEAL AN EGG — DEPOSIT FORCER (รันทับ MON_lean)
-- ปัญหา: monthonsova อุ้มไข่ถึงบ้าน(ฝั่งเซฟ)แล้ว แต่ tween ไม่ใช่ "การข้ามเส้น"
--        → server ไม่ trigger redeem (การฝาก = Separates: ข้าม SeparationLine)
-- แก้: พอไข่ถึงบ้าน → ขยับ "ตัวจริง" ข้ามเส้น SeparationLine ด้วย CFrame ทีละสเต็ป
--      (แบบเดิน ไม่ใช่ tween clone) → server เห็นการข้าม → ฝากทันที
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer

local function hrp() local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") return h end
local function log(t) print("[DEPOSIT-FORCE] "..tostring(t)) end

-- หา SeparationLine (เส้นแดง SAFE ZONE)
local line
pcall(function()
    local a = WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas")
    line = a and a:FindFirstChild("SeparationLine")
end)
if not line then log("❌ หา SeparationLine ไม่เจอ — หยุด"); return end
log("✅ SeparationLine @ "..tostring(line.Position).." size="..tostring(line.Size))

-- ทิศตั้งฉากกับเส้น (normal) = แกนที่ผอมสุดของ part; ข้ามไปตามแกนนี้
local function lineNormal()
    local s = line.Size
    if s.X<=s.Z then return line.CFrame.RightVector else return line.CFrame.LookVector end
end
-- ฝั่งเซฟ = ฝั่งที่ฐานเราอยู่ (X~425). หาเครื่องหมายจากจุดฐานเรา
local SAFE_POINT = Vector3.new(425,70,-362)
local function signedSide(pos)   -- >0 ฝั่งหนึ่ง, <0 อีกฝั่ง (เทียบ normal)
    return (pos - line.Position):Dot(lineNormal())
end
local SAFE_SIGN = (signedSide(SAFE_POINT) >= 0) and 1 or -1   -- เครื่องหมายของฝั่งเซฟ

-- carry state
local carrying, carryStart, forcedUid = false, 0, nil
pcall(function()
    local ES = require(RS:WaitForChild("Client"):WaitForChild("EggState"))
    ES.CarryChanged:Connect(function(cs)
        carrying = cs and cs.IsCarrying == true
        if carrying then carryStart = os.clock() else forcedUid = nil end
    end)
end)

-- ข้ามเส้นด้วยตัวจริง: ไปฝั่งสนาม(นอกเส้น)เล็กน้อย → เดินข้ามกลับฝั่งเซฟ (CFrame ทีละสเต็ป)
local function forceCross()
    local h = hrp(); if not h then return end
    local z, y = h.Position.Z, h.Position.Y
    local n = lineNormal()
    -- จุดเริ่ม = ฝั่งสนาม 18 studs จากเส้น, จุดจบ = ฝั่งเซฟ 30 studs จากเส้น (ตาม normal, ระดับ y/z เดิม)
    local base = Vector3.new(line.Position.X, y, z)   -- จุดบนเส้นระดับเดียวกับเรา
    local startP = base + n * (-SAFE_SIGN * 18)       -- ฝั่งสนาม
    local endP   = base + n * ( SAFE_SIGN * 30)       -- ฝั่งเซฟ
    log("ข้ามเส้น: "..("(%.0f,%.0f,%.0f)"):format(startP.X,startP.Y,startP.Z).." → "..("(%.0f,%.0f,%.0f)"):format(endP.X,endP.Y,endP.Z))
    -- วาร์ปไปจุดเริ่มฝั่งสนาม
    pcall(function() h.CFrame = CFrame.new(startP) end)
    RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
    -- เดินข้ามกลับฝั่งเซฟ ทีละ ~3 studs/เฟรม (ตัวจริง = server เห็นการข้าม)
    local total = (endP - startP)
    local steps = math.ceil(total.Magnitude / 3)
    for i=1, steps do
        if not carrying then break end       -- ฝากสำเร็จแล้ว (carry จบ) → หยุด
        local h2 = hrp(); if not h2 then break end
        local p = startP + total.Unit * math.min(total.Magnitude, i*3)
        pcall(function() h2.CFrame = CFrame.new(p) end)
        RunService.Heartbeat:Wait()
    end
end

-- ลูปเฝ้า: พอถืออยู่ + ใกล้บ้าน(ใกล้เส้น) + อุ้มมาแล้ว >1.2s (monthonsova พากลับถึงแล้ว) → ข้ามเส้นเอง
getgenv().__SAE_DEPFORCE = true
log("✅ เปิด — จะบังคับข้ามเส้นตอนไข่ถึงบ้าน (ปิด: getgenv().__SAE_DEPFORCE=false)")
task.spawn(function()
    while getgenv().__SAE_DEPFORCE do
        local h = hrp()
        if carrying and h and forcedUid == nil then
            local nearHome = math.abs(signedSide(h.Position)) < 220   -- ใกล้เส้น(อยู่ในระยะบ้าน)
            if nearHome and (os.clock()-carryStart) > 1.2 then
                forcedUid = true
                pcall(forceCross)
                -- ถ้ายังไม่ฝาก ลองซ้ำได้อีกใน 1.5s
                task.delay(1.5, function() if carrying then forcedUid = nil end end)
            end
        end
        task.wait(0.2)
    end
end)
