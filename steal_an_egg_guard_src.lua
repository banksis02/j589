-- ============================================================
-- STEAL AN EGG — GUARD SOURCE DUMP (อ่าน/decompile โมดูลยาม)
-- อ่านอย่างเดียว ไม่ hook ไม่ยิง remote = ปลอดภัย
-- เพื่อรู้ว่า "server ตัดสินการหนีพ้นยาม/แย่งไข่คืน" ด้วยเงื่อนไขอะไร
-- รัน → มันเซฟไฟล์ + ก๊อปให้ → ส่งไฟล์/วางมาให้เลย
-- ============================================================

local RS = game:GetService("ReplicatedStorage")

-- โมดูลยามที่สำคัญ (เรียงตามความสำคัญ)
local TARGETS = {
    "Shared.Modules.GuardAreas.GuardEscapeRequirement",     -- ★ เงื่อนไขหนีพ้น
    "Shared.Modules.GuardAreas.GuardEggRetrievalComponent", -- ★ ตัวแย่งไข่คืน (เฟล)
    "Shared.Modules.GuardAreas.GuardReturnHomeDistanceResolver",
    "Shared.Modules.GuardAreas.GuardEscapePrediction",
    "Shared.Modules.GuardAreas.GuardChasePolicy",
    "Shared.Modules.GuardAreas.GuardDistance",
    "Shared.Utils.GuardEscape",
    "Shared.Modules.GuardAreas.GuardComponent",
}

-- หา decompiler ที่ executor มี
local DEC = nil
for _, name in ipairs({"decompile","getscriptsource","getscriptclosure_decompile"}) do
    if type(getgenv()[name]) == "function" then DEC = getgenv()[name]; break end
    if type(_G[name]) == "function" then DEC = _G[name]; break end
end
if not DEC and type(decompile) == "function" then DEC = decompile end

local function resolve(path)
    local node = RS
    for seg in path:gmatch("[^%.]+") do
        node = node and node:FindFirstChild(seg)
    end
    return node
end

local function getSrc(inst)
    -- 1) .Source (บาง executor อ่านได้)
    local ok, s = pcall(function() return inst.Source end)
    if ok and type(s) == "string" and #s > 0 then return s, ".Source" end
    -- 2) decompile
    if DEC then
        local ok2, s2 = pcall(DEC, inst)
        if ok2 and type(s2) == "string" and #s2 > 0 then return s2, "decompile" end
    end
    return nil, "อ่านไม่ได้"
end

local parts = {}
for _, path in ipairs(TARGETS) do
    local inst = resolve(path)
    parts[#parts+1] = "\n\n=====================================================\n-- " .. path .. "\n=====================================================\n"
    if not inst then
        parts[#parts+1] = "[ไม่เจอ instance นี้]"
    else
        local src, how = getSrc(inst)
        if src then
            parts[#parts+1] = "-- [ที่มา: " .. how .. "]\n" .. src
        else
            parts[#parts+1] = "[" .. how .. " — executor นี้ decompile ไม่ได้]"
        end
    end
end

local out = "STEAL AN EGG — GUARD SOURCE\ndecompiler=" .. (DEC and "มี" or "ไม่มี") .. table.concat(parts)

-- เซฟไฟล์ทีละไฟล์ (เผื่อ clipboard ยาวเกิน) + รวม
if type(writefile) == "function" then
    pcall(function() writefile("guard_src_all.txt", out) end)
    for _, path in ipairs(TARGETS) do
        local inst = resolve(path)
        if inst then
            local src = getSrc(inst)
            if src then pcall(function() writefile("guard_src_" .. path:gsub("%.","_") .. ".txt", src) end) end
        end
    end
end
for _, fn in ipairs({setclipboard, toclipboard, writeclipboard}) do
    if type(fn) == "function" and pcall(fn, out) then break end
end

print("════════ GUARD SOURCE DUMP ════════")
print("decompiler = " .. (DEC and "✅ มี" or "❌ ไม่มี (executor นี้ decompile ไม่ได้)"))
print("เซฟไฟล์: guard_src_all.txt (โฟลเดอร์ workspace ของ executor) + ก๊อปให้แล้ว")
print("ยาวไป? เปิดไฟล์ guard_src_GuardEscapeRequirement... ส่งมาก่อนก็ได้")
print("═══════════════════════════════════")
