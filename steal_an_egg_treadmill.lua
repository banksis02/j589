-- ============================================================
-- STEAL AN EGG — TREADMILL (ลู่วิ่ง idle) — ยืนบนสายพานได้ Speed
-- recon: Plots.<N>.TreadmillBottom (ยืนบนได้ speed, ไม่มี prompt) + RE/Treadmill/SpeedGained
-- cmd: SAE_TREAD_ON() = ขึ้นลู่วิ่ง(ใกล้สุด/ที่ตั้งไว้) | SAE_TREAD_OFF() | SAE_TREAD_SET(n) เลือก Plot
--      SAE_TREAD_LIST() ดูลู่วิ่งทั้งหมด+ระยะ
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[TREAD] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

_G.SAE_TREAD_GEN=(_G.SAE_TREAD_GEN or 0)+1
local GEN=_G.SAE_TREAD_GEN
local function alive() return GEN==_G.SAE_TREAD_GEN end

local CFG={ STAND_Y=5, SET_PLOT=nil }   -- STAND_Y=ลอยเหนือสายพาน, SET_PLOT=ล็อก Plot (nil=ใกล้สุด)

-- หาลู่วิ่งทั้งหมด (Plots.<N>.TreadmillBottom)
local function allTreadmills()
    local out={}
    local plots=WS:FindFirstChild("Plots")
    if plots then for _,pl in ipairs(plots:GetChildren()) do
        local tb=pl:FindFirstChild("TreadmillBottom")
        if tb and tb:IsA("BasePart") then out[#out+1]={plot=pl.Name, part=tb, pos=tb.Position} end
    end end
    return out
end
local function myTreadmill()
    local t=allTreadmills()
    if #t==0 then return nil end
    if CFG.SET_PLOT then for _,x in ipairs(t) do if x.plot==tostring(CFG.SET_PLOT) then return x end end end
    -- ไม่ได้ล็อก → ใกล้สุด (ตอนอยู่บ้าน = ลู่ของเรา)
    local h=hrp(); local myPos=(h and h.Position) or Vector3.new()
    local best,bd=nil,1e9
    for _,x in ipairs(t) do local d=(x.pos-myPos).Magnitude if d<bd then bd=d; best=x end end
    return best
end

-- ยืนยัน Speed ขึ้น (connect SpeedGained + อ่าน leaderstats)
local NET=RS:FindFirstChild("Packages"); NET=NET and NET:FindFirstChild("Networking")
local SpeedGained=NET and NET:FindFirstChild("RE/Treadmill/SpeedGained")
local gainCount=0
pcall(function() if SpeedGained then SpeedGained.OnClientEvent:Connect(function() gainCount=gainCount+1 end) end end)
local function speedStat() local ls=player:FindFirstChild("leaderstats") local s=ls and ls:FindFirstChild("Speed") return s and s.Value or nil end

ENV.SAE_TREAD_LIST=function()
    local t=allTreadmills(); local h=hrp()
    log("ลู่วิ่ง "..#t.." อัน:")
    for _,x in ipairs(t) do local d=h and (x.pos-h.Position).Magnitude or -1
        print(("   Plot %s @%s ห่าง%.0f"):format(x.plot, P(x.pos), d)) end
    log("Speed ตอนนี้ = "..tostring(speedStat()))
end
ENV.SAE_TREAD_SET=function(n) CFG.SET_PLOT=n and tostring(n) or nil; log("ล็อกลู่วิ่ง Plot = "..(CFG.SET_PLOT or "ใกล้สุด(auto)")) end
-- ★ ยืนบนลู่ของคุณเอง แล้วเรียก = จำลู่นั้นเป็นลู่เรา (ชัวร์สุด)
ENV.SAE_TREAD_SETHERE=function()
    local t=allTreadmills(); local h=hrp()
    if not h or #t==0 then log("❌ ไม่มีตัว/ลู่"); return end
    local best,bd=nil,1e9
    for _,x in ipairs(t) do local d=(x.pos-h.Position).Magnitude if d<bd then bd=d; best=x end end
    if best then CFG.SET_PLOT=best.plot; log("✅ จำลู่ของเรา = Plot "..best.plot.." @"..P(best.pos).." (ห่าง "..math.floor(bd)..") — ต่อไป SAE_TREAD_ON() จะขึ้นลู่นี้เสมอ") end
end

-- ยืนบนลู่ 1 อัน hold (ใช้ทั้งตอนเทสหาลู่เรา + ตอนวิ่งจริง)
local holdTM=nil
local function holdLoop()
    task.spawn(function()
        while alive() and ENV.SAE_TREAD_RUN and holdTM do
            local h=hrp()
            if h and holdTM.part and holdTM.part.Parent then
                local target=holdTM.pos+Vector3.new(0,CFG.STAND_Y,0)
                if (h.Position-target).Magnitude>3 then pcall(function() h.CFrame=CFrame.new(target) end) end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
-- เทสลู่ 1 อันว่า Speed ขึ้นไหม (= ลู่ของเรา)
local function testTreadmill(tm, secs)
    holdTM=tm; ENV.SAE_TREAD_RUN=true; holdLoop()
    local s0=speedStat() or 0; local g0=gainCount
    local t=os.clock(); while alive() and os.clock()-t<(secs or 3.5) do RunService.Heartbeat:Wait() end
    local rose=(speedStat() or 0)>s0 or (gainCount-g0)>0
    return rose
end
ENV.SAE_TREAD_ON=function()
    local t=allTreadmills()
    if #t==0 then log("❌ ไม่เจอลู่วิ่ง"); return end
    -- ถ้าล็อกไว้แล้ว → ขึ้นเลย
    if CFG.SET_PLOT then
        local tm; for _,x in ipairs(t) do if x.plot==tostring(CFG.SET_PLOT) then tm=x end end
        if tm then log("🏃 ขึ้นลู่วิ่ง Plot "..tm.plot.." (ล็อกไว้)"); ENV.SAE_TREAD_RUN=true; holdTM=tm; holdLoop(); return end
    end
    -- auto-detect: เรียงใกล้สุด → เทสทีละอันจน Speed ขึ้น = ลู่เรา
    local h=hrp(); local myPos=(h and h.Position) or Vector3.new()
    table.sort(t,function(a,b) return (a.pos-myPos).Magnitude<(b.pos-myPos).Magnitude end)
    log("🔎 หาลู่ของเรา (เทสทีละอันว่า Speed ขึ้นไหม)...")
    for i,tm in ipairs(t) do
        if not (alive() and (ENV.SAE_TREAD_RUN~=false or i==1)) then break end
        log(("   ลอง Plot %s @%s"):format(tm.plot, P(tm.pos)))
        if testTreadmill(tm, 3.5) then
            CFG.SET_PLOT=tm.plot
            log("✅ ลู่ของเรา = Plot "..tm.plot.." (Speed ขึ้น) → ยืนต่อ"); return
        end
    end
    log("⚠️ เทสทุกลู่แล้ว Speed ไม่ขึ้น — อาจต้องอยู่ใกล้ฐานก่อน หรือลู่วิ่งเต็ม/ต้องกดเริ่ม บอกผมด้วยว่า Plot ไหนของคุณ")
    ENV.SAE_TREAD_RUN=false; holdTM=nil
end
ENV.SAE_TREAD_OFF=function() ENV.SAE_TREAD_RUN=false log("ลงจากลู่วิ่ง") end

pcall(function() for _,n in ipairs({"SAE_TREAD_ON","SAE_TREAD_OFF","SAE_TREAD_SET","SAE_TREAD_LIST"}) do _G[n]=ENV[n] end end)
log("✅ พร้อม — SAE_TREAD_LIST() ดูลู่ | SAE_TREAD_ON() ขึ้นลู่วิ่ง | ถ้าไม่ใช่ลู่เรา SAE_TREAD_SET(เลข Plot)")
