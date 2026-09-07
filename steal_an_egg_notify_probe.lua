-- ============================================================
-- STEAL AN EGG — NOTIFY RECON (อ่านล้วน 100% ไม่ยิง remote ไม่ hook)
--   หา path ของ: 1) เงิน  2) ความเร็ว  3) ไข่ที่กำลังโต (Growing Eggs) + เวลา
--   สำหรับสร้างตัวแจ้งเตือนทุก 1 นาที
--   ปลอดภัย: อ่าน leaderstats / attributes / PlayerGui text เท่านั้น
--   (list ชื่อ remote เฉยๆ ไม่ InvokeServer)
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local PG      = player:WaitForChild("PlayerGui")

local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[NOTIFY] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied to clipboard ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "egg_notify.txt", text) end
end
local function attrs(inst)
    local ok, a = pcall(function() return inst:GetAttributes() end)
    if not ok or type(a) ~= "table" then return "{}" end
    local p = {}
    for k, v in pairs(a) do p[#p+1] = tostring(k) .. "=" .. tostring(v) end
    return "{" .. table.concat(p, ", ") .. "}"
end
-- ScreenGui ใช้ .Enabled / Frame ใช้ .Visible — เช็คแบบ pcall กันสคริปต์ตาย
local function vis(inst)
    local ok, v = pcall(function()
        if inst:IsA("ScreenGui") or inst:IsA("LayerCollector") then return inst.Enabled end
        return inst.Visible
    end)
    if not ok then return "?" end
    return tostring(v)
end

add("════════════════════════════════════════")
add("NOTIFY RECON  Place=" .. tostring(game.PlaceId) .. "  Player=" .. player.Name)
add("════════════════════════════════════════")

-- 1) LEADERSTATS (เงิน + ความเร็ว มักอยู่ตรงนี้) -----------------
add("")
add("── LEADERSTATS ──")
local ls = player:FindFirstChild("leaderstats")
if ls then
    for _, v in ipairs(ls:GetChildren()) do
        add(("  %s = %s   [%s]"):format(v.Name, tostring(v.Value), v.ClassName))
    end
else
    add("  (ไม่มี leaderstats)")
end
add("  player.attrs = " .. attrs(player))

-- บาง object เก็บเงินเป็น value ใต้ player (ไม่ใช่ leaderstats)
add("")
add("── ValueObjects ใต้ player (นอก leaderstats) ──")
for _, d in ipairs(player:GetDescendants()) do
    if d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("StringValue") then
        if not (ls and d:IsDescendantOf(ls)) then
            add(("  %s = %s   [%s]"):format(d:GetFullName(), tostring(d.Value), d.ClassName))
        end
    end
end

-- 2) PlayerGui — หา TextLabel ที่โชว์ เงิน / ความเร็ว / เวลาไข่ ----
--    ดัมพ์ label ที่มีตัวเลข/เวลา เพื่อระบุ path จริงบนหน้าจอ
add("")
add("── PlayerGui text labels (เงิน/speed/timer) ──")
local MONEY_HINT = { "$", "cash", "coin", "money", "gem", "speed", "/s" }
local TIME_PAT   = { "%d+h%s*%d+m", "%d+m%s*%d+s", "%d+:%d+", "%d+s$" }
local shown = 0
for _, d in ipairs(PG:GetDescendants()) do
    if d:IsA("TextLabel") or d:IsA("TextButton") then
        local txt = tostring(d.Text)
        if txt ~= "" then
            local low = string.lower(txt)
            local hit = false
            for _, h in ipairs(MONEY_HINT) do if string.find(low, h, 1, true) then hit = true break end end
            if not hit then
                for _, p in ipairs(TIME_PAT) do if string.match(low, p) then hit = true break end end
            end
            -- โชว์เฉพาะที่ดูเป็นตัวเลข/เวลา/สกุลเงิน
            if hit and shown < 80 then
                shown = shown + 1
                add(("  \"%s\"  <- %s"):format(txt, d:GetFullName()))
            end
        end
    end
end
add("  (แสดง " .. shown .. " labels ที่เข้าเงื่อนไข)")

-- 3) หา GUI panel "Growing Eggs" โดยตรง ------------------------
add("")
add("── ScreenGui / Frame ชื่อเกี่ยวกับ Grow/Egg/Hatch + ดัมพ์ TextLabel ข้างใน ──")
local GUI_KW = { "grow", "egg", "hatch", "incubat", "pet" }
for _, d in ipairs(PG:GetDescendants()) do
    if d:IsA("ScreenGui") or d:IsA("Frame") or d:IsA("ScrollingFrame") then
        local low = string.lower(d.Name)
        local matched = false
        for _, kw in ipairs(GUI_KW) do
            if string.find(low, kw, 1, true) then matched = true break end
        end
        if matched then
            add(("  <%s> %s  visible=%s"):format(d.ClassName, d:GetFullName(), vis(d)))
            -- ดัมพ์ label ข้างใน (ชื่อไข่ + เวลา) — จำกัด 25 ตัวกันล้น
            local cnt = 0
            for _, c in ipairs(d:GetDescendants()) do
                if (c:IsA("TextLabel") or c:IsA("TextButton")) and tostring(c.Text) ~= "" then
                    cnt = cnt + 1
                    if cnt <= 25 then
                        add(("      · [%s] %s = \"%s\""):format(c.ClassName, c.Name, tostring(c.Text)))
                    end
                end
            end
            if cnt > 25 then add(("      · ... (อีก %d labels)"):format(cnt - 25)) end
        end
    end
end

-- 4) REMOTE NAMES (list เฉยๆ — ไม่ยิง) หา snapshot ไข่โต --------
add("")
add("── REMOTE names (Grow/Hatch/Incubat/Snapshot/Egg) — list เฉยๆ ──")
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteFunction") or d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then
        local low = string.lower(d.Name)
        if string.find(low, "grow") or string.find(low, "hatch") or string.find(low, "incubat")
            or string.find(low, "snapshot") or string.find(low, "egg") then
            add(("  [%s] %s"):format(d.ClassName, d:GetFullName()))
        end
    end
end

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
