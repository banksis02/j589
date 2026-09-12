-- ============================================================
-- STEAL AN EGG — ObbyAntiTP SOURCE DUMP (decompile ตัวกัน teleport)
-- อ่าน/decompile อย่างเดียว ไม่ hook = ปลอดภัย
-- เพื่อรู้ว่ามันเช็ค teleport ยังไง → ทำ humanoid-swap วาปทันทีไม่โดนดึงได้ถูกจุด
-- รัน → ก๊อป output วางมา (auto setclipboard)
-- ============================================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer

local DEC = (type(decompile)=="function" and decompile) or (type(getgenv().decompile)=="function" and getgenv().decompile)
local out = {}
local function add(s) out[#out+1]=s end

-- หา ObbyAntiTP scripts/modules ทุกที่
local roots = { player:FindFirstChild("PlayerScripts"), player:FindFirstChild("PlayerGui"),
                game:GetService("StarterPlayer"), RS, game:GetService("Workspace") }
local found = {}
for _,root in ipairs(roots) do
    if root then
        pcall(function()
            for _,d in ipairs(root:GetDescendants()) do
                if (d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Script")) and d.Name:lower():find("obby") and d.Name:lower():find("anti") then
                    found[#found+1]=d
                end
            end
        end)
    end
end
-- เผื่อชื่ออื่น: หา "AntiTP","AntiTeleport","Lagback"
for _,root in ipairs(roots) do
    if root then pcall(function()
        for _,d in ipairs(root:GetDescendants()) do
            if d:IsA("LuaSourceContainer") then local n=d.Name:lower()
                if (n:find("antitp") or n:find("antiteleport") or n:find("lagback")) then
                    local dup=false for _,x in ipairs(found) do if x==d then dup=true end end
                    if not dup then found[#found+1]=d end
                end
            end
        end
    end) end
end

add("════════ ObbyAntiTP SOURCE DUMP ════════")
add("decompiler="..(DEC and "✅" or "❌ ไม่มี"))
add("เจอสคริปต์กัน teleport "..#found.." ตัว:")
for _,d in ipairs(found) do add("  - "..d.ClassName.." "..d:GetFullName()) end

local function getSrc(inst)
    local ok,s=pcall(function() return inst.Source end); if ok and type(s)=="string" and #s>0 then return s,".Source" end
    if DEC then local ok2,s2=pcall(DEC,inst); if ok2 and type(s2)=="string" and #s2>0 then return s2,"decompile" end end
    return nil,"อ่านไม่ได้"
end
for _,d in ipairs(found) do
    add("\n===================================================================")
    add("-- "..d:GetFullName())
    add("===================================================================")
    local src,how=getSrc(d)
    add(src and ("-- ["..how.."]\n"..src) or ("["..how.."]"))
end

local txt=table.concat(out,"\n")
for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
if type(writefile)=="function" then pcall(writefile,"antitp_src.txt",txt) end
print(txt:sub(1,1500))
print("... (เต็มอยู่ในคลิปบอร์ด + antitp_src.txt — วางมาให้เลย)")
