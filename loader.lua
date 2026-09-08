-- ============================================================
-- GGx LOADER — เลือกโหลดสคริปต์ตามเกม (กัน BAC ของ Steal An Egg)
--   Steal An Egg = โหลดแค่ตัว notify min (pure-read เล็กๆ) — ไม่โหลด s789 ตัวใหญ่
--   เกมอื่นๆ      = โหลด s789 ปกติ
--   *** เปลี่ยน autoexec ของบอทให้ loadstring ตัวนี้ แทน s789 ***
--     loadstring(game:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/loader.lua"))()
-- ============================================================
local BASE = "https://raw.githubusercontent.com/banksis02/j589/main/"
local pid = game.PlaceId

local function run(file)
    local ok, src = pcall(function() return game:HttpGet(BASE .. file) end)
    if not ok or type(src) ~= "string" or #src == 0 then
        warn("[LOADER] โหลด " .. file .. " ไม่สำเร็จ: " .. tostring(src)); return
    end
    local fn = loadstring(src)
    if not fn then warn("[LOADER] compile " .. file .. " ไม่สำเร็จ"); return end
    print("[LOADER] ▶ โหลด " .. file .. " (placeId " .. tostring(pid) .. ")")
    fn()
end

if pid == 107778070777162 then
    -- Steal An Egg → ตัว notify มีชื่อไข่ (invoke cache, ไม่มี VirtualUser — รอด BAC)
    run("steal_an_egg_notify_names.lua")
else
    -- เกมอื่นๆ → s789 ตามปกติ
    run("s789")
end
