-- ============================================================
-- AE — CARRY ACTION SPY v2 (ปลอดภัย: ห่อ pcall ทั้ง hook — ไม่ทำให้ __namecall error)
--   จับ replica action ตอน วาง / เลือก Priority / อัพเกรด (เพื่อเพิ่มลงตัวแบก 77777)
--   วิธีใช้ (ในด่าน):
--     1) รันสคริปต์นี้
--     2) วางยูนิต 1 ตัว → คลิก Priority เลือก (เช่น Boss) → กดอัพเกรดตัวนั้น 1-2 ครั้ง
--     3) รัน  AE_CSPY_SAVE()  → ก๊อป clipboard มาวาง
-- ============================================================
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
    warn("[CSPY] executor ไม่รองรับ hookmetamethod"); return
end

local t0 = tick()
local log = {}
local function add(t) t = tostring(t); log[#log+1] = t; print("[CSPY] " .. t) end

-- serialize ปลอดภัย (ไม่มี GetDebugId / ไม่มี call เสี่ยง)
local function ser(v, d)
    d = d or 0
    local ok, out = pcall(function()
        local t = typeof(v)
        if t == "Instance" then return "<" .. v.ClassName .. ">" .. v.Name
        elseif t == "string" then return string.format("%q", v)
        elseif t == "CFrame" then local p = v.Position; return ("CFrame(%.1f,%.1f,%.1f)"):format(p.X, p.Y, p.Z)
        elseif t == "Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
        elseif t == "table" then
            if d >= 5 then return "{..}" end
            local parts, n = {}, 0
            for k, vv in pairs(v) do n = n + 1; if n > 25 then parts[#parts+1] = "..."; break end; parts[#parts+1] = "[" .. tostring(k) .. "]=" .. ser(vv, d + 1) end
            return "{" .. table.concat(parts, ", ") .. "}"
        else return t .. ":" .. tostring(v) end
    end)
    return ok and out or "?"
end

ENV.AE_CSPY_SAVE = function()
    local text = table.concat(log, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then print("[CSPY] copied ✅ (" .. #log .. " บรรทัด)"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "ae_carry_spy.txt", text) end
end

add("════ CARRY ACTION SPY v2 — วาง/Priority/อัพเกรด แล้วรัน AE_CSPY_SAVE() ════")

local old
old = hookmetamethod(game, "__namecall", function(self, ...)
    -- ⚠️ ทุกอย่างห่อ pcall — ห้าม error เด็ดขาด (ไม่งั้น __namecall พังทั้งเกม → โดนเตะ)
    local args = { ... }
    pcall(function()
        local m = getnamecallmethod()
        if m ~= "FireServer" and m ~= "InvokeServer" then return end
        local nm = self.Name
        -- เก็บเฉพาะ replica/action เกม (ตัด noise) — action อยู่ arg2 ปกติ (เช่น "PlaceGameUnit")
        local a2 = args[2]
        local low = (typeof(a2) == "string") and a2:lower() or ""
        local isAction = low:find("unit") or low:find("upgrad") or low:find("priorit") or low:find("target") or low:find("place")
            or nm == "ReplicaSignal" or nm == "_updateNode"
        if not isAction then return end
        local parts = {}
        for i = 1, math.min(#args, 10) do parts[#parts+1] = ser(args[i]) end
        add(("[%.1fs][%s] %s(%s)"):format(tick() - t0, m, nm, table.concat(parts, ", ")))
    end)
    return old(self, ...)
end)

add(">> hook ปลอดภัยติดตั้งแล้ว — วางตัว → Priority → อัพเกรด → AE_CSPY_SAVE()")
