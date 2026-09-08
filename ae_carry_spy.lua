-- ============================================================
-- AE — CARRY ACTION SPY: จับ remote ตอน วาง/เลือก Priority/อัพเกรด (เพื่อเพิ่มลงตัวแบก)
--   วิธีใช้ (ในด่าน):
--     1) รันสคริปต์นี้
--     2) วางยูนิต 1 ตัว → คลิก Priority เลือก (เช่น Boss) → กดอัพเกรดตัวนั้น 1-2 ครั้ง
--     3) รัน  AE_CSPY_SAVE()  → ก๊อป clipboard มาวาง
--   จับ FireServer/InvokeServer ทุกตัว + serialize args เต็ม (ดูว่าอ้างยูนิตยังไง)
-- ============================================================
local Players = game:GetService("Players")
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
    warn("[CSPY] executor ไม่รองรับ hookmetamethod"); return
end

local t0 = tick()
local log = {}
local function add(t) t=tostring(t); log[#log+1]=t; print("[CSPY] "..t) end

local function ser(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "Instance" then return "<"..v.ClassName..">"..v.Name.."(id="..tostring(v:GetDebugId and select(1, pcall(function() return v:GetDebugId() end)) or "?")..")"
    elseif t == "string" then return string.format("%q", v)
    elseif t == "CFrame" then local p=v.Position return ("CFrame(%.1f,%.1f,%.1f)"):format(p.X,p.Y,p.Z)
    elseif t == "Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z)
    elseif t == "table" then
        if d>=5 then return "{..}" end
        local parts,n={},0
        for k,vv in pairs(v) do n=n+1; if n>25 then parts[#parts+1]="..."; break end; parts[#parts+1]="["..tostring(k).."]="..ser(vv,d+1) end
        return "{"..table.concat(parts,", ").."}"
    else return t..":"..tostring(v) end
end

ENV.AE_CSPY_SAVE = function()
    local text = table.concat(log, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn)=="function" and pcall(fn, text) then print("[CSPY] copied ✅ ("..#log.." บรรทัด)"); break end
    end
    if type(writefile)=="function" then pcall(writefile, "ae_carry_spy.txt", text) end
end

add("════ CARRY ACTION SPY — วาง/Priority/อัพเกรด แล้วรัน AE_CSPY_SAVE() ════")

local old
old = hookmetamethod(game, "__namecall", function(self, ...)
    local m = getnamecallmethod()
    if m == "FireServer" or m == "InvokeServer" then
        local args = { ... }
        local nm, full = "", ""
        pcall(function() nm = self.Name end)
        pcall(function() full = self:GetFullName() end)
        -- log เฉพาะ remote เกม (ReplicaSignal / _updateNode / อื่นๆ) — ตัด chat/telemetry ทั่วไปออกไม่ได้ก็ log หมด
        local parts = {}
        for i=1, math.min(#args, 10) do parts[#parts+1] = ser(args[i]) end
        local line = ("[%.1fs][%s] %s(%s)"):format(tick()-t0, m, nm, table.concat(parts, ", "))
        local low = line:lower()
        local hot = low:find("upgrad") or low:find("target") or low:find("priorit") or low:find("place") or low:find("unit")
        add((hot and "⭐ " or "  ")..line.."   | "..full)
    end
    return old(self, ...)
end)

add(">> hook ติดตั้งแล้ว — วางตัว → เลือก Priority → อัพเกรด → AE_CSPY_SAVE()")
