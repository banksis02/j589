-- ============================================================
-- AE — REMOTE SPY: จับ remote/signal ตอน "เปลี่ยน UI Scale" (เพื่อยิงตรง ไม่เปิด UI)
--   วิธีใช้:
--     1) รันสคริปต์นี้ (ติดตั้ง hook)
--     2) เปิด Settings → Miscellaneous → พิมพ์เลข UI Scale (เช่น 1) กด Enter  ทำ 2-3 ครั้ง (ค่าต่างกัน)
--     3) รัน  AE_SPY_SAVE()  → ก๊อป clipboard มาวางให้เดฟ
--   จับ FireServer/InvokeServer ทุกตัว + เน้น ReplicaSignal/Setting/Scale
-- ============================================================
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local ENV = (type(getgenv) == "function" and getgenv()) or _G

if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
    warn("[SPY] executor ไม่รองรับ hookmetamethod/getnamecallmethod")
    return
end

local log = {}
local function add(t) t = tostring(t); log[#log+1] = t; print("[SPY] " .. t) end

-- serialize arg สั้นๆ
local function ser(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "Instance" then return "<" .. v.ClassName .. ">" .. v.Name
    elseif t == "string" then return string.format("%q", v)
    elseif t == "CFrame" then local p = v.Position return ("CFrame(%.1f,%.1f,%.1f)"):format(p.X, p.Y, p.Z)
    elseif t == "Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
    elseif t == "table" then
        if d >= 4 then return "{..}" end
        local parts, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1; if n > 20 then parts[#parts+1] = "..."; break end
            parts[#parts+1] = "[" .. tostring(k) .. "]=" .. ser(vv, d + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else return t .. ":" .. tostring(v) end
end

ENV.AE_SPY_SAVE = function()
    local text = table.concat(log, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then print("[SPY] copied ✅ (" .. #log .. " บรรทัด)"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "ae_settings_spy.txt", text) end
end

add("════════ AE SETTINGS SPY เริ่ม — เปลี่ยน UI Scale แล้วรัน AE_SPY_SAVE() ════════")

local old
old = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = { ... }
        local name = ""
        pcall(function() name = self.Name end)
        local full = ""
        pcall(function() full = self:GetFullName() end)
        -- เน้นตัวที่น่าจะเกี่ยวกับ setting/scale (แต่ log ทุกตัวไว้ก่อน กันพลาด)
        local parts = {}
        for i = 1, math.min(#args, 8) do parts[#parts+1] = ser(args[i]) end
        local line = ("[%s] %s(%s)"):format(method, name, table.concat(parts, ", "))
        local low = string.lower(line)
        local hot = low:find("scale") or low:find("setting") or low:find("ui") or low:find("misc")
        add((hot and "⭐ " or "  ") .. line .. "   | " .. full)
    end
    return old(self, ...)
end)

add(">> hook ติดตั้งแล้ว — ไปเปลี่ยน UI Scale ในเกม (พิมพ์เลข+Enter) 2-3 ครั้ง → AE_SPY_SAVE()")
