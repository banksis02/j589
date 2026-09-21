-- ============================================================================
-- Steal An Egg — dump โครงสร้าง entry ไข่เต็ม หา field รูปที่ public
-- (egg.Icon เป็น private; หา field อื่นเช่น Image/Thumbnail/Model ที่ public)
-- อ่านอย่างเดียว — clipboard
-- ============================================================================
local RS=game:GetService("ReplicatedStorage")
local out={}
local function w(...) local t={} for _,v in ipairs({...}) do t[#t+1]=tostring(v) end out[#out+1]=table.concat(t," ") end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
end

local function findAssets()
    local d=RS:FindFirstChild("Data"); local m=d and d:FindFirstChild("Assets")
    if m then local ok,v=pcall(require,m); if ok and v and v.Directory then return v end end
    for _,x in ipairs(RS:GetDescendants()) do
        if x:IsA("ModuleScript") and x.Name=="Assets" then local ok,v=pcall(require,x); if ok and v and v.Directory then return v end end
    end
end
local A=findAssets()
if not A then w("no Assets"); save(table.concat(out,"\n")); print(out[1]); return end

-- dump ทุก field ที่เป็น string/number ที่ "อาจเป็น asset id" ในทั้ง entry (recursive ตื้นๆ)
local function assetIds(tbl, prefix, acc, depth)
    if depth>4 or type(tbl)~="table" then return end
    for k,v in pairs(tbl) do
        local path=prefix.."."..tostring(k)
        if type(v)=="string" then
            local id=v:match("rbxassetid://(%d+)") or v:match("^(%d%d%d%d%d%d%d+)$")
            if id then acc[#acc+1]={path=path, id=id, raw=v} end
        elseif type(v)=="table" then
            assetIds(v, path, acc, depth+1)
        end
    end
end

-- เลือก 3 ไข่มา dump เต็ม
local pick={}
for cat,entry in pairs(A.Directory) do
    if type(entry)=="table" and type(entry.Egg)=="table" then
        pick[#pick+1]=cat
        if #pick>=3 then break end
    end
end

for _,cat in ipairs(pick) do
    local entry=A.Directory[cat]
    w("========== EGG: "..cat.." ==========")
    -- keys ใน entry.Egg
    w("entry.Egg keys:")
    for k,v in pairs(entry.Egg) do w("   ."..tostring(k).." = ("..type(v)..") "..(type(v)~="table" and tostring(v) or "{table}")) end
    -- keys ใน entry (top)
    w("entry keys:")
    for k,v in pairs(entry) do w("   ."..tostring(k).." = ("..type(v)..") "..(type(v)~="table" and tostring(v) or "{table}")) end
    -- asset id ทั้งหมดใน entry
    local acc={}
    assetIds(entry, "entry", acc, 1)
    w("asset-id fields ทั้งหมด:")
    for _,a in ipairs(acc) do w("   "..a.path.." = "..a.id) end
    w("")
end
w("=== END — ส่ง output นี้มา (จะเทสว่า field ไหน public) ===")
local text=table.concat(out,"\n")
save(text); print(text)
