-- ============================================================
-- GGx LOADER — เลือกโหลดสคริปต์ตามเกม (กัน BAC ของ Steal An Egg)
--   Steal An Egg = notify names + auto-hop — ไม่โหลด s789 ตัวใหญ่
--   เกมอื่นๆ      = โหลด s789 ปกติ
--   *** เปลี่ยน autoexec ของบอทให้ loadstring ตัวนี้ แทน s789 ***
--     loadstring(game:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/loader.lua"))()
-- ============================================================
local BASE = "https://raw.githubusercontent.com/banksis02/j589/main/"
local pid = game.PlaceId

local function run(file, starter)
    local ok, src = pcall(function() return game:HttpGet(BASE .. file) end)
    if not ok or type(src) ~= "string" or #src == 0 then
        warn("[LOADER] โหลด " .. file .. " ไม่สำเร็จ: " .. tostring(src)); return
    end
    local fn = loadstring(src)
    if not fn then warn("[LOADER] compile " .. file .. " ไม่สำเร็จ"); return end
    print("[LOADER] ▶ โหลด " .. file .. " (placeId " .. tostring(pid) .. ")")
    local result = fn()
    if starter then
        assert(type(result) == "function", "invalid starter: " .. file)
        result()
    end
end

if pid == 107778070777162 then
    task.spawn(function()
        local ok, err = pcall(function()
            local source = game:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/steal_an_egg_fall_recovery.lua?v=1")
            local chunk, compileError = loadstring(source)
            assert(chunk, compileError)
            chunk()
        end)
        if not ok then warn("[SAE FALL] load failed: " .. tostring(err)) end
    end)

    task.spawn(function()
        local ok, err = pcall(run, "steal_an_egg_report.lua?v=1.3")
        if not ok then warn("[LOADER] report failed: " .. tostring(err)) end
    end)
    -- Independent tasks: a long-running notifier must not block population checks.
    task.spawn(function()
        local ok, err = pcall(run, "steal_an_egg_auto_hop.lua?v=8", true)
        if not ok then warn("[LOADER] auto-hop failed: " .. tostring(err)) end
    end)
    -- Steal An Egg → ตัว notify มีชื่อไข่ (invoke cache, ไม่มี VirtualUser — รอด BAC)
    run("steal_an_egg_notify_names.lua")
else
    -- เกมอื่นๆ → s789 ตามปกติ
    run("s789")
end
