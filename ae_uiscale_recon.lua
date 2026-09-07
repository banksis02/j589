-- ============================================================
-- AE — RECON ช่อง "UI Scale" ในหน้า Settings (อ่านล้วน)
--   *** เปิดหน้า Settings → แท็บ Miscellaneous (เห็น UI Scale) ก่อนรัน ***
--   ดัมพ์: label "UI Scale" + แถวเดียวกัน (TextBox/slider/ค่า) เพื่อรู้ว่าตั้ง=1 ยังไง
-- ============================================================
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local out = {}
local function add(t) t=tostring(t); out[#out+1]=t; print("[UISC] "..t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn)=="function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile)=="function" then pcall(writefile, "ae_uiscale.txt", text) end
end
local function short(inst) return (inst:GetFullName():gsub("^Players%.[^.]+%.PlayerGui%.","")) end
local function props(c)
    local s = ""
    local okT,t = pcall(function() return c.Text end); if okT and t~=nil and tostring(t)~="" then s=s.." Text="..string.format("%q",tostring(t)) end
    local okV,v = pcall(function() return c.Value end); if okV and v~=nil then s=s.." Value="..tostring(v) end
    if c:IsA("Frame") or c:IsA("ImageLabel") or c:IsA("ImageButton") then
        s=s..(" pos=(%d,%d) size=(%d,%d)"):format(c.AbsolutePosition.X,c.AbsolutePosition.Y,c.AbsoluteSize.X,c.AbsoluteSize.Y)
    end
    return s
end

local s = player.PlayerGui:FindFirstChild("Settings")
add("════════ UI SCALE RECON ════════")
add("Settings เปิดอยู่ = "..tostring(s ~= nil))
if not s then add("❌ เปิดหน้า Settings ก่อน (แท็บ Miscellaneous)"); save(); return end

-- หา label "UI Scale"
local lbl
for _, l in ipairs(s:GetDescendants()) do
    if l:IsA("TextLabel") and l.Visible and l.Text:lower():gsub("%s","") == "uiscale" then lbl = l; break end
end
if not lbl then
    add("⚠️ ไม่เจอ label 'UI Scale' — dump ทุก label ที่เห็น:")
    for _, l in ipairs(s:GetDescendants()) do
        if l:IsA("TextLabel") and l.Visible and l.Text ~= "" then add("  \""..l.Text.."\"  <- "..short(l)) end
    end
    save(); return
end
add("✅ เจอ UI Scale label: "..short(lbl))
add(("   pos=(%d,%d) size=(%d,%d)"):format(lbl.AbsolutePosition.X,lbl.AbsolutePosition.Y,lbl.AbsoluteSize.X,lbl.AbsoluteSize.Y))

-- ไต่ขึ้นหา "แถว/การ์ด" ของ UI Scale (parent ที่กว้างพอ) แล้วดัมพ์ทั้งแถว
local row = lbl
for _=1,5 do if row.Parent and row.Parent~=s and row.Parent.AbsoluteSize.X < s.AbsoluteSize.X*0.6 then row=row.Parent else break end end
add(""); add("── การ์ด/แถว UI Scale = "..short(row).." ──")
for _, c in ipairs(row:GetDescendants()) do
    add(("  [%s] %s%s"):format(c.ClassName, c.Name, props(c)))
end

-- element อื่นในหน้า Settings ที่อยู่ "แถวเดียวกัน" (y ใกล้ label) — เผื่อ slider/box อยู่นอก row
add(""); add("── element แถวเดียวกัน (y ใกล้ UI Scale ±"..math.floor(lbl.AbsoluteSize.Y*2)..") ──")
local ly = lbl.AbsolutePosition.Y
for _, c in ipairs(s:GetDescendants()) do
    if (c:IsA("TextBox") or c:IsA("Frame") or c:IsA("ImageButton") or c:IsA("GuiButton")) and c.Visible
       and math.abs(c.AbsolutePosition.Y - ly) < lbl.AbsoluteSize.Y*2 and c.AbsolutePosition.X > lbl.AbsolutePosition.X then
        add(("  [%s] %s%s"):format(c.ClassName, c.Name, props(c)))
    end
end

-- หา TextBox ทั้งหน้า Settings (ช่องพิมพ์เลข)
add(""); add("── TextBox ทั้งหมดในหน้า Settings ──")
for _, c in ipairs(s:GetDescendants()) do
    if c:IsA("TextBox") then add(("  [TextBox] %s Text=%q  <- %s"):format(c.Name, tostring(c.Text), short(c))) end
end

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
