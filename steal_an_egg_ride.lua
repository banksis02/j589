-- ============================================================
-- STEAL AN EGG — CARRIER RIDE (ท่าจริงจากสคริปที่ใช้ได้ — decode ด้วย carrier_probe)
-- สูตรจริง (ไม่ใช่ยาม AI / ไม่ teleport / ไม่ tween CFrame):
--   1) สร้าง CARRIER = Part ล่องหน (Massless, CanCollide=false, Transparency=1) ไม่มี Humanoid
--   2) weld ตัวเรา (HRP) นั่งบน carrier
--   3) ลาก carrier ด้วย BodyVelocity (ฟิสิกส์ ~500) → anti-cheat มองเป็นเคลื่อนที่ปกติ ไม่จับ ไม่ desync
--   ตัวเรา = ผู้โดยสารน้ำหนักตาย → ไม่มี AI ไล่ ไม่โดนตี
-- cmd: SAE_SETHOME() จำจุดฝาก | SAE_AUTORIDE() ไป-เก็บ-กลับ-ฝาก อัตโนมัติ
--      SAE_RIDEOUT(far) ไปไข่ | SAE_RIDEHOME() กลับ | SAE_UNRIDE() ลง
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[RIDE] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

-- ───────── config ─────────
local CFG = {
    SPEED   = 500,     -- ความเร็ว carrier (studs/s) — ฟิสิกส์ ไม่ใช่วาป
    HOVER   = 8,       -- ลอยเหนือเป้า/พื้น กี่ studs
    ARRIVE  = 8,       -- ถึงเมื่อห่าง < นี่
    GRAB_T  = 6,       -- เวลา spam เก็บไข่สูงสุด
    HOME    = nil,     -- จุดฝาก (SAE_SETHOME) — default = จุดปัจจุบันตอนโหลด
}

-- ───────── EggState (เก็บไข่) ─────────
local EggState; pcall(function() EggState=require(RS:WaitForChild("Client",10):WaitForChild("EggState",10)) end)
local carrying=false
pcall(function() if EggState and EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local function pickEgg(farthest)
    if not EggState then return nil end
    local best,bd=nil, farthest and -1 or 1e9
    local ok=pcall(function() EggState.SyncFieldEggs() end)
    local data; pcall(function() data=EggState.ReadFieldEggs() end)
    if type(data)=="table" and type(data.Records)=="table" then
        local h=hrp(); local myPos=(h and h.Position) or Vector3.new()
        for _,rec in pairs(data.Records) do
            if type(rec)=="table" and typeof(rec.BoundsCFrame)=="CFrame" then
                local d=(rec.BoundsCFrame.Position-myPos).Magnitude
                if (farthest and d>bd) or (not farthest and d<bd) then bd=d; best={uid=rec.Uid,pos=rec.BoundsCFrame.Position,slotKey=slotKey(rec),dist=d} end
            end
        end
    end
    return best
end

-- ───────── CARRIER (พาหนะล่องหน + BodyVelocity) ─────────
local carrier, carWeld, carBV
ENV.SAE_UNRIDE=function()
    if carBV then pcall(function() carBV:Destroy() end) carBV=nil end
    if carWeld then pcall(function() carWeld:Destroy() end) carWeld=nil end
    if carrier then pcall(function() carrier:Destroy() end) carrier=nil end
    log("ลงจาก carrier แล้ว")
end
local function makeCarrier()
    ENV.SAE_UNRIDE()
    local h=hrp(); if not h then return false end
    local p=Instance.new("Part")
    p.Name="GGXCarrier"; p.Size=Vector3.new(6,1,6)
    p.Transparency=1; p.CanCollide=false; p.Massless=true; p.Anchored=false
    p.CFrame=CFrame.new(h.Position)   -- ใต้ตัวเรา
    p.Parent=WS
    -- weld ตัวเรานั่งบน carrier
    local w=Instance.new("WeldConstraint"); w.Part0=h; w.Part1=p; w.Parent=p
    -- BodyVelocity ลากทั้งชุด (ฟิสิกส์ ไม่ teleport)
    local bv=Instance.new("BodyVelocity")
    bv.MaxForce=Vector3.new(1e9,1e9,1e9); bv.P=1e4; bv.Velocity=Vector3.zero; bv.Parent=p
    carrier,carWeld,carBV=p,w,bv
    return true
end
-- ลาก carrier ไปจุดหมายด้วยความเร็วคงที่ (ฟิสิกส์) จนถึง
local function driveTo(pos, tag)
    if not carrier or not carBV then if not makeCarrier() then return false end end
    local target=Vector3.new(pos.X, pos.Y+CFG.HOVER, pos.Z)
    local t0=os.clock(); local stuckT=os.clock(); local lastP
    while carrier and carrier.Parent do
        local h=hrp(); if not h then break end
        local cur=h.Position
        local delta=target-cur
        local dist=delta.Magnitude
        if dist<CFG.ARRIVE then break end
        carBV.Velocity = delta.Unit*CFG.SPEED
        -- anti-stuck: ถ้าไม่ขยับ 2 วิ ดันขึ้น
        if lastP and (cur-lastP).Magnitude<2 then
            if os.clock()-stuckT>2 then carBV.Velocity=carBV.Velocity+Vector3.new(0,CFG.SPEED*0.6,0); stuckT=os.clock() end
        else stuckT=os.clock() end
        lastP=cur
        if os.clock()-t0>20 then log("⚠️ "..(tag or "").." timeout"); break end
        RunService.Heartbeat:Wait()
    end
    if carBV then carBV.Velocity=Vector3.zero end
    return true
end

-- ───────── prompts (เผื่อไข่ต้องกด E) ─────────
local function firePrompts(pos)
    if typeof(fireproximityprompt)~="function" then return end
    for _,c in ipairs(WS:GetChildren()) do
        if c.Name=="SmartPromptPart" and c:IsA("BasePart") and (c.Position-pos).Magnitude<=22 then
            for _,p in ipairs(c:GetChildren()) do if p:IsA("ProximityPrompt") then pcall(function() p.Enabled=true p.HoldDuration=0 p.MaxActivationDistance=math.max(p.MaxActivationDistance or 0,60) p.RequiresLineOfSight=false fireproximityprompt(p) end) end end
        end
    end
end

-- ───────── commands ─────────
ENV.SAE_SETHOME=function()
    local h=hrp(); if not h then log("❌ ไม่เจอตัว"); return end
    CFG.HOME=h.Position
    log("🏠 จำจุดฝาก = "..P(CFG.HOME))
end
ENV.SAE_RIDEOUT=function(far)
    if far==nil then far=true end
    local egg=pickEgg(far)
    if not egg then log("❌ ไม่เจอไข่"); return nil end
    log("① ขี่ carrier ไปไข่"..(far and "ไกลสุด" or "ใกล้สุด").." @"..P(egg.pos).." (ห่าง "..math.floor(egg.dist or 0)..")")
    makeCarrier()
    driveTo(egg.pos,"ไป")
    log("② ถึงไข่ → spam เก็บ")
    local t=os.clock()
    while not carrying and os.clock()-t<CFG.GRAB_T do
        pcall(function() if EggState.CarryFieldEgg then EggState.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    log(carrying and "③ เก็บไข่ติดแล้ว ✅" or "③ ⚠️ เก็บไม่ติด (ลองต่อ)")
    return egg
end
ENV.SAE_RIDEHOME=function()
    local home=CFG.HOME
    if not home then log("❌ ยังไม่ตั้งบ้าน — SAE_SETHOME() ตอนยืนจุดฝากก่อน"); return end
    log("④ ขี่ carrier กลับบ้าน @"..P(home))
    if not carrier then makeCarrier() end
    driveTo(home,"กลับ")
    log("⑤ ถึงบ้าน → ลงจาก carrier (ฝากไข่)")
    task.wait(0.2)
    ENV.SAE_UNRIDE()
    task.wait(0.6)
    log(carrying and "⚠️ ยังถือไข่อยู่ (ฝากไม่ผ่าน?)" or "✅ ฝากไข่แล้ว (ปล่อยไข่)")
end
ENV.SAE_AUTORIDE=function(far)
    if not CFG.HOME then CFG.HOME=(hrp() and hrp().Position) or nil; log("(ใช้จุดปัจจุบันเป็นบ้าน — ควร SAE_SETHOME ตอนยืนจุดฝาก)") end
    local egg=ENV.SAE_RIDEOUT(far)
    if not egg then ENV.SAE_UNRIDE(); return end
    ENV.SAE_RIDEHOME()
end

if not CFG.HOME then CFG.HOME=(hrp() and hrp().Position) end
pcall(function() for _,n in ipairs({"SAE_SETHOME","SAE_RIDEOUT","SAE_RIDEHOME","SAE_AUTORIDE","SAE_UNRIDE"}) do _G[n]=ENV[n] end end)

log("✅ พร้อม (carrier ride — ฟิสิกส์ ไม่วาป ไม่โดนตี)")
log("1) ยืนจุดฝาก → SAE_SETHOME()   2) SAE_AUTORIDE() = ไป-เก็บ-กลับ-ฝาก")
log("ค่า: SPEED="..CFG.SPEED.." HOVER="..CFG.HOVER.." | บ้าน="..P(CFG.HOME))
