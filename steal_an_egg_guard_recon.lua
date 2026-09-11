-- ============================================================
-- STEAL AN EGG — GUARD RECON (อ่านอย่างเดียว ไม่ hook = ปลอดภัย ไม่เด้ง)
-- หา client script/โมเดลที่คุม "guard/ยาม" เพื่อดูว่าปิดตัวไหนได้
-- (เหมือนที่ปิด ObbyAntiTPClient) → รัน แล้วก๊อป output มาให้
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local SP      = game:GetService("StarterPlayer")
local player  = Players.LocalPlayer

local logs = {}
local function push(l) logs[#logs+1]=l; print(l) end
local function save()
    local txt = table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,txt) then break end
    end
    if type(writefile)=="function" then pcall(writefile,"egg_guard_recon.txt",txt) end
end

-- คำที่บ่งชี้ระบบยาม/จับ
local KW = {"guard","patrol","catch","steal","alert","chase","security","warden","cop","police","pursuit","detect"}
local function hit(name)
    local n = name:lower()
    for _,k in ipairs(KW) do if n:find(k) then return k end end
    return nil
end

local seen = {}
local function scan(root, label, maxprint)
    local count, printed = 0, 0
    local ok = pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            local k = hit(d.Name)
            if k and not seen[d] then
                seen[d] = true
                count = count + 1
                if d:IsA("LuaSourceContainer") or d:IsA("Model") or d:IsA("Folder")
                   or d:IsA("BasePart") or d:IsA("Configuration") then
                    if printed < (maxprint or 60) then
                        printed = printed + 1
                        local extra = ""
                        if d:IsA("Script") or d:IsA("LocalScript") then
                            extra = " Enabled=" .. tostring(d.Enabled)
                        end
                        push(("  [%s] <%s> %s%s"):format(k, d.ClassName, d:GetFullName(), extra))
                    end
                end
            end
        end
    end)
    push(("── %s : เจอ %d รายการ%s"):format(label, count, ok and "" or " (อ่านบางส่วนไม่ได้)"))
end

push("════════ GUARD RECON ════════")

-- 1) client scripts ที่กำลังรัน (PlayerScripts) — ตรงนี้ปิดได้ทันที (Enabled=false / Destroy)
local ps = player:FindFirstChild("PlayerScripts")
if ps then scan(ps, "PlayerScripts (รันอยู่)") else push("── ไม่มี PlayerScripts") end

-- 2) StarterPlayerScripts (ต้นฉบับก่อนถูกก๊อปไป PlayerScripts)
scan(SP, "StarterPlayer")

-- 3) ReplicatedStorage (module ที่ client require เรียกใช้ระบบ guard)
scan(RS, "ReplicatedStorage", 80)

-- 4) Workspace (โมเดลยาม + สคริปต์ในตัวมัน)
scan(WS, "Workspace", 80)

-- 5) โฟกัส: หาโมเดล guard จริงใน Workspace + ProximityPrompt/ตัวจับ
push("── โมเดล guard ใน Workspace (5 ตัวแรก + ลูกที่น่าสน):")
do
    local shown = 0
    for _, m in ipairs(WS:GetDescendants()) do
        if shown >= 5 then break end
        if m:IsA("Model") and hit(m.Name) then
            shown = shown + 1
            push(("  <Model> %s"):format(m:GetFullName()))
            for _, c in ipairs(m:GetChildren()) do
                if c:IsA("LuaSourceContainer") or c:IsA("Configuration")
                   or c:IsA("Humanoid") or c:IsA("ProximityPrompt") then
                    push(("      └ <%s> %s"):format(c.ClassName, c.Name))
                end
            end
        end
    end
    if shown == 0 then push("  (ไม่เจอโมเดลชื่อ guard — ยามอาจชื่ออื่น/อยู่ใน ReplicatedStorage)") end
end

-- 6) ดู client scripts ทั้งหมดใน PlayerScripts (เผื่อยามชื่อไม่ตรง keyword)
push("── LocalScript/ModuleScript ทั้งหมดใน PlayerScripts (ดูชื่อรวม):")
if ps then
    local n = 0
    for _, d in ipairs(ps:GetDescendants()) do
        if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and n < 60 then
            n = n + 1
            push(("  <%s> %s"):format(d.ClassName, d.Name))
        end
    end
    push(("  (รวม %d — ถ้าเยอะกว่านี้บอกได้)"):format(n))
end

push("════════ จบ — ก๊อปแล้ว วางมาให้เลย ════════")
save()
