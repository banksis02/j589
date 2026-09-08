-- ============================================================
-- STEAL AN EGG — NOTIFY MINIMAL v1  (pure-read ขั้นต่ำสุด — เทสว่ารอด BAC บนบอทไหม)
--   ส่งแค่ "แจ้งเตือน" อย่างเดียว: อ่านค่า + POST ขึ้น ggxshop (overload) ทุก 60 วิ
--   ❌ ไม่ invoke remote เกม  ❌ ไม่ hook  ❌ ไม่ VirtualUser/anti-afk  ❌ ไม่รายงาน automation
--   อ่าน: เงิน+ความเร็ว (HUD label) + ไข่กำลังโต (timer จาก GUI) เท่านั้น
-- ============================================================
local SV = "min-v1"
_G.SAE_NOTIFY_GEN = (_G.SAE_NOTIFY_GEN or 0) + 1
local GEN = _G.SAE_NOTIFY_GEN
local function alive() return GEN == _G.SAE_NOTIFY_GEN end

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player      = Players.LocalPlayer
local PG          = player:WaitForChild("PlayerGui")
local ENV         = (type(getgenv) == "function" and getgenv()) or _G

local BACKEND_URL = "https://overload-backend-production.up.railway.app"
local INTERVAL    = 60

local function log(t) print("[SAE-MIN " .. SV .. "] " .. tostring(t)) end
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
        if unit == "d" then sec = sec + num*86400 elseif unit == "h" then sec = sec + num*3600
        elseif unit == "m" then sec = sec + num*60 elseif unit == "s" then sec = sec + num end
    end
    return sec
end

-- เงิน/ความเร็ว จาก HUD label (อ่านล้วน)
local function hudValue(kind)
    for _, hud in ipairs({ "GameHUD", "TradmilHud" }) do
        local lbl = findDeep(PG, "HUD", hud, "BottomLeft", kind, "Value")
        if lbl and lbl:IsA("TextLabel") then local t = strip(lbl.Text); if t ~= "" then return t end end
    end
    return "?"
end

-- ไข่กำลังโต: อ่าน timer จาก GUI GrowingEggs (ไม่ invoke — ไม่มีชื่อ ใช้ label กลาง)
local function getEggs()
    local out = {}
    local sf = findDeep(PG, "GrowingEggs", "Frame", "ScrollingFrame")
    if not sf then return out end
    for _, slot in ipairs(sf:GetChildren()) do
        if slot:IsA("Frame") and slot.Name ~= "Template" and slot.Name ~= "EmptyLast" then
            local tl = findDeep(slot, "Spacer", "Progress", "TextLabel")
            if tl and tl:IsA("TextLabel") then
                local timeText = strip(tl.Text)
                if timeText ~= "" then out[#out + 1] = { name = "ไข่", time = timeText, seconds = parseTime(timeText) } end
            end
        end
    end
    table.sort(out, function(a, b) return a.seconds < b.seconds end)
    return out
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
        (ok and type(res) == "table" and res.Success) and "OK" or "FAIL"))
end

ENV.SAE_MIN_STOP = function() ENV.SAE_MIN_RUNNING = false; log("หยุด") end
ENV.SAE_MIN_ONCE = function() pcall(sendOnce) end
local function start()
    if ENV.SAE_MIN_RUNNING then return end
    ENV.SAE_MIN_RUNNING = true
    log(("เริ่ม (ทุก %d วิ) — pure read ล้วน"):format(INTERVAL))
    task.spawn(function()
        while alive() and ENV.SAE_MIN_RUNNING do
            pcall(sendOnce)
            local t = os.clock()
            while alive() and ENV.SAE_MIN_RUNNING and (os.clock() - t) < INTERVAL do task.wait(1) end
        end
        log("หยุดแล้ว")
    end)
end

log("โหลดแล้ว ✅ " .. SV)
start()
