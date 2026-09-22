-- ============================================================================
-- Steal An Egg — PROBE: ทดสอบดึง pixel รูปไข่ private ด้วย EditableImage
-- AssetService:CreateEditableImageAsync + ReadPixels (client มีสิทธิ์ในเกม)
-- ถ้าได้ = เอา pixel ส่ง backend encode PNG เก็บเอง (host เองเหมือนเจ้าอื่น)
-- ============================================================================
local AssetService=game:GetService("AssetService")
local out={}
local function w(...) local t={} for _,v in ipairs({...}) do t[#t+1]=tostring(v) end out[#out+1]=table.concat(t," ") end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
end

local EGG_ID="140733363307193"   -- Gorilla King Egg (private)
w("=== EDITABLE IMAGE PROBE ===")
w("CreateEditableImageAsync:", type(AssetService.CreateEditableImageAsync))

-- ลองหลาย signature
local img, usedWay
local attempts={
    {"assetId string", function() return AssetService:CreateEditableImageAsync("rbxassetid://"..EGG_ID) end},
    {"Content.fromUri", function() return AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://"..EGG_ID)) end},
    {"Content.fromAssetId", function() return AssetService:CreateEditableImageAsync(Content.fromAssetId(tonumber(EGG_ID))) end},
    {"rbxthumb", function() return AssetService:CreateEditableImageAsync("rbxthumb://type=Asset&id="..EGG_ID.."&w=150&h=150") end},
}
for _,a in ipairs(attempts) do
    local ok,res=pcall(a[2])
    w("  ["..a[1].."]:", ok and (typeof(res)) or ("ERR: "..tostring(res)))
    if ok and res then img=res; usedWay=a[1]; break end
end

if not img then
    w("❌ CreateEditableImageAsync ไม่สำเร็จทุก signature")
else
    w("✅ ได้ EditableImage ด้วย:", usedWay)
    local sz=img.Size
    w("  Size:", tostring(sz))
    -- ReadPixels
    local okR,px=pcall(function() return img:ReadPixels(Vector2.new(0,0), sz) end)
    if not okR then
        -- ลอง ReadPixelsBuffer (API ใหม่)
        local okB,buf=pcall(function() return img:ReadPixelsBuffer(Vector2.new(0,0), sz) end)
        w("  ReadPixels:", "ERR "..tostring(px), "| ReadPixelsBuffer:", okB and ("buffer len="..(buffer and buffer.len(buf) or "?")) or ("ERR "..tostring(buf)))
    else
        w("  ✅ ReadPixels ok — จำนวนค่า:", #px, "(ควร = w*h*4)")
        w("  ตัวอย่าง 8 ค่าแรก (RGBA):")
        local s={}
        for i=1,math.min(8,#px) do s[i]=tostring(px[i]) end
        w("   ", table.concat(s,", "))
    end
end
w("")
w("=== ถ้าขึ้น 'ReadPixels ok' = ดึงรูปไข่มา host เองได้! ===")
local text=table.concat(out,"\n")
save(text); print(text)
