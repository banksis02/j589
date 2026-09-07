-- ============================================================
-- STEAL AN EGG — MONEY LABEL + LIVENESS VERIFY (อ่านล้วน)
--   1) เจาะ label เงินรวม ($...T ไม่ใช่ /s ไม่ใช่ Kg)
--   2) เช็คว่า GrowingEggs timer + เงิน อัพเดตสดไหม (อ่าน 2 ครั้งห่าง 4 วิ)
-- ============================================================

local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local PG      = player:WaitForChild("PlayerGui")

local out = {}
local function add(t) t = tostring(t); out[#out+1] = t; print("[VF] " .. t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile) == "function" then pcall(writefile, "egg_verify.txt", text) end
end
-- ตัด rich-text <font..> ออก
local function strip(s) return (tostring(s):gsub("<[^>]->", "")) end

-- 1) label เงิน --------------------------------------------------
add("════════ MONEY LABELS ($ ก้อนใหญ่ ไม่ /s ไม่ Kg) ════════")
local NOISE = { "SurfaceGui", "ActivePets", "RobuxShop", "RiftTradeIn", "PetFuse",
                "SakuraEgg", "Backpack", "Codex", "AssetHoverData" }
local money = {}
for _, d in ipairs(PG:GetDescendants()) do
    if d:IsA("TextLabel") then
        local full = d:GetFullName()
        local noisy = false
        for _, ex in ipairs(NOISE) do if string.find(full, ex, 1, true) then noisy = true break end end
        if not noisy then
            local txt = strip(d.Text)
            if string.find(txt, "$") and not string.find(txt, "/s") and not string.find(txt, "Kg") then
                money[#money+1] = ("  %q  <- %s"):format(txt, full)
            end
        end
    end
end
if #money == 0 then add("  (ไม่เจอ label เงินแบบ $ นอก noise paths)") end
for _, line in ipairs(money) do add(line) end

-- 2) LIVENESS: อ่าน GrowingEggs timers + label เงิน 2 ครั้ง ---------
local function readGrowing()
    local res = {}
    local ge = PG:FindFirstChild("GrowingEggs")
    local sf = ge and ge:FindFirstChild("Frame")
    sf = sf and sf:FindFirstChild("ScrollingFrame")
    if not sf then return res end
    for _, slot in ipairs(sf:GetChildren()) do
        if slot:IsA("Frame") and slot.Name ~= "Template" and slot.Name ~= "EmptyLast" then
            local tl = slot:FindFirstChild("Spacer")
            tl = tl and tl:FindFirstChild("Progress")
            tl = tl and tl:FindFirstChild("TextLabel")
            if tl then res[slot.Name] = tostring(tl.Text) end
        end
    end
    return res
end

add(""); add("════════ LIVENESS (panel ปิดอยู่ อ่าน 2 ครั้งห่าง 4 วิ) ════════")
local ge = PG:FindFirstChild("GrowingEggs")
add("GrowingEggs.Enabled = " .. tostring(ge and ge.Enabled))
local g1 = readGrowing()
add("-- GrowingEggs รอบ 1 --")
for uid, t in pairs(g1) do add(("  %s = %s"):format(uid:sub(1,8), t)) end
task.wait(4)
local g2 = readGrowing()
add("-- GrowingEggs รอบ 2 (หลัง 4 วิ) --")
local changed = false
for uid, t in pairs(g2) do
    local before = g1[uid] or "?"
    local mark = (before ~= t) and "  <== เปลี่ยน (สด!)" or ""
    if before ~= t then changed = true end
    add(("  %s = %s (ก่อน %s)%s"):format(uid:sub(1,8), t, before, mark))
end
add(">> timer " .. (changed and "อัพเดตสดแม้ panel ปิด ✅" or "ไม่เปลี่ยน — อาจต้องเปิด panel/คำนวณเอง ⚠️"))

save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
