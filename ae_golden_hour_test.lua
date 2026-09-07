-- ============================================================
-- ANIME EXPEDITIONS — GOLDEN HOUR (standalone test) v0.1
--   ทดสอบทีละสเต็ปก่อนรวมเข้า s789:
--     AE_GH_FIND()   = หาว่าด่านไหนมี Golden Hour (+ เวลาเหลือ) — ไม่คลิก
--     AE_GH_ENTER()  = คลิกการ์ด GH → เลือกแท็บ GH → กดเริ่ม (log ทุกสเต็ป)
--     AE_GH_RUN()    = ลูปเต็ม: เข้า→เล่นจบ→รีเพลย์ วนจนหมดเวลา→กลับ lobby→หา GH ใหม่
--     AE_GH_STOP()   = หยุด
--   *** ทดสอบ AE_GH_FIND() ก่อน แล้ว AE_GH_ENTER() แล้วบอกผลว่าเข้าด่านได้ไหม ***
-- ============================================================
local SV = "v0.1"
_G.AE_GH_GEN = (_G.AE_GH_GEN or 0) + 1
local GEN = _G.AE_GH_GEN
local function alive() return GEN == _G.AE_GH_GEN end

local Players = game:GetService("Players")
local VIM     = game:GetService("VirtualInputManager")
local GuiSvc  = game:GetService("GuiService")
local player  = Players.LocalPlayer
local ENV = (type(getgenv) == "function" and getgenv()) or _G
local function log(t) print("[AE-GH " .. SV .. "] " .. tostring(t)) end
local function playRoot() return player.PlayerGui:FindFirstChild("Play") or player.PlayerGui end
local function strip(s) return (tostring(s):gsub("<[^>]->", "")) end

local STAGES = { "School Grounds", "Flower Forest", "Rose Kingdom", "East Town",
                 "Fairy King Forest", "King's Tomb", "Crimson Shore" }

-- ── คลิก: fire connections + VIM mouse fallback ────────────────
local function fireBtn(btn)
    local fired = 0
    pcall(function()
        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire(); fired = fired + 1 end
    end)
    if fired == 0 then
        pcall(function()
            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire(); fired = fired + 1 end
        end)
    end
    -- VIM click เผื่อ fire ไม่ติด
    pcall(function()
        local inset = GuiSvc:GetGuiInset()
        local cx = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2
        local cy = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2 + inset.Y
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0); task.wait(0.05)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
    return fired
end

-- หาปุ่ม (TextButton/ImageButton) ที่ text ตัวเอง/ลูก == target (normalize)
local function norm(s) return (tostring(s):lower():gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")) end
local function btnText(b)
    if b:IsA("TextButton") and strip(b.Text) ~= "" then return strip(b.Text) end
    for _, c in ipairs(b:GetDescendants()) do
        if c:IsA("TextLabel") and strip(c.Text) ~= "" then return strip(c.Text) end
    end
    return ""
end
local function findButtonByText(target)
    local t = norm(target)
    for _, b in ipairs(playRoot():GetDescendants()) do
        if (b:IsA("TextButton") or b:IsA("ImageButton")) then
            local vis = true; pcall(function() vis = b.Visible end)
            if vis and norm(btnText(b)) == t then return b end
        end
    end
    return nil
end
local function clickText(target, waitSec)
    local deadline = os.clock() + (waitSec or 0)
    repeat
        local b = findButtonByText(target)
        if b then
            local n = fireBtn(b)
            log(("คลิก '%s' (fired=%d)"):format(target, n))
            return true
        end
        task.wait(0.3)
    until os.clock() > deadline
    return false
end

-- ── หา horizontal ScrollingFrame ของแถบด่าน ────────────────────
local function stageScroller()
    local best
    for _, f in ipairs(playRoot():GetDescendants()) do
        if f:IsA("ScrollingFrame") and f.Visible and f.AbsoluteCanvasSize.X > f.AbsoluteSize.X + 50 then
            if not best or f.AbsoluteSize.X > best.AbsoluteSize.X then best = f end
        end
    end
    return best
end

-- ── หาการ์ดที่มี label "Golden Hour" (คืน card + ชื่อด่าน) ──────
local function findGHCardNow()
    for _, b in ipairs(playRoot():GetDescendants()) do
        if b:IsA("TextButton") then
            local hasGH, stageName = false, nil
            for _, c in ipairs(b:GetDescendants()) do
                if c:IsA("TextLabel") then
                    local txt = strip(c.Text)
                    if norm(txt) == "golden hour" then hasGH = true end
                    for _, sn in ipairs(STAGES) do if txt == sn then stageName = sn end end
                end
            end
            if hasGH and stageName then return b, stageName end
        end
    end
    return nil
end

-- เลื่อนหาการ์ด GH ทั้งแถบ
local function findGHCardScroll()
    local card, name = findGHCardNow()
    if card then return card, name end
    local sf = stageScroller()
    if not sf then return nil end
    local maxX = math.max(0, sf.AbsoluteCanvasSize.X - sf.AbsoluteSize.X)
    local step = math.max(200, sf.AbsoluteSize.X * 0.6)
    local x = 0
    while x <= maxX + step and alive() do
        pcall(function() sf.CanvasPosition = Vector2.new(math.min(x, maxX), sf.CanvasPosition.Y) end)
        task.wait(0.35)
        card, name = findGHCardNow()
        if card then return card, name end
        if x >= maxX then break end
        x = x + step
    end
    return nil
end

-- อ่าน timer แท็บ GH บนจอ stage-select (ปุ่มที่ text = mm:ss)
local function readGHTimer()
    for _, b in ipairs(playRoot():GetDescendants()) do
        if b:IsA("TextButton") then
            local t = strip(b.Text)
            if string.match(t, "^%d+:%d%d$") then return t, b end
        end
    end
    return nil
end

-- ── COMMANDS ────────────────────────────────────────────────
ENV.AE_GH_FIND = function()
    local card, name = findGHCardScroll()
    if card then log("✅ Golden Hour อยู่ที่ด่าน: " .. name)
    else log("❌ ไม่เจอด่านที่มี Golden Hour (เปิดหน้า Story map ไหม?)") end
    return name
end

ENV.AE_GH_ENTER = function()
    local card, name = findGHCardScroll()
    if not card then log("❌ ไม่เจอการ์ด GH"); return false end
    log("→ คลิกการ์ด " .. name)
    fireBtn(card)
    task.wait(1.5)
    -- เลือกแท็บ GH (ปุ่ม timer mm:ss) ถ้ามี
    local tv, tb = readGHTimer()
    if tb then log("→ แท็บ GH (เหลือ " .. tostring(tv) .. ") คลิก"); fireBtn(tb); task.wait(1) end
    -- กดเริ่ม: ลอง Select Stage → ถ้ามี Start/Enter Matchmaking ค่อยกด
    log("ปุ่มบนจอตอนนี้: " .. (function()
        local names = {}
        for _, b in ipairs(playRoot():GetDescendants()) do
            if (b:IsA("TextButton")) and b.Visible then
                local t = btnText(b); if t ~= "" then names[#names+1] = t end
            end
        end
        return table.concat(names, " | ")
    end)())
    if clickText("Select Stage", 3) then task.wait(1.5) end
    if not clickText("Start", 3) then clickText("Enter Matchmaking", 3) end
    return true
end

ENV.AE_GH_STOP = function() ENV.AE_GH_RUNNING = false; log("สั่งหยุด") end

ENV.AE_GH_RUN = function()
    if ENV.AE_GH_RUNNING then return end
    ENV.AE_GH_RUNNING = true
    log("▶️ GH RUN — วนหา/เล่น Golden Hour (หยุด: AE_GH_STOP())")
    task.spawn(function()
        while alive() and ENV.AE_GH_RUNNING do
            local name = ENV.AE_GH_FIND()
            if not name then
                -- ไม่เจอ GH → อยู่ lobby รอ/หาใหม่
                task.wait(10)
            else
                ENV.AE_GH_ENTER()
                -- เล่นวนจนกว่าจะไม่อยู่ในแมตช์ (จบ) แล้วรีเพลย์
                local roundGuard = os.clock() + 60 * 40  -- กันค้างสูงสุด 40 นาที
                while alive() and ENV.AE_GH_RUNNING and os.clock() < roundGuard do
                    local prompt = player.PlayerGui:FindFirstChild("Prompt")
                    local ended = false
                    if prompt and prompt.Enabled then
                        for _, d in ipairs(prompt:GetDescendants()) do
                            if d:IsA("TextLabel") and (d.Text == "Victory" or d.Text == "Defeat") then ended = true break end
                        end
                    end
                    if ended then
                        log("รอบจบ → ลองรีเพลย์")
                        if not clickText("Replay", 3) and not clickText("Retry", 3) then
                            -- ไม่มีปุ่มรีเพลย์ → ออกไป lobby หา GH ใหม่
                            if _G.AE_BACK_TO_LOBBY then pcall(_G.AE_BACK_TO_LOBBY) end
                            break
                        end
                        task.wait(3)
                    end
                    task.wait(3)
                end
                -- ครบรอบ/GH ย้าย → กลับ lobby หา GH ใหม่
                if _G.AE_BACK_TO_LOBBY then pcall(_G.AE_BACK_TO_LOBBY) end
                task.wait(3)
            end
        end
        log("⏹️ GH หยุดแล้ว")
    end)
end

log("โหลดแล้ว ✅ v" .. SV)
log("ทดสอบ: AE_GH_FIND() → AE_GH_ENTER() (ดูว่าเข้าด่านได้ไหม) แล้วค่อย AE_GH_RUN()")
