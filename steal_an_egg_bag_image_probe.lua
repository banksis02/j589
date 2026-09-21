-- ============================================================================
-- Steal An Egg — PROBE: ดูว่าไข่ใน "กระเป๋า/inventory" จริง render ด้วยรูปอะไร
-- (เผื่อ id ที่ inventory ใช้ต่างจาก egg.Icon และเป็น public/rbxthumb ดึงได้)
-- อ่านอย่างเดียว — auto-copy clipboard
-- วิธีใช้: เปิดกระเป๋า/inventory ที่เห็นไข่ค้างไว้ แล้วรัน
-- ============================================================================
local Players=game:GetService("Players")
local plr=Players.LocalPlayer
local out={}
local function w(...) local t={} for _,v in ipairs({...}) do t[#t+1]=tostring(v) end out[#out+1]=table.concat(t," ") end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
    if type(writefile)=="function" then pcall(writefile,"probe_bag_images.txt",text) end
end
local function fn(o) local ok,n=pcall(function() return o:GetFullName() end); return ok and n or "?" end

local pg=plr:FindFirstChild("PlayerGui")
w("=== BAG IMAGE PROBE ===")
if not pg then w("no PlayerGui"); save(table.concat(out,"\n")); print(out[#out]); return end

-- 1) ทุก ImageLabel/ImageButton ที่ Image มีคำว่า egg หรืออยู่ใน GUI ชื่อเกี่ยวกับ inventory/egg
w("--- ImageLabel/Button ใน GUI inventory/egg/backpack (Image ที่ใช้จริง) ---")
local KW_GUI={"inventory","backpack","egg","bag","hatch","growing","pet","item"}
local seen=0
for _,g in ipairs(pg:GetChildren()) do
    local gn=g.Name:lower()
    local matchGui=false
    for _,k in ipairs(KW_GUI) do if gn:find(k) then matchGui=true break end end
    if matchGui then
        w(">> ScreenGui:", g.Name, "(Enabled="..tostring(g.Enabled)..")")
        local imgs=0
        for _,d in ipairs(g:GetDescendants()) do
            if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image and d.Image~="" then
                imgs=imgs+1
                if imgs<=12 then
                    w("   ["..d.Name.."] Image = "..d.Image)
                end
            end
            if d:IsA("ViewportFrame") then
                w("   ⚑ ViewportFrame (3D render):", fn(d))
            end
        end
        w("   (รวม "..imgs.." ImageLabel มีรูป)")
        seen=seen+imgs
    end
end
if seen==0 then w("   (ไม่เจอ — ลองเปิดกระเป๋าค้างไว้แล้วรันใหม่ หรือดู [2])") end
w("")

-- 2) รูปแบบ Image ที่เจอทั้งหมด (สรุปว่าเกมใช้ rbxassetid / rbxthumb / http)
w("--- [2] สรุปรูปแบบ Image ที่เกมใช้ (ทั้ง PlayerGui) ---")
local kinds={}
for _,d in ipairs(pg:GetDescendants()) do
    if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image and d.Image~="" then
        local img=d.Image
        local kind = img:match("^(%a+)://") or (img:match("^%d+$") and "bare-number") or "other"
        kinds[kind]=(kinds[kind] or 0)+1
    end
end
for k,v in pairs(kinds) do w("   "..k..": "..v) end
w("")

-- 3) ตัวอย่าง rbxthumb (ถ้าเกมใช้) — แสดง id ข้างใน
w("--- [3] ตัวอย่าง Image ที่เป็น rbxthumb/rbxassetid (5 อัน) ---")
local shown=0
for _,d in ipairs(pg:GetDescendants()) do
    if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image and (d.Image:find("rbxthumb")or d.Image:find("rbxassetid")) then
        w("   "..fn(d).."  =  "..d.Image)
        shown=shown+1; if shown>=5 then break end
    end
end
w("")
w("=== END (ก๊อป / ไฟล์ probe_bag_images.txt) ===")
local text=table.concat(out,"\n")
save(text); print(text)
