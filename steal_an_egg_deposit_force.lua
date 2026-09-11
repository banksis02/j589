-- ============================================================
-- STEAL AN EGG — DEPOSIT FORCER v3 (รันทับ MON_lean)
-- การฝาก = server เช็ค Separates(เก่า,ใหม่) = "ข้ามเส้น SeparationLine"
-- monthonsova tween(clone) ไม่นับเป็นการข้าม → แก้: ขยับ HRP จริงเดินข้ามเอง
-- v3: เดินข้ามลื่นเร็ว + noclip เฉพาะตอนข้าม (ทะลุกำแพง WallStartCollision ขอบโซน)
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer

local function hrp() local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") return h end
local function log(t) print("[DEPOSIT-FORCE] "..tostring(t)) end

local line
pcall(function()
    local a = WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas")
    line = a and a:FindFirstChild("SeparationLine")
end)
if not line then log("❌ หา SeparationLine ไม่เจอ — หยุด"); return end
log("✅ SeparationLine @ "..tostring(line.Position))

local function lineNormal()
    local s = line.Size
    local n = (s.X<=s.Z) and line.CFrame.RightVector or line.CFrame.LookVector
    return Vector3.new(n.X,0,n.Z).Unit
end
local function signedSide(pos) return (pos - line.Position):Dot(lineNormal()) end
local SAFE_SIGN = (signedSide(Vector3.new(425,70,-362))>=0) and 1 or -1

local carrying, carryUid = false, nil
pcall(function()
    local ES = require(RS:WaitForChild("Client"):WaitForChild("EggState"))
    ES.CarryChanged:Connect(function(cs) carrying = cs and cs.IsCarrying==true; carryUid = cs and cs.Uid end)
end)

-- noclip ชั่วคราว (ทะลุกำแพงขอบโซนตอนข้าม)
local noclipOn = false
task.spawn(function()
    while true do
        if noclipOn then
            local ch=player.Character
            if ch then for _,p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end
            end end
        end
        RunService.Stepped:Wait()
    end
end)

-- เดินตัวจริงไปเป้าหมาย (CFrame ทีละเฟรม = server เห็นเป็นการเคลื่อนที่จริง)
local function stepTo(target, perFrame)
    local guard=0
    while carrying and guard<200 do
        guard=guard+1
        local h=hrp(); if not h then return end
        local d=target-h.Position; local m=d.Magnitude
        if m<2 then return end
        pcall(function() h.CFrame=CFrame.new(h.Position + d.Unit*math.min(m, perFrame)) end)
        RunService.Heartbeat:Wait()
    end
end

-- ข้ามเส้น 1 ครั้ง: เดินไปฝั่งสนาม → เดินข้ามกลับฝั่งเซฟ (ต่อเนื่อง เร็ว)
local function crossOnce()
    local h=hrp(); if not h then return end
    local y=h.Position.Y
    local n=lineNormal(); local safeDir=n*SAFE_SIGN
    local foot=h.Position - signedSide(h.Position)*n
    local fieldP=foot - safeDir*18; fieldP=Vector3.new(fieldP.X,y,fieldP.Z)
    local safeP =foot + safeDir*38; safeP =Vector3.new(safeP.X,y,safeP.Z)
    noclipOn=true
    stepTo(fieldP, 7)     -- ไปฝั่งสนาม (เร็ว)
    stepTo(safeP, 7)      -- ข้ามกลับฝั่งเซฟ → server เห็นการข้าม → ฝาก
    noclipOn=false
end

getgenv().__SAE_DEPFORCE=true
log("✅ เปิด v3 — เดินข้ามเส้นตอนไข่ถึงบ้าน (ปิด: getgenv().__SAE_DEPFORCE=false)")
task.spawn(function()
    while getgenv().__SAE_DEPFORCE do
        local h=hrp()
        if carrying and h and math.abs(signedSide(h.Position))<140 then
            local uid=carryUid; local tries=0
            while carrying and carryUid==uid and getgenv().__SAE_DEPFORCE and tries<6 do
                tries=tries+1
                pcall(crossOnce)
                local t=os.clock(); while carrying and carryUid==uid and os.clock()-t<0.5 do RunService.Heartbeat:Wait() end
            end
            noclipOn=false
            if not carrying then log("✅ ฝากสำเร็จ! ("..tries.." ครั้ง)") end
        end
        task.wait(0.15)
    end
end)
