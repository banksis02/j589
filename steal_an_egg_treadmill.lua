-- ============================================================
-- STEAL AN EGG — TREADMILL (ลู่วิ่ง) via REMOTE (จาก moa456811 auto_training)
-- ★ ไม่ต้องยืน/ไม่ต้องหา plot: ยิง remote server จับขึ้นลู่ของเราเอง (ไม่สน spawn ที่ไหน)
--   AskWearStill = ขึ้นลู่ | AskRenderSnapshot = เช็ค mount | AskDoff = ลงลู่
-- cmd: SAE_TREAD_ON() ขึ้นลู่ | SAE_TREAD_OFF() ลง | SAE_TREAD_STATUS() เช็ค
-- ============================================================
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[TREAD] "..tostring(t)) end

_G.SAE_TREAD_GEN=(_G.SAE_TREAD_GEN or 0)+1
local GEN=_G.SAE_TREAD_GEN
local function alive() return GEN==_G.SAE_TREAD_GEN end

-- หา remote (recon เจอที่ RS.Packages.Networking.RF/Treadmill/*)
local NET=RS:FindFirstChild("Packages"); NET=NET and NET:FindFirstChild("Networking")
local function findRemote(name)
    if not NET then return nil end
    return NET:FindFirstChild("RF/Treadmill/"..name) or NET:FindFirstChild("RE/Treadmill/"..name)
end
local WearStill=findRemote("AskWearStill")
local Snapshot =findRemote("AskRenderSnapshot")
local Doff     =findRemote("AskDoff")
log("remote: WearStill="..tostring(WearStill~=nil).." Snapshot="..tostring(Snapshot~=nil).." Doff="..tostring(Doff~=nil))

local function speedStat() local ls=player:FindFirstChild("leaderstats") local s=ls and ls:FindFirstChild("Speed") return s and s.Value or nil end
-- เช็คว่า mount อยู่ไหม (จาก snapshot — moa ใช้ snapshot เป็น table = mount)
local function isMounted()
    if not Snapshot then return nil end   -- nil = เช็คไม่ได้
    local ok,snap=pcall(function() return Snapshot:InvokeServer() end)
    if not ok or type(snap)~="table" then return false end
    -- หา field ที่บอก mounted (mounted/wearing/active/onBelt); ถ้าไม่มี ถือว่า table=mounted
    for _,k in ipairs({"Mounted","Wearing","Active","OnBelt","IsWearing","Worn"}) do
        if snap[k]~=nil then return snap[k]==true end
    end
    return true
end
local function wear()
    if not WearStill then return false,"no remote" end
    return pcall(function() return WearStill:InvokeServer() end)
end

ENV.SAE_TREAD_STATUS=function()
    log("Speed="..tostring(speedStat()).." | mounted="..tostring(isMounted()))
    if Snapshot then local ok,s=pcall(function() return Snapshot:InvokeServer() end) if ok and type(s)=="table" then
        local ks={} for k,v in pairs(s) do ks[#ks+1]=k.."="..tostring(v) end
        log("snapshot: {"..table.concat(ks,", ").."}") end end
end

ENV.SAE_TREAD_ON=function()
    if not WearStill then log("❌ ไม่เจอ remote AskWearStill (path อาจต่าง — รัน recon)"); return end
    ENV.SAE_TREAD_RUN=true
    log("🏃 ขึ้นลู่วิ่ง (AskWearStill) ...")
    local s0=speedStat() or 0
    task.spawn(function()
        while alive() and ENV.SAE_TREAD_RUN do
            local m=isMounted()
            if m==false or m==nil then wear() end   -- ยังไม่ mount / เช็คไม่ได้ → ยิงขึ้นลู่
            task.wait(3)                              -- keep mounted (ไม่ spam)
        end
    end)
    task.spawn(function() task.wait(6)
        if alive() and ENV.SAE_TREAD_RUN then
            local now=speedStat() or 0
            log(("เช็ค 6 วิ: Speed %s→%s %s | mounted=%s"):format(tostring(s0), tostring(now),
                (now>s0 and "▲ขึ้น✅" or "(ดูยาก—Speed ขึ้นเองด้วย)"), tostring(isMounted())))
        end
    end)
end
ENV.SAE_TREAD_OFF=function()
    ENV.SAE_TREAD_RUN=false
    if Doff then pcall(function() Doff:InvokeServer() end) log("ลงลู่ (AskDoff)") else log("หยุด (ไม่มี AskDoff)") end
end

pcall(function() for _,n in ipairs({"SAE_TREAD_ON","SAE_TREAD_OFF","SAE_TREAD_STATUS"}) do _G[n]=ENV[n] end end)
log("✅ พร้อม — SAE_TREAD_ON() ขึ้นลู่ (remote ไม่ต้องยืน/ไม่สน plot) | SAE_TREAD_STATUS() เช็ค | SAE_TREAD_OFF() ลง")
