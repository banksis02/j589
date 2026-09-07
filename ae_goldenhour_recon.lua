-- ============================================================
-- ANIME EXPEDITIONS — RECON: Golden Hour + Crimson Shore (อ่านล้วน)
--   เปิดหน้า STORY MAP (เกาะๆ) ก่อนรัน จะได้เห็น badge Golden Hour + ชื่อด่านใหม่
--   ดัมพ์: 1) label ชื่อด่าน/Golden/Crimson  2) element ที่ชื่อมี Golden/Hour/Crimson
--          3) โครงการ์ดด่าน (หา badge เกาะไหนมี Golden Hour)  4) ScreenGui ที่เปิดอยู่
-- ============================================================

local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local PG      = player:WaitForChild("PlayerGui")

local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[AE] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "ae_goldenhour.txt", text) end
end
local function strip(s) return (tostring(s):gsub("<[^>]->", "")) end

add("════════ AE RECON  Place=" .. tostring(game.PlaceId) .. " ════════")

-- 0) ScreenGui ที่เปิด/เห็นอยู่
add(""); add("── ScreenGui (enabled) ──")
for _, sg in ipairs(PG:GetChildren()) do
    if sg:IsA("ScreenGui") or sg:IsA("Folder") then
        add(("  <%s> %s  enabled=%s"):format(sg.ClassName, sg.Name, tostring(sg:IsA("ScreenGui") and sg.Enabled)))
    end
end

-- 1) label ชื่อด่าน / Golden Hour / Crimson
add(""); add("── labels (ด่าน/Golden/Crimson/Hour) ──")
local KW = { "school grounds", "flower forest", "rose kingdom", "east town", "fairy king", "tomb",
             "crimson", "golden hour", "golden", "hour", "shore" }
local shown = 0
for _, d in ipairs(PG:GetDescendants()) do
    if (d:IsA("TextLabel") or d:IsA("TextButton")) then
        local txt = strip(d.Text)
        if txt ~= "" then
            local low = string.lower(txt)
            for _, kw in ipairs(KW) do
                if string.find(low, kw, 1, true) then
                    shown = shown + 1
                    if shown <= 60 then add(("  \"%s\"  <- %s"):format(txt, d:GetFullName())) end
                    break
                end
            end
        end
    end
end
add("  (เจอ " .. shown .. ")")

-- 2) element ที่ "ชื่อ (Name)" มี Golden/Hour/Crimson — หา badge/marker/tab
add(""); add("── instances ที่ Name มี Golden/Hour/Crimson ──")
local n2 = 0
for _, d in ipairs(PG:GetDescendants()) do
    local nm = string.lower(d.Name)
    if string.find(nm, "golden") or string.find(nm, "hour") or string.find(nm, "crimson") then
        n2 = n2 + 1
        if n2 <= 50 then
            local extra = ""
            local okT, t = pcall(function() return d.Text end)
            if okT and t and tostring(t) ~= "" then extra = "  Text=\"" .. strip(t) .. "\"" end
            add(("  <%s> %s%s"):format(d.ClassName, d:GetFullName(), extra))
        end
    end
end
add("  (เจอ " .. n2 .. ")")

-- 3) การ์ดด่าน: หา label ที่ตรงชื่อด่าน แล้วเดินขึ้น 3 ชั้น ดัมพ์ลูกทั้งหมด (หา badge)
add(""); add("── โครงการ์ดด่าน (ไต่จาก label ชื่อด่าน ขึ้น 3 ชั้น) ──")
local STAGE_NAMES = { "school grounds", "flower forest", "rose kingdom", "east town", "crimson shore", "fairy king forest" }
local doneCards = {}
for _, d in ipairs(PG:GetDescendants()) do
    if d:IsA("TextLabel") then
        local low = string.lower(strip(d.Text))
        for _, sn in ipairs(STAGE_NAMES) do
            if low == sn and not doneCards[sn] then
                doneCards[sn] = true
                local card = d
                for _ = 1, 3 do if card.Parent and card.Parent ~= PG then card = card.Parent end end
                add(("  ● การ์ด '%s' = %s"):format(d.Text, card:GetFullName()))
                for _, c in ipairs(card:GetDescendants()) do
                    local ct = ""
                    local okT, t = pcall(function() return c.Text end)
                    if okT and t and tostring(t) ~= "" then ct = " \"" .. strip(t) .. "\"" end
                    add(("      · [%s] %s%s"):format(c.ClassName, c.Name, ct))
                end
                break
            end
        end
    end
end

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
