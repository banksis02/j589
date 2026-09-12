-- ============================================================
-- STEAL AN EGG — RIDE GUARD TEST (ทดสอบขี่ยาม = ให้ server ขยับเรา ไม่ desync)
-- weld ตัวติดยาม (guard = server-controlled) → ยามพาเราไป = anti-cheat ไม่จับ
-- SAE_RIDE() = ขี่ยามใกล้สุด | SAE_UNRIDE() = ลง | SAE_RGUARDS() = ดูยามในแมพ
-- ============================================================
local Players = game:GetService("Players")
local WS      = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player  = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[RIDE] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

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
                log(("t+%.0fs ตัวเรา %s | ยาม %s"):format(os.clock()-t0, P(hh.Position), P(gr.Position)))
            else log("ยาม/ตัวหาย → ลง"); ENV.SAE_UNRIDE() end
        end
    end)
end
pcall(function() for _,n in ipairs({"SAE_RIDE","SAE_UNRIDE","SAE_RGUARDS"}) do _G[n]=ENV[n] end end)

log("✅ พร้อม — SAE_RGUARDS() ดูยาม | SAE_RIDE() ขี่ยามใกล้สุด | SAE_UNRIDE() ลง")
log("ทดสอบ: SAE_RIDE() แล้วดูว่า 'ตัวเรา' ขยับตามยามไหม + Y สูงขึ้น (บนยาม) + ไม่โดนดึงกลับ")
