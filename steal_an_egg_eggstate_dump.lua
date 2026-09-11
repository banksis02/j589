-- ============================================================
-- STEAL AN EGG — EGGSTATE FULL DUMP (decompile โค้ดเต็ม ใส่คลิปบอร์ดเลย)
-- อ่าน/decompile อย่างเดียว ไม่ hook ไม่ยิง remote = ปลอดภัย
-- รัน → ก๊อปได้เลย (วางกลับมาให้ผม) — เพื่อดูว่า "redeem/ฝากไข่" trigger เขตไหน/เงื่อนไขอะไร
-- ============================================================

local RS = game:GetService("ReplicatedStorage")

-- โมดูลที่เกี่ยวกับ carry/redeem (ตัวหลัก = EggState)
local TARGETS = {
    RS:FindFirstChild("Client") and RS.Client:FindFirstChild("EggState"),
}
-- เผื่อมีโมดูลฝากแยก — หา descendant ชื่อเกี่ยว redeem/deposit/safezone
pcall(function()
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local n = d.Name:lower()
            if n:find("redeem") or n:find("deposit") or n:find("safezone") or n:find("fieldegg") then
                TARGETS[#TARGETS+1] = d
            end
        end
    end
end)

-- decompiler (ลองหลายชื่อ)
local DEC
for _, nm in ipairs({"decompile"}) do
    if type(getgenv()[nm])=="function" then DEC=getgenv()[nm]; break end
    if type(_G[nm])=="function" then DEC=_G[nm]; break end
end
if not DEC and type(decompile)=="function" then DEC=decompile end

local function getSrc(inst)
    local ok,s = pcall(function() return inst.Source end)
    if ok and type(s)=="string" and #s>0 then return s,".Source" end
    if DEC then local ok2,s2=pcall(DEC,inst); if ok2 and type(s2)=="string" and #s2>0 then return s2,"decompile" end end
    return nil,"อ่านไม่ได้"
end

local seen, parts = {}, {}
for _, inst in ipairs(TARGETS) do
    if inst and not seen[inst] then
        seen[inst]=true
        parts[#parts+1] = "\n\n===================================================================\n-- "..inst:GetFullName().."\n===================================================================\n"
        local src,how = getSrc(inst)
        parts[#parts+1] = src and ("-- ["..how.."]\n"..src) or ("["..how.."]")
    end
end

local out = "EGGSTATE FULL DUMP  (decompiler="..(DEC and "มี" or "ไม่มี")..")"..table.concat(parts)

-- ใส่คลิปบอร์ด + เซฟไฟล์
local copied=false
for _, fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
    if type(fn)=="function" and pcall(fn,out) then copied=true; break end
end
if type(writefile)=="function" then pcall(writefile,"eggstate_full.txt",out) end

print("════════ EGGSTATE FULL DUMP ════════")
print("decompiler = "..(DEC and "✅ มี" or "❌ ไม่มี"))
print("ก๊อปใส่คลิปบอร์ด = "..(copied and "✅ แล้ว (Ctrl+V วางมาได้เลย)" or "❌ ไม่ได้ — เปิดไฟล์ eggstate_full.txt"))
print("ยาว "..#out.." ตัวอักษร | โมดูลที่ดึง: "..#TARGETS)
print("═══════════════════════════════════")
