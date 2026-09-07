-- ============================================================
-- STEAL AN EGG — NOTIFY v0.1  (แจ้งเตือนขึ้น ggxshop.online ทุก 1 นาที)
--   อ่านล้วน + invoke AskLiveSnapshot (แบบเดียวกับ farm เดิม) — ไม่ hook
--   ส่ง: เงินรวม + ความเร็ว + ไข่ที่กำลังฟัก (ชื่อ+เวลาเหลือ)
--
--   SAE_NOTIFY_ONCE()   = อ่าน+ส่ง 1 ครั้ง (ทดสอบ, print ผล)
--   SAE_NOTIFY_START()  = ส่งวนทุก 60 วิ   /   SAE_NOTIFY_STOP() = หยุด
-- ============================================================

local SCRIPT_VERSION = "v0.1"
_G.SAE_NOTIFY_GEN = (_G.SAE_NOTIFY_GEN or 0) + 1
local GEN = _G.SAE_NOTIFY_GEN
local function alive() return GEN == _G.SAE_NOTIFY_GEN end

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player      = Players.LocalPlayer
local PG          = player:WaitForChild("PlayerGui")
local ENV         = (type(getgenv) == "function" and getgenv()) or _G

local CFG = {
    BACKEND_URL = "https://overload-backend-production.up.railway.app",
    INTERVAL    = 60,   -- วินาที
}

local function log(t) print("[SAE-NOTIFY " .. SCRIPT_VERSION .. "] " .. tostring(t)) end

-- ── helpers ─────────────────────────────────────────────────
local function findDeep(root, ...)
    local node = root
    for _, n in ipairs({ ... }) do
        if not node then return nil end
        node = node:FindFirstChild(n)
    end
    return node
end
local function strip(s) return (tostring(s):gsub("<[^>]->", "")) end

-- ย่อเลขเป็น K/M/B/T/Qa/Qi (เผื่อ fallback จาก leaderstat ดิบ)
local UNITS = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function abbrev(n)
    n = tonumber(n) or 0
    local neg = n < 0; n = math.abs(n)
    local i = 1
    while n >= 1000 and i < #UNITS do n = n / 1000; i = i + 1 end
    local s
    if i == 1 then s = string.format("%.0f", n)
    elseif n < 10 then s = string.format("%.2f", n)
    elseif n < 100 then s = string.format("%.1f", n)
    else s = string.format("%.0f", n) end
    s = s:gsub("%.?0+$", "")
    return (neg and "-" or "") .. s .. UNITS[i]
end

-- "1h 3m" / "27m 45s" / "38s" / "21h 56m" → วินาที
local function parseTime(t)
    local sec = 0
    for num, unit in string.gmatch(tostring(t), "(%d+)%s*([dhms])") do
        num = tonumber(num) or 0
        if unit == "d" then sec = sec + num * 86400
        elseif unit == "h" then sec = sec + num * 3600
        elseif unit == "m" then sec = sec + num * 60
        elseif unit == "s" then sec = sec + num end
    end
    return sec
end

-- ── เงิน + ความเร็ว (อ่าน HUD label ที่ย่อหน่วยแล้ว) ─────────────
local function hudValue(kind)  -- "Money" | "Speed"
    for _, hud in ipairs({ "GameHUD", "TradmilHud" }) do
        local lbl = findDeep(PG, "HUD", hud, "BottomLeft", kind, "Value")
        if lbl and lbl:IsA("TextLabel") then
            local t = strip(lbl.Text)
            if t ~= "" then return t end
        end
    end
    return nil
end
local function getMoney()
    return hudValue("Money") or "?"
end
local function getSpeed()
    local s = hudValue("Speed")
    if s then return s end
    -- fallback: leaderstats.Speed (ดิบ) → ย่อเอง
    local ls = player:FindFirstChild("leaderstats")
    local sp = ls and ls:FindFirstChild("Speed")
    if sp then return abbrev(sp.Value) end
    return "?"
end

-- ── ไข่ที่กำลังโต: GUI (uid+timer) + AskLiveSnapshot (ชื่อ) ────────
local NET = findDeep(RS, "Packages", "Networking")
local nameCache = {}  -- uid → ชื่อไข่ (AssetCategory)

local function refreshNames()
    if not NET then return end
    local snapRF = NET:FindFirstChild("RF/EggWorld/AskLiveSnapshot")
    if not snapRF then return end
    local ok, snap = pcall(function() return snapRF:InvokeServer() end)
    if not ok or type(snap) ~= "table" then return end
    for _, entry in pairs(snap) do
        if type(entry) == "table" and entry.OwnerUserId == player.UserId and type(entry.Records) == "table" then
            for uid, rec in pairs(entry.Records) do
                if type(rec) == "table" and rec.AssetCategory then
                    local nm = tostring(rec.AssetCategory)
                    if rec.BaseMutation then nm = tostring(rec.BaseMutation) .. " " .. nm end
                    nameCache[uid] = nm
                end
            end
        end
    end
end

local function readGrowing()
    local out = {}
    local sf = findDeep(PG, "GrowingEggs", "Frame", "ScrollingFrame")
    if not sf then return out end
    for _, slot in ipairs(sf:GetChildren()) do
        if slot:IsA("Frame") and slot.Name ~= "Template" and slot.Name ~= "EmptyLast" then
            local tl = findDeep(slot, "Spacer", "Progress", "TextLabel")
            if tl and tl:IsA("TextLabel") then
                local timeText = strip(tl.Text)
                if timeText ~= "" then
                    out[#out + 1] = { uid = slot.Name, time = timeText, seconds = parseTime(timeText) }
                end
            end
        end
    end
    return out
end

local function getEggs()
    local slots = readGrowing()
    -- ต้องรู้ชื่อ: ถ้ามี uid ไหนยังไม่ cache → invoke snapshot รอบเดียว
    local need = false
    for _, s in ipairs(slots) do if not nameCache[s.uid] then need = true break end end
    if need then pcall(refreshNames) end
    local eggs = {}
    for _, s in ipairs(slots) do
        eggs[#eggs + 1] = { name = nameCache[s.uid] or "Egg", time = s.time, seconds = s.seconds }
    end
    table.sort(eggs, function(a, b) return a.seconds < b.seconds end)
    return eggs
end

-- ── ส่งขึ้น backend ─────────────────────────────────────────
local function sendOnce()
    local money, speed = getMoney(), getSpeed()
    local eggs = getEggs()
    local area = "Steal An Egg"
    pcall(function() local a = player:GetAttribute("AreaId"); if a then area = tostring(a) end end)

    local payload = {
        username    = player.Name,
        userId      = player.UserId,
        serviceName = "Steal An Egg",
        gameId      = "steal_an_egg",
        farming     = true,
        currentStats = {
            money = money,
            speed = speed,
            growingCount = #eggs,
        },
        growingEggs = eggs,
        matchInfo   = { map = area, wave = 0 },
        -- ⭐ บันทึกลง Mission Log ทุกรอบ (เงิน/ความเร็ว/เวลา) — backend ใส่ timestamp เอง
        recentLog   = {
            act      = money,
            file     = area,
            playTime = "",
            quantity = speed,
            rewards  = speed,
            status   = "SNAPSHOT",
            wave     = 0,
        },
    }

    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url = CFG.BACKEND_URL .. "/api/overload/update",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
    local sent = ok and type(res) == "table" and res.Success
    local soon = {}
    for _, e in ipairs(eggs) do if e.seconds > 0 and e.seconds <= 300 then soon[#soon + 1] = e.name end end
    log(("เงิน %s | ความเร็ว %s | ไข่โต %d ใบ%s | ส่ง=%s")
        :format(money, speed, #eggs,
            (#soon > 0 and (" | ⏰ ใกล้ฟัก: " .. table.concat(soon, ", ")) or ""),
            sent and "OK ✅" or ("FAIL " .. tostring(ok and res and res.StatusCode or res))))
    return sent
end

-- ── COMMANDS ────────────────────────────────────────────────
ENV.SAE_NOTIFY_ONCE = function() return sendOnce() end
ENV.SAE_NOTIFY_STOP = function() ENV.SAE_NOTIFY_RUNNING = false; log("สั่งหยุด") end
ENV.SAE_NOTIFY_START = function()
    if ENV.SAE_NOTIFY_RUNNING then log("กำลังรันอยู่แล้ว"); return end
    ENV.SAE_NOTIFY_RUNNING = true
    log(("▶️ เริ่มแจ้งเตือนทุก %d วิ (หยุด: SAE_NOTIFY_STOP())"):format(CFG.INTERVAL))
    task.spawn(function()
        while alive() and ENV.SAE_NOTIFY_RUNNING do
            pcall(sendOnce)
            local t0 = os.clock()
            while alive() and ENV.SAE_NOTIFY_RUNNING and (os.clock() - t0) < CFG.INTERVAL do
                task.wait(1)
            end
        end
        log("⏹️ หยุดแล้ว")
    end)
end

log("โหลดแล้ว ✅ v" .. SCRIPT_VERSION .. " | Net=" .. (NET and "✅" or "❌"))
log("SAE_NOTIFY_ONCE() ทดสอบ 1 ครั้ง / SAE_NOTIFY_START() ส่งวนทุก " .. CFG.INTERVAL .. " วิ")
