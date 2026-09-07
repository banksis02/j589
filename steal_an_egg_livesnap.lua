-- ============================================================
-- STEAL AN EGG — LIVE SNAPSHOT PROBE (invoke EggWorld snapshot — pattern เดียวกับ farm เดิม)
--   ดู AskLiveSnapshot / AskEggRecord ว่าคืน "ไข่ที่กำลังโต + ชื่อ + เวลาเหลือ" ไหม
-- ============================================================

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[LIVE] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "egg_livesnap.txt", text) end
end
local function ser(v, d, seen)
    d = d or 0; seen = seen or {}
    local t = typeof(v)
    if t == "Instance" then return "<"..v.ClassName..">"..v.Name
    elseif t == "string" then return string.format("%q", v)
    elseif t == "CFrame" then local p=v.Position return ("CFrame(%.1f,%.1f,%.1f)"):format(p.X,p.Y,p.Z)
    elseif t == "Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z)
    elseif t ~= "table" then return t..":"..tostring(v) end
    if seen[v] then return "{recur}" end
    if d >= 7 then return "{..}" end
    seen[v] = true
    local parts, n = {}, 0
    for k, vv in pairs(v) do
        n = n + 1
        if n > 80 then parts[#parts+1] = "..." break end
        parts[#parts+1] = "["..tostring(k).."]="..ser(vv, d+1, seen)
    end
    return "{"..table.concat(parts, ", ").."}"
end

local NET = RS:FindFirstChild("Packages")
NET = NET and NET:FindFirstChild("Networking")
local function invoke(name, ...)
    local r = NET and NET:FindFirstChild(name)
    if not r then add(name .. " = ไม่เจอ") return end
    local ok, res = pcall(function(...) return r:InvokeServer(...) end, ...)
    add("──────── " .. name .. " (ok=" .. tostring(ok) .. ") ────────")
    add(ser(res))
    -- ถ้าเป็น list ของ record โชว์ key element แรก
    if type(res) == "table" then
        for k, v in pairs(res) do
            if type(v) == "table" then
                local keys = {}
                for kk, vv in pairs(v) do keys[#keys+1] = tostring(kk) .. "=" .. typeof(vv) end
                add("   element[" .. tostring(k) .. "] keys: " .. table.concat(keys, ", "))
                break
            end
        end
    end
end

add("════════ LIVE SNAPSHOT  Player=" .. player.Name .. " ════════")
add("Networking = " .. (NET and NET:GetFullName() or "ไม่เจอ"))
add("")
invoke("RF/EggWorld/AskLiveSnapshot")
add("")
invoke("RF/EggWorld/AskEggRecord")

-- หา label HUD เงินรวม/เพชร มุมจอ (ตัดพวก shop/SurfaceGui/ActivePets ออก) --
add(""); add("════════ HUD money/gem labels (ตัด shop/leaderboard) ════════")
local PG = player:WaitForChild("PlayerGui")
local EXCLUDE = { "SurfaceGui", "ActivePets", "RobuxShop", "RiftTradeIn", "PetFuse",
                  "SakuraEgg", "GrowingEggs", "AssetEggData", "Index", "Codex", "Shop" }
local shown = 0
for _, d in ipairs(PG:GetDescendants()) do
    if d:IsA("TextLabel") then
        local full = d:GetFullName()
        local skip = false
        for _, ex in ipairs(EXCLUDE) do if string.find(full, ex, 1, true) then skip = true break end end
        if not skip then
            local txt = tostring(d.Text)
            -- ขึ้นต้นด้วย $ หรือ ตัวเลข+หน่วยย่อ (2.5T / 84.4M) หรือมี /s
            if string.match(txt, "^%$") or string.match(txt, "^%d[%d,%.]*%s*[KMBTQ]")
                or string.match(txt, "%d[%d%.]*[KMBTQ]") then
                shown = shown + 1
                if shown <= 40 then add(("  %q  <- %s"):format(txt, full)) end
            end
        end
    end
end
add("  (เจอ " .. shown .. ")")

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
