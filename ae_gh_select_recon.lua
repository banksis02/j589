-- ============================================================
-- AE — RECON จอ Golden Hour STAGE-SELECT (อ่านล้วน)
--   *** เปิดจอเลือกด่าน Golden Hour ค้างไว้ก่อนรัน ***
--   (คลิกการ์ดด่านที่มี Golden Hour → จอโชว์ "Golden Hour · Act 5 Hard" + ปุ่ม Select Stage / Enter Matchmaking)
--   ดัมพ์: ปุ่มกดได้ทั้งหมด (text+path) + แท็บด้านซ้าย (GH/Act) + label สำคัญ
-- ============================================================
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local PG      = player:WaitForChild("PlayerGui")
local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[GH] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "ae_gh_select.txt", text) end
end
local function strip(s) return (tostring(s):gsub("<[^>]->", "")) end
local function shortPath(inst)
    -- path ย่อจาก Play ลงไป (กัน Frame.Frame ยาว)
    local full = inst:GetFullName()
    return (full:gsub("^Players%.[^.]+%.PlayerGui%.", ""))
end

local root = PG:FindFirstChild("Play") or PG
add("════════ GH STAGE-SELECT RECON  root=" .. root.Name .. " ════════")

-- 1) ปุ่มกดได้ทั้งหมดที่ visible (TextButton/ImageButton) + text ในตัว/ลูก
add(""); add("── ปุ่มกดได้ (visible) + ข้อความ ──")
local n = 0
for _, b in ipairs(root:GetDescendants()) do
    if (b:IsA("TextButton") or b:IsA("ImageButton")) then
        local vis = true
        local ok = pcall(function() vis = b.Visible end)
        if ok and vis then
            -- หา text: ตัวปุ่มเอง หรือ label ลูก
            local txt = ""
            if b:IsA("TextButton") and strip(b.Text) ~= "" then txt = strip(b.Text) end
            if txt == "" then
                for _, c in ipairs(b:GetDescendants()) do
                    if c:IsA("TextLabel") and strip(c.Text) ~= "" then txt = strip(c.Text); break end
                end
            end
            n = n + 1
            if n <= 70 then add(("  [%s] \"%s\"  <- %s"):format(b.ClassName, txt, shortPath(b))) end
        end
    end
end
add("  (ปุ่ม visible = " .. n .. ")")

-- 2) label สำคัญ (Golden/Act/Hard/Matchmaking/Select/Reward)
add(""); add("── labels สำคัญ ──")
local KW = { "golden", "act", "hard", "normal", "matchmak", "select stage", "reward", "hour", "stage" }
local n2 = 0
for _, d in ipairs(root:GetDescendants()) do
    if d:IsA("TextLabel") and d.Visible then
        local low = string.lower(strip(d.Text))
        if low ~= "" then
            for _, kw in ipairs(KW) do
                if string.find(low, kw, 1, true) then
                    n2 = n2 + 1
                    if n2 <= 50 then add(("  \"%s\"  <- %s"):format(strip(d.Text), shortPath(d))) end
                    break
                end
            end
        end
    end
end
add("  (เจอ " .. n2 .. ")")

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
