-- ============================================================
-- STEAL AN EGG — FLY TEST (พิสูจน์เทคนิค BodyVelocity แยกเดี่ยว)
-- บินไปไข่ไกลสุด + log ระยะทุกวิ → เห็นชัดว่าบินไปเรื่อยๆ หรือโดนดึงกลับ
-- ไม่มี farm logic — เทสการบินอย่างเดียว
-- คำสั่ง: SAE_FLYFAR()  = บินไปไข่ไกลสุด | SAE_FLYSTOP() = หยุด
-- ============================================================
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[FLYTEST] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end

local EggState
pcall(function() EggState = require(RS:WaitForChild("Client",10):WaitForChild("EggState",10)) end)

-- ปิด ObbyAntiTPClient (insurance)
pcall(function() WS:SetAttribute("ClientObbyAntiTp",false) end)
pcall(function() local ps=player:FindFirstChild("PlayerScripts") if ps then for _,i in ipairs(ps:GetDescendants()) do if i.Name=="ObbyAntiTPClient" and i:IsA("LocalScript") then pcall(function() i.Disabled=true i:Destroy() end) end end end end)

local SPEED = 340
local flyBV, flying = nil, false

local function farthestEgg()
    local best, bestd = nil, -1
    local ok,data=pcall(function() EggState.SyncFieldEggs(); return EggState.ReadFieldEggs() end)
    if ok and type(data)=="table" and type(data.Records)=="table" then
        local h=hrp(); local myPos=(h and h.Position) or Vector3.new()
        for _,rec in pairs(data.Records) do
            if type(rec)=="table" and typeof(rec.BoundsCFrame)=="CFrame" then
                local d=(rec.BoundsCFrame.Position-myPos).Magnitude
                if d>bestd then bestd=d; best=rec.BoundsCFrame.Position end
            end
        end
    end
    return best, bestd
end

ENV.SAE_FLYFAR = function()
    local target, d0 = farthestEgg()
    if not target then log("❌ หาไข่ไม่เจอ (ลองรัน MON_lean ก่อนให้ sync)"); return end
    log(("🎯 บินไปไข่ไกลสุด ระยะ %.0f studs @(%.0f,%.0f,%.0f)"):format(d0,target.X,target.Y,target.Z))
    flying=true
    local h=hrp(); local hu=hum(); if not(h and hu) then return end
    pcall(function() hu.PlatformStand=false end)
    if not (flyBV and flyBV.Parent) then
        flyBV=Instance.new("BodyVelocity"); flyBV.Name="SAE_Fly"; flyBV.MaxForce=Vector3.new(1e7,1e7,1e7); flyBV.P=12500; flyBV.Velocity=Vector3.new(0,0,0); flyBV.Parent=h
    end
    task.spawn(function()
        local t0=tick(); local lastLog=0; local lastPos=h.Position; local lastCheck=tick()
        while flying and tick()-t0<40 do
            local cur=hrp(); if not cur then break end
            if not (flyBV and flyBV.Parent) then flyBV=Instance.new("BodyVelocity") flyBV.Name="SAE_Fly" flyBV.MaxForce=Vector3.new(1e7,1e7,1e7) flyBV.P=12500 flyBV.Parent=cur end
            local flat=Vector3.new(target.X-cur.Position.X,0,target.Z-cur.Position.Z)
            local dy=target.Y-cur.Position.Y
            local dist=flat.Magnitude
            if dist<5 and math.abs(dy)<10 then log("✅✅ ถึงไข่ไกลแล้ว! (ระยะเหลือ "..math.floor(dist)..") = BodyVelocity เวิร์ก!") break end
            local dir=(dist>0.1) and flat.Unit or Vector3.new(0,0,0)
            local vy=0; if math.abs(dy)>8 then vy=math.clamp(dy,-18,18) end
            pcall(function() flyBV.Velocity=Vector3.new(dir.X*SPEED, vy, dir.Z*SPEED) end)
            if tick()-lastCheck>2 then
                if (cur.Position-lastPos).Magnitude<6 then pcall(function() flyBV.Velocity=Vector3.new(dir.X*SPEED,16,dir.Z*SPEED) end) end
                lastPos,lastCheck=cur.Position,tick()
            end
            -- log ระยะทุก 1 วิ
            if tick()-lastLog>1 then lastLog=tick(); log(("   บินอยู่... เหลือ %.0f studs (ที่ %.0f,%.0f)"):format(dist,cur.Position.X,cur.Position.Z)) end
            task.wait(0.06)
        end
        flying=false
        if flyBV and flyBV.Parent then pcall(function() flyBV.Velocity=Vector3.new(0,0,0) end) end
        log("จบการบิน")
    end)
end
ENV.SAE_FLYSTOP = function() flying=false if flyBV then pcall(function() flyBV:Destroy() end) flyBV=nil end log("หยุดบิน") end
pcall(function() _G.SAE_FLYFAR=ENV.SAE_FLYFAR; _G.SAE_FLYSTOP=ENV.SAE_FLYSTOP end)

log("✅ พร้อมเทส — พิมพ์ SAE_FLYFAR() (บินไปไข่ไกลสุด) | หยุด SAE_FLYSTOP()")
log("EggState="..tostring(EggState~=nil))
