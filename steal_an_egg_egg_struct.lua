-- ============================================================
-- STEAL AN EGG — EGG STRUCT PROBE (อ่านล้วน) หาชื่อไข่ใน GrowingEggs
--   ดัมพ์โครงสร้างเต็มของ GrowingEggs + AssetEggData
--   (ClassName / Name / Text / Image / Attributes) เพื่อ map timer → ชื่อไข่
-- ============================================================

local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local PG      = player:WaitForChild("PlayerGui")

local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[EGG] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "egg_struct.txt", text) end
end
local function attrStr(inst)
    local ok, a = pcall(function() return inst:GetAttributes() end)
    if not ok or type(a) ~= "table" then return "" end
    local p = {}
    for k, v in pairs(a) do p[#p+1] = tostring(k) .. "=" .. tostring(v) end
    if #p == 0 then return "" end
    return "  attrs{" .. table.concat(p, ", ") .. "}"
end
-- ดัมพ์ tree แบบ indent พร้อม Text / Image / attrs
local function dump(inst, depth, maxdepth)
    depth = depth or 0
    if depth > (maxdepth or 6) then return end
    local pad = string.rep("  ", depth)
    local extra = ""
    local okT, txt = pcall(function() return inst.Text end)
    if okT and txt ~= nil and tostring(txt) ~= "" then extra = extra .. ("  Text=%q"):format(tostring(txt)) end
    local okI, img = pcall(function() return inst.Image end)
    if okI and img ~= nil and tostring(img) ~= "" then extra = extra .. "  Image=" .. tostring(img) end
    add(("%s<%s> %s%s%s"):format(pad, inst.ClassName, inst.Name, extra, attrStr(inst)))
    for _, c in ipairs(inst:GetChildren()) do
        dump(c, depth + 1, maxdepth)
    end
end

add("════════ EGG STRUCT ════════")

local ge = PG:FindFirstChild("GrowingEggs")
add(""); add("=== GrowingEggs (full tree) ===")
if ge then dump(ge, 0, 7) else add("  (ไม่เจอ GrowingEggs)") end

local aed = PG:FindFirstChild("AssetEggData")
add(""); add("=== AssetEggData (full tree) ===")
if aed then dump(aed, 0, 7) else add("  (ไม่เจอ AssetEggData)") end

-- ล่า "เงินรวม" ($2.5T) — label ที่มี $ แต่ไม่อยู่ใต้ SurfaceGui (ป้ายคนอื่น) --
add(""); add("=== หา label เงินรวม (มี $ / ไม่นับ SurfaceGui) ===")
local n = 0
for _, d in ipairs(PG:GetDescendants()) do
    if (d:IsA("TextLabel") or d:IsA("TextButton")) then
        local full = d:GetFullName()
        if not string.find(full, "SurfaceGui", 1, true) then
            local txt = tostring(d.Text)
            if string.find(txt, "$") or string.match(txt, "^%d[%d,%.]*[KMBTQ]") then
                n = n + 1
                if n <= 40 then add(("  %q  <- %s"):format(txt, full)) end
            end
        end
    end
end
add("  (เจอ " .. n .. ")")

-- หาค่าเงินรวมแบบ "ตัวเลขดิบ" — NumberValue/IntValue ก้อนใหญ่ + attributes --
add(""); add("=== ค่าดิบก้อนใหญ่ (NumberValue/IntValue > 1e6) ทั้ง player + character ===")
local roots = { player }
if player.Character then roots[#roots+1] = player.Character end
for _, root in ipairs(roots) do
    for _, d in ipairs(root:GetDescendants()) do
        if (d:IsA("NumberValue") or d:IsA("IntValue")) and d.Value and d.Value > 1e6 then
            add(("  %s = %s"):format(d:GetFullName(), tostring(d.Value)))
        end
    end
end
-- attribute ก้อนใหญ่บน player / character
local function bigAttrs(inst, tag)
    local ok, a = pcall(function() return inst:GetAttributes() end)
    if not ok then return end
    for k, v in pairs(a) do
        if type(v) == "number" and v > 1e6 then add(("  [%s attr] %s = %s"):format(tag, k, tostring(v))) end
    end
end
bigAttrs(player, "player")
if player.Character then bigAttrs(player.Character, "char") end

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
