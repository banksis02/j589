-- ============================================================
-- AE — PARTY SCREEN RECON (อ่านล้วน ไม่ hook ไม่ยิง remote)
--   รันตอน "ค้างอยู่หน้าปาร์ตี้ (Start/Change Map/Change Gamemode)"
--   ดัมพ์: ScreenGui ที่เปิด + ปุ่ม/ข้อความที่มองเห็นทั้งหมด + path + ตำแหน่ง/ขนาด + Active/AutoButtonColor
--   → รู้ path/ชื่อจริงของ Change Map / Change Gamemode / Start / Difficulty / การ์ดด่าน
-- ============================================================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[PARTY] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "ae_party_recon.txt", text) end
end
local function path(o)
    local parts, cur, n = {}, o, 0
    while cur and cur ~= game and n < 12 do parts[#parts+1] = cur.Name; cur = cur.Parent; n = n + 1 end
    local r = {}
    for i = #parts, 1, -1 do r[#r+1] = parts[i] end
    return table.concat(r, ".")
end
local function cleanText(o)
    if o:IsA("TextLabel") or o:IsA("TextButton") then return (tostring(o.Text):gsub("<[^>]->", "")) end
    return ""
end
local function visible(o)
    local ok, res = pcall(function()
        if not o.Visible then return false end
        local p = o.Parent
        while p and p:IsA("GuiObject") do if not p.Visible then return false end; p = p.Parent end
        return o.AbsoluteSize.X > 2 and o.AbsoluteSize.Y > 2
    end)
    return ok and res
end

add("════ PARTY SCREEN RECON ════")
local guis = {}
for _, g in ipairs(player.PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Enabled then guis[#guis+1] = g end
end
add("ScreenGui ที่เปิด (" .. #guis .. "): ")
for _, g in ipairs(guis) do add("  • " .. g.Name) end

-- ปุ่มทั้งหมดที่มองเห็น
add("")
add("════ ปุ่ม (GuiButton) ที่มองเห็น ════")
local nBtn = 0
for _, g in ipairs(guis) do
    for _, b in ipairs(g:GetDescendants()) do
        if (b:IsA("TextButton") or b:IsA("ImageButton")) and visible(b) then
            local ownText = cleanText(b)
            local childText = {}
            for _, l in ipairs(b:GetDescendants()) do
                if l:IsA("TextLabel") and l.Visible then
                    local t = cleanText(l); if t ~= "" then childText[#childText+1] = t end
                end
            end
            local label = ownText
            if #childText > 0 then label = label .. (ownText ~= "" and " | " or "") .. "[" .. table.concat(childText, " / ") .. "]" end
            if label ~= "" then
                nBtn = nBtn + 1
                local pos, sz = b.AbsolutePosition, b.AbsoluteSize
                local act = pcall(function() return b.Active end) and tostring(b.Active) or "?"
                add(("#%d %s  <%s>  pos(%d,%d) size(%d,%d) Active=%s")
                    :format(nBtn, label, b.ClassName, pos.X, pos.Y, sz.X, sz.Y, act))
                add("     path: " .. path(b))
            end
        end
    end
end
add("รวมปุ่ม = " .. nBtn)

-- ข้อความสำคัญ (Change Map/Gamemode/Start/Difficulty/ชื่อด่าน) — โชว์ path ของ label ด้วย
add("")
add("════ ข้อความสำคัญ (label) + path ════")
local keywords = { "Change Map", "Change Gamemode", "Start", "Select Stage", "Difficulty", "Back", "Disband",
    "School Grounds", "Flower Forest", "Rose Kingdom", "East Town", "Expedition" }
for _, g in ipairs(guis) do
    for _, l in ipairs(g:GetDescendants()) do
        if (l:IsA("TextLabel") or l:IsA("TextButton")) and visible(l) then
            local t = cleanText(l)
            for _, kw in ipairs(keywords) do
                if t:find(kw, 1, true) then
                    add(("• '%s'  <%s>  path: %s"):format(t, l.ClassName, path(l)))
                    break
                end
            end
        end
    end
end

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ (รันตอนอยู่หน้าปาร์ตี้)")
