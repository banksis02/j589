-- ============================================================
-- AE — END SCREEN RECON (Victory/Defeat) — อ่านล้วน ไม่ hook
--   รันตอน "อยู่หน้าจบด่าน (มีปุ่ม Repeat Stage / View Party)"
--   จุดประสงค์: ดูว่าทำไมคลิก Repeat Stage ไม่ตรง (ไปโดน View Party)
--   ดัมพ์: ScreenGui จบเกม + ปุ่มที่มองเห็น + path/pos/size/Active
--          + สำหรับ label "Repeat Stage"/"View Party": ปุ่มแม่ตัวในสุด (innermost) + ปุ่มที่ "ครอบ" ทั้งคู่
-- ============================================================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[END] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "ae_endscreen_recon.txt", text) end
end
local function pathOf(o)
    local parts, cur, n = {}, o, 0
    while cur and cur ~= game and n < 14 do parts[#parts+1] = cur.Name .. "<" .. cur.ClassName .. ">"; cur = cur.Parent; n = n + 1 end
    local r = {}; for i = #parts, 1, -1 do r[#r+1] = parts[i] end
    return table.concat(r, ".")
end
local function cleanText(o)
    if o:IsA("TextLabel") or o:IsA("TextButton") then return (tostring(o.Text):gsub("<[^>]->", ""):gsub("^%s+",""):gsub("%s+$","")) end
    return ""
end
local function isVisible(o)
    local ok, res = pcall(function()
        if not o.Visible then return false end
        local p = o.Parent
        while p and p:IsA("GuiObject") do if not p.Visible then return false end; p = p.Parent end
        return o.AbsoluteSize.X > 2 and o.AbsoluteSize.Y > 2
    end)
    return ok and res
end
-- ปุ่มแม่ตัวในสุด (innermost GuiButton) ที่ครอบ label
local function innermostBtn(lbl)
    local p = lbl
    while p do
        if p:IsA("GuiButton") then return p end
        p = p.Parent
    end
    return nil
end
-- ปุ่มนี้ครอบ label ข้อความ needle ไหม
local function btnContains(btn, needle)
    for _, l in ipairs(btn:GetDescendants()) do
        if (l:IsA("TextLabel") or l:IsA("TextButton")) and cleanText(l) == needle then return true end
    end
    return false
end

-- หา ScreenGui จบเกม (Victory/Defeat + Repeat Stage)
local endGui, result
for _, g in ipairs(player.PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Enabled then
        local res, hasRepeat
        for _, l in ipairs(g:GetDescendants()) do
            if (l:IsA("TextLabel") or l:IsA("TextButton")) and l.Visible then
                local t = cleanText(l)
                if t == "Victory" or t == "Defeat" then res = t end
                if t == "Repeat Stage" then hasRepeat = true end
            end
        end
        if res and hasRepeat then endGui, result = g, res; break end
    end
end

add("════ END SCREEN RECON ════")
if not endGui then
    add("❌ ไม่เจอ ScreenGui จบเกม (ต้องรันตอนอยู่หน้า Victory/Defeat ที่มีปุ่ม Repeat Stage)")
    -- fallback: list ทุก ScreenGui ที่มี Repeat/View Party
    for _, g in ipairs(player.PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            for _, l in ipairs(g:GetDescendants()) do
                if (l:IsA("TextLabel") or l:IsA("TextButton")) and l.Visible then
                    local t = cleanText(l)
                    if t == "Repeat Stage" or t == "View Party" or t == "Victory" or t == "Defeat" then
                        add(("  พบ '%s' ใน ScreenGui '%s'  path: %s"):format(t, g.Name, pathOf(l)))
                    end
                end
            end
        end
    end
    save(); return
end
add(("พบหน้าจบเกม: %s  (ScreenGui '%s')"):format(tostring(result), endGui.Name))

-- ปุ่มทั้งหมดที่มองเห็นในหน้าจบเกม
add("")
add("════ ปุ่ม (GuiButton) ที่มองเห็นในหน้าจบเกม ════")
local nb = 0
for _, b in ipairs(endGui:GetDescendants()) do
    if b:IsA("GuiButton") and isVisible(b) then
        nb = nb + 1
        local own = cleanText(b)
        local kids = {}
        for _, l in ipairs(b:GetDescendants()) do
            if l:IsA("TextLabel") and l.Visible then local t = cleanText(l); if t ~= "" then kids[#kids+1] = t end end
        end
        local pos, sz = b.AbsolutePosition, b.AbsoluteSize
        add(("#%d text='%s' child=[%s]  <%s> pos(%d,%d) size(%d,%d) Active=%s")
            :format(nb, own, table.concat(kids, " / "), b.ClassName, pos.X, pos.Y, sz.X, sz.Y, tostring(b.Active)))
        add("     path: " .. pathOf(b))
    end
end
add("รวมปุ่ม = " .. nb)

-- วิเคราะห์ Repeat Stage / View Party — ปุ่มแม่ innermost + ปุ่มที่ครอบทั้งคู่
for _, needle in ipairs({ "Repeat Stage", "View Party" }) do
    add("")
    add("════ วิเคราะห์ '" .. needle .. "' ════")
    for _, l in ipairs(endGui:GetDescendants()) do
        if (l:IsA("TextLabel") or l:IsA("TextButton")) and isVisible(l) and cleanText(l) == needle then
            add(("• label path: %s"):format(pathOf(l)))
            local ib = innermostBtn(l)
            if ib then
                local pos, sz = ib.AbsolutePosition, ib.AbsoluteSize
                local alsoView = btnContains(ib, "View Party") and btnContains(ib, "Repeat Stage")
                add(("   → ปุ่มแม่ innermost: <%s> pos(%d,%d) size(%d,%d) center=(%d,%d) ครอบทั้งคู่=%s")
                    :format(ib.ClassName, pos.X, pos.Y, sz.X, sz.Y, pos.X+sz.X/2, pos.Y+sz.Y/2, tostring(alsoView)))
                add(("     path: %s"):format(pathOf(ib)))
            else
                add("   → ไม่มีปุ่มแม่ (GuiButton) เลย")
            end
            break
        end
    end
end

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ (รันตอนอยู่หน้าจบด่าน)")
