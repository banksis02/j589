-- ============================================================
-- STEAL AN EGG — NOTIFY + ชื่อไข่ (เทส) v1
--   = ตัว min (pure-read) + ได้ "ชื่อไข่" กลับมาจาก AskLiveSnapshot (invoke แบบ CACHE)
--   ❌ ไม่ hook  ❌ ไม่ VirtualUser/anti-afk  ❌ ไม่ report automation
--   ⚠️ invoke AskLiveSnapshot "เฉพาะตอนเจอไข่ GUID ใหม่" (ไม่ยิงทุกรอบ) — เทสว่า BAC ทนไหม
--     ถ้าเตะ = invoke คือปัญหา → กลับไปใช้ตัว min (ไม่มีชื่อ)
--     ถ้ารอด = ได้ชื่อไข่กลับมาใช้ได้
-- ============================================================
local SV = "names-v1"
_G.SAE_NOTIFY_GEN = (_G.SAE_NOTIFY_GEN or 0) + 1
local GEN = _G.SAE_NOTIFY_GEN
local function alive() return GEN == _G.SAE_NOTIFY_GEN end

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player      = Players.LocalPlayer
local PG          = player:WaitForChild("PlayerGui")
local ENV         = (type(getgenv) == "function" and getgenv()) or _G

local BACKEND_URL = "https://overload-backend-production.up.railway.app"
local INTERVAL    = 60

local function log(t) print("[SAE-NAMES " .. SV .. "] " .. tostring(t)) end
local function findDeep(root, ...)
    local node = root
    for _, n in ipairs({ ... }) do if not node then return nil end; node = node:FindFirstChild(n) end
    return node
end
local function strip(s) return (tostring(s):gsub("<[^>]->", "")) end
local function parseTime(t)
    local sec = 0
    for num, unit in string.gmatch(tostring(t), "(%d+)%s*([dhms])") do
        num = tonumber(num) or 0
        if unit=="d" then sec=sec+num*86400 elseif unit=="h" then sec=sec+num*3600
        elseif unit=="m" then sec=sec+num*60 elseif unit=="s" then sec=sec+num end
    end
    return sec
end
local function hudValue(kind)
    for _, hud in ipairs({ "GameHUD", "TradmilHud" }) do
        local lbl = findDeep(PG, "HUD", hud, "BottomLeft", kind, "Value")
        if lbl and lbl:IsA("TextLabel") then local t = strip(lbl.Text); if t ~= "" then return t end end
    end
    return "?"
end

-- ── ชื่อไข่: AskLiveSnapshot (invoke แบบ CACHE — เฉพาะตอนเจอ GUID ใหม่) ──
local NET = findDeep(RS, "Packages", "Networking")
local nameCache = {}
local function refreshNames()
    if not NET then return end
    local rf = NET:FindFirstChild("RF/EggWorld/AskLiveSnapshot")
    if not rf then return end
    local ok, snap = pcall(function() return rf:InvokeServer() end)
    if not ok or type(snap) ~= "table" then return end
    for _, entry in pairs(snap) do
        if type(entry)=="table" and entry.OwnerUserId==player.UserId and type(entry.Records)=="table" then
            for uid, rec in pairs(entry.Records) do
                if type(rec)=="table" and rec.AssetCategory then
                    local nm = tostring(rec.AssetCategory)
                    if rec.BaseMutation then nm = tostring(rec.BaseMutation).." "..nm end
                    nameCache[uid] = nm
                end
            end
        end
    end
end
local function readSlots()
    local out = {}
    local sf = findDeep(PG, "GrowingEggs", "Frame", "ScrollingFrame")
    if not sf then return out end
    for _, slot in ipairs(sf:GetChildren()) do
        if slot:IsA("Frame") and slot.Name~="Template" and slot.Name~="EmptyLast" then
            local tl = findDeep(slot, "Spacer", "Progress", "TextLabel")
            if tl and tl:IsA("TextLabel") then
                local tt = strip(tl.Text)
                if tt ~= "" then out[#out+1] = { uid=slot.Name, time=tt, seconds=parseTime(tt) } end
            end
        end
    end
    return out
end
local function getEggs()
    local slots = readSlots()
    local need = false
    for _, s in ipairs(slots) do if not nameCache[s.uid] then need = true break end end
    if need then pcall(refreshNames) end   -- invoke เฉพาะตอนมี GUID ใหม่ (cache)
    local eggs = {}
    for _, s in ipairs(slots) do
        eggs[#eggs+1] = { name = nameCache[s.uid] or "ไข่", time = s.time, seconds = s.seconds }
    end
    table.sort(eggs, function(a,b) return a.seconds < b.seconds end)
    return eggs
end

local function sendOnce()
    local money, speed = hudValue("Money"), hudValue("Speed")
    local eggs = getEggs()
    local area = "Steal An Egg"
    pcall(function() local a = player:GetAttribute("AreaId"); if a then area = tostring(a) end end)
    local payload = {
        username = player.Name, userId = player.UserId,
        serviceName = "Steal An Egg", gameId = "steal_an_egg", farming = true,
        currentStats = { money = money, speed = speed, growingCount = #eggs },
        growingEggs = eggs,
        matchInfo = { map = area, wave = 0 },
        recentLog = { act = money, file = area, playTime = "", quantity = speed, rewards = speed, status = "SNAPSHOT", wave = 0 },
    }
    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url = BACKEND_URL .. "/api/overload/update", Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
    log(("เงิน %s | เร็ว %s | ไข่ %d | ส่ง=%s"):format(money, speed, #eggs,
        (ok and type(res)=="table" and res.Success) and "OK" or "FAIL"))
end

ENV.SAE_MIN_STOP = function() ENV.SAE_MIN_RUNNING = false; log("หยุด") end
ENV.SAE_MIN_ONCE = function() pcall(sendOnce) end
local function start()
    if ENV.SAE_MIN_RUNNING then return end
    ENV.SAE_MIN_RUNNING = true
    log(("เริ่ม (ทุก %d วิ) — มีชื่อไข่ (invoke cache) ไม่มี VirtualUser"):format(INTERVAL))
    task.spawn(function()
        while alive() and ENV.SAE_MIN_RUNNING do
            pcall(sendOnce)
            local t = os.clock()
            while alive() and ENV.SAE_MIN_RUNNING and (os.clock()-t) < INTERVAL do task.wait(1) end
        end
        log("หยุดแล้ว")
    end)
end

log("โหลดแล้ว ✅ " .. SV .. " | Net=" .. (NET and "✅" or "❌"))
start()
