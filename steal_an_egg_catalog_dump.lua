-- ============================================================================
-- Steal An Egg — ดึงแคตตาล็อกรูปไข่+สัตว์ทั้งหมด จาก ReplicatedStorage.Data.Assets.Directory
-- อ่านอย่างเดียว (require module) — ปลอดภัย AC
-- ออกเป็น JSON → clipboard + asset_catalog.json  (ส่งไฟล์/วางกลับมาให้ผม)
-- ============================================================================
local RS=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")

local function findAssets()
    -- ปกติ RS.Data.Assets; เผื่อ path ต่าง สแกน ModuleScript ชื่อ Assets ที่มี .Directory
    local d=RS:FindFirstChild("Data")
    local m=d and d:FindFirstChild("Assets")
    if m and m:IsA("ModuleScript") then local ok,v=pcall(require,m); if ok and type(v)=="table" and v.Directory then return v end end
    for _,x in ipairs(RS:GetDescendants()) do
        if x:IsA("ModuleScript") and x.Name=="Assets" then
            local ok,v=pcall(require,x); if ok and type(v)=="table" and v.Directory then return v end
        end
    end
end

local Assets=findAssets()
if not Assets then warn("[CATALOG] ไม่พบ Data.Assets.Directory"); return end
local Dir=Assets.Directory

local function iconId(raw)
    return tostring(raw or ""):match("(%d+)")   -- ดึงเลข asset id ออกจาก rbxassetid://xxxx
end
local function rarityName(entry)
    local r=entry and entry.Rarity
    return (type(r)=="table" and r.DisplayName) or ""
end

local eggs,pets={},{}
local nEgg,nPet=0,0
for category,entry in pairs(Dir) do
    if type(entry)=="table" then
        -- สัตว์/asset: entry.DisplayName + entry.Icon
        local pIcon=iconId(entry.Icon)
        if pIcon then
            pets[category]={name=entry.DisplayName or category, icon=pIcon, rarity=rarityName(entry)}
            nPet=nPet+1
        end
        -- ไข่: entry.Egg.DisplayName + entry.Egg.Icon
        local egg=entry.Egg
        if type(egg)=="table" then
            local eIcon=iconId(egg.Icon)
            if eIcon then
                eggs[category]={name=egg.DisplayName or (category.." Egg"), icon=eIcon, rarity=rarityName(entry)}
                nEgg=nEgg+1
            end
        end
    end
end

local payload={eggs=eggs, pets=pets, counts={eggs=nEgg, pets=nPet}}
local json
local ok,err=pcall(function() json=HttpService:JSONEncode(payload) end)
if not ok then warn("[CATALOG] JSON encode error: "..tostring(err)); return end

for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
    if type(fn)=="function" and pcall(fn,json) then break end
end
if type(writefile)=="function" then pcall(writefile,"asset_catalog.json",json) end

print(("[CATALOG] ไข่ %d ชนิด | สัตว์ %d ชนิด | JSON %d bytes → clipboard + asset_catalog.json"):format(nEgg,nPet,#json))
-- โชว์ตัวอย่าง 3 อัน
local shown=0
for cat,e in pairs(eggs) do print(("  ไข่: %s = %s (icon %s)"):format(cat,e.name,e.icon)); shown=shown+1; if shown>=3 then break end end
shown=0
for cat,e in pairs(pets) do print(("  สัตว์: %s = %s (icon %s)"):format(cat,e.name,e.icon)); shown=shown+1; if shown>=3 then break end end
