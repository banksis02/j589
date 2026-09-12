-- ============================================================
-- STEAL AN EGG — RIDE GUARD TEST (ทดสอบขี่ยาม = ให้ server ขยับเรา ไม่ desync)
-- weld ตัวติดยาม (guard = server-controlled) → ยามพาเราไป = anti-cheat ไม่จับ
-- SAE_RIDE() = ขี่ยามใกล้สุด | SAE_UNRIDE() = ลง | SAE_RGUARDS() = ดูยามในแมพ
-- ============================================================
local Players = game:GetService("Players")
local WS      = game:GetService("Workspace")
local RS      = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player  = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[RIDE] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

-- EggState (สำหรับเก็บไข่เพื่อล่อยามให้ไล่)
local EggState; pcall(function() EggState=require(RS:WaitForChild("Client",10):WaitForChild("EggState",10)) end)
local carrying=false
pcall(function() if EggState and EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local function pickEgg(farthest)
    if not EggState then return nil end
    local best,bd=nil, farthest and -1 or 1e9
    local ok,data=pcall(function() EggState.SyncFieldEggs(); return EggState.ReadFieldEggs() end)
    if ok and type(data)=="table" and type(data.Records)=="table" then
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

-- หายามทั้งหมด (มี Humanoid+HRP)
local function allGuards()
    local out={}
    local function scan(root) if not root then return end pcall(function()
        for _,m in ipairs(root:GetDescendants()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                local gh=m:FindFirstChild("HumanoidRootPart") or (m.PrimaryPart)
                if gh and m~=player.Character then out[#out+1]={model=m,root=gh} end
            end
        end
    end) end
    scan(WS:FindFirstChild("_Guards"))
    local a=WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas"); a=a and a:FindFirstChild("GuardAreas")
    scan(a)
    return out
end
local function nearestGuard()
    local h=hrp(); if not h then return nil end
    local best,bd=nil,1e9
    for _,g in ipairs(allGuards()) do
        local ok,d=pcall(function() return (g.root.Position-h.Position).Magnitude end)
        if ok and d<bd then bd=d; best=g end
    end
    return best,bd
end

ENV.SAE_RGUARDS=function()
    local gs=allGuards(); log("ยามในแมพ "..#gs.." ตัว:")
    local h=hrp()
    for i,g in ipairs(gs) do if i<=12 then local d=h and (g.root.Position-h.Position).Magnitude or -1
        print(("  #%d %s @%s ห่าง %.0f"):format(i, g.model:GetFullName():gsub("Workspace%.",""), P(g.root.Position), d)) end end
end

local rideWeld, rideConn
ENV.SAE_UNRIDE=function()
    if rideConn then pcall(function() rideConn:Disconnect() end) rideConn=nil end
    if rideWeld then pcall(function() rideWeld:Destroy() end) rideWeld=nil end
    log("ลงจากยามแล้ว")
end
ENV.SAE_RIDE=function()
    ENV.SAE_UNRIDE()
    local g,d=nearestGuard()
    if not g then log("❌ ไม่เจอยาม"); return end
    log("🐴 ขี่ยาม "..g.model.Name.." (ห่าง "..math.floor(d)..") — weld ตัวติด")
    local h=hrp(); if not h then return end
    -- วิธี 1: weld HRP ติดยาม (บนหัวยาม) → ยาม(server)ขยับ = เราขยับตาม
    local w=Instance.new("Weld")
    w.Part0=g.root; w.Part1=h
    w.C0=CFrame.new(0,5,0)   -- นั่งเหนือยาม 5 studs
    w.Parent=g.root
    rideWeld=w
    -- log ตำแหน่งทุก 0.5s ดูว่ายามพาไปไหน + Y สูงขึ้น (บนยาม) + ไม่ดึงกลับ
    local t0=os.clock(); local lastLog=0
    rideConn=RunService.Heartbeat:Connect(function()
        if os.clock()-lastLog>0.5 then lastLog=os.clock()
            local hh=hrp(); local gr=g.root
            if hh and gr and gr.Parent then
                local st = g.model:GetAttribute("GuardState") or "?"
                local tp = g.model:GetAttribute("TargetPlayer") or ""
                log(("t+%.0fs เรา %s | ยาม %s | สถานะ=%s target=%s"):format(os.clock()-t0, P(hh.Position), P(gr.Position), tostring(st), tostring(tp)))
            else log("ยาม/ตัวหาย → ลง"); ENV.SAE_UNRIDE() end
        end
    end)
end
-- ★ AUTO: เก็บไข่ใกล้สุด (ล่อยามให้ไล่) → ขี่ยามอัตโนมัติ → ดูยามพาไปไหน
local function firePrompts(pos)
    if typeof(fireproximityprompt)~="function" then return end
    for _,c in ipairs(WS:GetChildren()) do
        if c.Name=="SmartPromptPart" and c:IsA("BasePart") and (c.Position-pos).Magnitude<=22 then
            for _,p in ipairs(c:GetChildren()) do if p:IsA("ProximityPrompt") then pcall(function() p.Enabled=true p.HoldDuration=0 p.MaxActivationDistance=math.max(p.MaxActivationDistance or 0,60) p.RequiresLineOfSight=false fireproximityprompt(p) end) end end
        end
    end
end
-- tween ไปจุด (TweenService ลื่น — ไม่วาป)
local TweenService=game:GetService("TweenService")
local function tweenTo(pos, speed)
    speed=speed or 120        -- studs/วิ (ยิ่งน้อยยิ่งลื่นช้า; ไม่ใช่วาป)
    local h=hrp(); if not h then return false end
    local dest=CFrame.new(pos.X, pos.Y+3, pos.Z)
    local d=(dest.Position-h.Position).Magnitude
    if d<6 then return true end
    local tw=TweenService:Create(h, TweenInfo.new(d/speed, Enum.EasingStyle.Linear), {CFrame=dest})  -- ★ ไม่ cap = ลื่นจริง
    tw:Play(); tw.Completed:Wait()
    return true
end
-- ★ AUTO: tween ไปไข่ไกลสุด → เก็บ (ล่อยาม) → ขี่ยาม (ไม่วาป)
ENV.SAE_AUTORIDE=function()
    ENV.SAE_UNRIDE()
    local egg=pickEgg(true)
    if not egg then log("❌ ไม่เจอไข่"); return end
    log("① tween ไปไข่ไกลสุด @"..P(egg.pos).." (ห่าง "..math.floor(egg.dist or 0)..")")
    tweenTo(egg.pos, 250)
    log("② เก็บไข่ (ล่อยาม)")
    local t=os.clock()
    while not carrying and os.clock()-t<6 do
        pcall(function() if EggState.CarryFieldEgg then EggState.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    log(carrying and "③ เก็บได้ → ขี่ยาม" or "③ เก็บไม่ติด แต่ลองขี่ยามใกล้สุดดู")
    task.wait(0.4)
    ENV.SAE_RIDE()
end

pcall(function() for _,n in ipairs({"SAE_RIDE","SAE_UNRIDE","SAE_RGUARDS","SAE_AUTORIDE"}) do _G[n]=ENV[n] end end)

log("✅ พร้อม — SAE_AUTORIDE() = เก็บไข่+ขี่ยามอัตโนมัติ | SAE_RGUARDS() ดูยาม | SAE_UNRIDE() ลง")
log("ทดสอบ: SAE_AUTORIDE() แล้วดู log ว่ายาม(ตอนไล่)พาเราไปไหน")
