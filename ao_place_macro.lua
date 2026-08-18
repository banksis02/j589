-- ============================================================
-- ANIME ORIGINS — PLACEMENT MACRO (record / replay) v0.3  แยกจากสคริปต์หลัก
-- อัด: วางตัว + อัพเกรด (UpgradeTower ตามลำดับ) + เวลาจริง
-- เล่นซ้ำ + AUTO LOOP: play -> จบด่าน -> กดรางวัล+Replay -> เวฟใหม่ -> play ต่อ
-- โหลด: loadstring(game:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/ao_place_macro.lua"))()
-- ============================================================
local MACRO_VERSION = "0.5"

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VIM = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local placeRemote = RS:FindFirstChild("LobbyRemotes")
placeRemote = placeRemote and placeRemote:FindFirstChild("TowerHandlerRemotes")
placeRemote = placeRemote and placeRemote:FindFirstChild("TowerHandlerFunction")
local setClip = setclipboard or toclipboard or (syn and syn.setclipboard) or set_clipboard or function() end

-- บันทึกลงไฟล์ (กันหายตอนออกด่าน/โหลดใหม่) — เก็บแยกต่อด่าน
local hasFS = (writefile and readfile and isfile) and true or false
local MACRO_DIR = "AO_Macros"

-- ---------- helpers ----------
local function clean(s) return (tostring(s or ""):gsub("<[^>]->", "")) end
local function gameUI() return player.PlayerGui:FindFirstChild("GameUI") end
local function readWave()
    local w = 0
    pcall(function() w = tonumber(tostring(clean(gameUI().TopUI.Info.Wave.TextLabel.Text)):match("^(%d+)")) or 0 end)
    return w
end
local function readStage()
    local s = "Unknown"
    pcall(function()
        local ai = gameUI().ManagementFrame.SideButtons.ActInfo
        s = string.format("%s - %s (%s)", clean(ai.World.Text), clean(ai.Act.Text), clean(ai.Difficulty.Text))
    end)
    return s
end
local function actOver() local g = gameUI(); return g and g:FindFirstChild("ActOver") end
local function actOverVisible()
    local v = false
    pcall(function() local a = actOver(); v = a ~= nil and a.Visible == true end)
    return v
end
local function shown(o)
    local n = o
    while n and n ~= player.PlayerGui do
        if n:IsA("GuiObject") and not n.Visible then return false end
        if n:IsA("ScreenGui") and not n.Enabled then return false end
        n = n.Parent
    end
    return true
end
local function hardClick(guiObj)
    if not guiObj then return end
    pcall(function()
        if getconnections then
            local gb = guiObj:IsA("GuiButton") and guiObj or guiObj:FindFirstChildWhichIsA("GuiButton", true)
            if gb then
                for _, c in ipairs(getconnections(gb.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(gb.MouseButton1Click)) do c:Fire() end
            end
        end
    end)
    pcall(function()
        local cx = math.floor(guiObj.AbsolutePosition.X + guiObj.AbsoluteSize.X / 2)
        local cy = math.floor(guiObj.AbsolutePosition.Y + guiObj.AbsoluteSize.Y / 2)
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0); task.wait(0.05)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end
-- คลิกปุ่ม/พื้นที่ตามข้อความ (claim/collect/close/ok)
local function clickByText(patterns)
    local hit = false
    pcall(function()
        for _, g in ipairs(player.PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled then
                for _, o in ipairs(g:GetDescendants()) do
                    if (o:IsA("TextButton") or o:IsA("TextLabel")) and shown(o) then
                        local t = clean(o.Text):lower()
                        for _, p in ipairs(patterns) do
                            if t:find(p, 1, true) then
                                hardClick(o:IsA("GuiButton") and o or o:FindFirstAncestorWhichIsA("GuiButton") or o)
                                hit = true; return
                            end
                        end
                    end
                end
            end
        end
    end)
    return hit
end
local function dismissReward()
    -- ปุ่มเก็บรางวัล/ปิด ถ้ามี
    clickByText({ "claim", "collect", "continue", "obtained" })
    -- popup "click anywhere to close" → คลิกมุมขวาล่าง
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            local x, y = math.floor(cam.ViewportSize.X - 40), math.floor(cam.ViewportSize.Y - 40)
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 0); task.wait(0.05)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end
    end)
end
local function clickReplay()
    local a = actOver()
    if not a then return false end
    local btn
    pcall(function() btn = a.Main.ContentFrame.Main.BottomButtons.Inner.Replay end)
    if not btn then return false end
    hardClick(btn)
    return true
end

local function placeTower(slot, pos, hill)
    if not placeRemote then return false, "no remote" end
    local ok, res = pcall(function()
        return placeRemote:InvokeServer("PlaceTower", "Tower" .. tostring(slot), pos, Vector3.new(0, 1, 0), 0, nil, hill)
    end)
    if not ok then return false, res end
    if typeof(res) == "table" then return true, res end
    return false, res
end
local function upgradeTower(uuid)
    if not placeRemote or not uuid then return false end
    local ok, res = pcall(function() return placeRemote:InvokeServer("UpgradeTower", uuid) end)
    return ok and res == true
end

-- ---------- containers ที่อาจเก็บ instance ของยูนิตที่วาง (ลองหลายที่) ----------
local function containers()
    local out = {}
    local t = workspace:FindFirstChild("Towers"); if t then out[#out + 1] = { name = "Towers", inst = t } end
    local u = workspace:FindFirstChild("UnitNodes"); if u then out[#out + 1] = { name = "UnitNodes", inst = u } end
    pcall(function()
        local sf = gameUI().ManagementFrame.UnitManagerFrame.Main.CanvasGroup.ScrollingFrame
        if sf then out[#out + 1] = { name = "UMSF", inst = sf } end
    end)
    return out
end
local function instKeys(c)  -- Name + ค่า attribute ที่เป็น string (uuid อาจอยู่ตรงไหนก็ได้)
    local keys = { c.Name }
    pcall(function()
        for _, v in pairs(c:GetAttributes()) do if type(v) == "string" then keys[#keys + 1] = v end end
    end)
    return keys
end
local function fieldValue(inst, field)
    if field == "Name" then return inst.Name end
    if field:sub(1, 1) == "@" then local v; pcall(function() v = inst:GetAttribute(field:sub(2)) end); return v and tostring(v) end
    return nil
end
local function detectField(inst, uuid)
    if inst.Name == uuid then return "Name" end
    local f
    pcall(function() for k, v in pairs(inst:GetAttributes()) do if tostring(v) == uuid then f = "@" .. k end end end)
    return f
end

-- ---------- state ----------
local macro = { version = MACRO_VERSION, stage = "", events = {}, container = nil, field = nil }
local recording, playing, autoOn = false, false, false
local recStart = 0
-- track appearance order ต่อ container ตอนอัด
local recTrack = {}   -- [name] = { inst=..., order={inst}, seen={}, keyIdx={} }
local statusCb = function() end

local function resetRecTrack()
    recTrack = {}
    for _, c in ipairs(containers()) do
        recTrack[c.name] = { inst = c.inst, order = {}, seen = {}, keyIdx = {} }
    end
end
local function mapNew(track)
    local f = track.inst
    if not f or not f.Parent then return end
    for _, c in ipairs(f:GetChildren()) do
        if c:IsA("Instance") and not c:IsA("UIListLayout") and c.Name ~= "Template"
            and c.Name ~= "VFXButton" and not track.seen[c] then
            track.seen[c] = true
            track.order[#track.order + 1] = c
            local idx = #track.order
            for _, key in ipairs(instKeys(c)) do if not track.keyIdx[key] then track.keyIdx[key] = idx end end
        end
    end
end

-- ---------- hook remote (อัด) ----------
local hookedOK = false
pcall(function()
    if not (hookmetamethod and getnamecallmethod) then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local a
        if recording and self == placeRemote and method == "InvokeServer" then a = { ... } end
        local res = old(self, ...)
        if a then
            local action = tostring(a[1])
            if action == "PlaceTower" and typeof(res) == "table" then
                local slot = tonumber(tostring(a[2] or ""):match("Tower(%d+)"))
                local pos = a[3]
                if slot and typeof(pos) == "Vector3" then
                    macro.events[#macro.events + 1] = { k = "place", t = math.floor((os.clock() - recStart) * 100) / 100,
                        w = readWave(), slot = slot, pos = { x = pos.X, y = pos.Y, z = pos.Z }, hill = a[7] == true }
                    statusCb(("🔴 วาง T%d (%d)"):format(slot, #macro.events))
                end
            elseif action == "UpgradeTower" and res == true then
                macro.events[#macro.events + 1] = { k = "up", t = math.floor((os.clock() - recStart) * 100) / 100,
                    action = "UpgradeTower", uuid = tostring(a[2] or "") }
                statusCb(("🔴 อัพเกรด (%d)"):format(#macro.events))
            end
        end
        return res
    end)
    hookedOK = true
end)

-- record poller
task.spawn(function()
    while true do
        if recording then for _, tr in pairs(recTrack) do mapNew(tr) end end
        task.wait(0.1)
    end
end)

-- ---------- resolve upgrade -> placement index (เลือก container ที่เจอ uuid) ----------
local function resolveUpgradeIdx()
    for _, tr in pairs(recTrack) do mapNew(tr) end
    -- หา container ที่ keyIdx มี uuid ของ upgrade
    local sample
    for _, e in ipairs(macro.events) do if e.k == "up" and e.uuid and e.uuid ~= "" then sample = e.uuid; break end end
    local chosenName, chosenTrack
    if sample then
        for name, tr in pairs(recTrack) do if tr.keyIdx[sample] then chosenName = name; chosenTrack = tr; break end end
    end
    macro.container = chosenName
    macro.field = nil
    local mapped, total = 0, 0
    for _, e in ipairs(macro.events) do
        if e.k == "up" then
            total = total + 1
            if chosenTrack and e.uuid then
                e.idx = chosenTrack.keyIdx[e.uuid]
                if e.idx then
                    mapped = mapped + 1
                    if not macro.field then macro.field = detectField(chosenTrack.order[e.idx], e.uuid) end
                end
            end
            e.uuid = nil
        end
    end
    return mapped, total
end

-- ---------- play (blocking-ish ผ่าน flag playing) ----------
local function stopPlay() playing = false end
local function play()
    if playing then return end
    if #macro.events == 0 then statusCb("ไม่มี macro"); return end
    playing = true
    task.spawn(function()
        -- poller เฉพาะ container ที่เลือก (สำหรับ map อัพเกรดตอนเล่น)
        local track
        if macro.container then
            for _, c in ipairs(containers()) do if c.name == macro.container then track = { inst = c.inst, order = {}, seen = {}, keyIdx = {} } end end
        end
        local alive = true
        if track then task.spawn(function() while alive and playing do mapNew(track); task.wait(0.08) end end) end
        local t0 = os.clock()
        for i, e in ipairs(macro.events) do
            if not playing then break end
            while playing and os.clock() - t0 < (e.t or 0) do task.wait(0.05) end
            if e.k == "place" then
                local pos = Vector3.new(e.pos.x, e.pos.y, e.pos.z)
                local placed, wrong = false, 0
                while playing and not placed and wrong < 6 do
                    local ok, res = placeTower(e.slot, pos, e.hill)
                    if ok then placed = true elseif res == -1 then task.wait(0.5) else wrong = wrong + 1; task.wait(0.15) end
                end
                statusCb(("▶️ %d/%d วาง T%d %s"):format(i, #macro.events, e.slot, placed and "✓" or "ข้าม"))
            elseif e.k == "up" and e.idx and track then
                local wt = os.clock()
                while playing and not track.order[e.idx] and os.clock() - wt < 4 do task.wait(0.1) end
                local inst = track.order[e.idx]
                local uuid = inst and fieldValue(inst, macro.field or "Name")
                local done, tries = false, 0
                while playing and uuid and not done and tries < 8 do tries = tries + 1
                    if upgradeTower(uuid) then done = true else task.wait(0.4) end end
                statusCb(("▶️ %d/%d อัพเกรด #%d %s"):format(i, #macro.events, e.idx, done and "✓" or "-"))
            end
        end
        alive = false; playing = false
        statusCb("▶️ เล่นจบ (" .. #macro.events .. ")")
    end)
end

-- ---------- AUTO (แยก watcher อิสระ เหมือน s789 v11.5) ----------
local function readWavePair()
    local cur, total = 0, 0
    pcall(function()
        local t = clean(gameUI().TopUI.Info.Wave.TextLabel.Text)   -- เช่น "15/15"
        local c, tt = t:match("(%d+)%s*/%s*(%d+)")
        cur, total = tonumber(c) or 0, tonumber(tt) or 0
    end)
    return cur, total
end
-- คลิกกลางจอ (เก็บไอเทมที่ลอยตอนจบด่าน — ต้องคลิกก่อน UI Victory ถึงโผล่)
local function clickCenter()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local x, y = math.floor(cam.ViewportSize.X / 2), math.floor(cam.ViewportSize.Y / 2)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0); task.wait(0.05)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

-- watcher 1: จบด่าน — เวฟสุดท้าย → คลิกเก็บไอเทมที่ลอย → ActOver โผล่ → รางวัล+Replay
task.spawn(function()
    local was = false
    while true do
        if autoOn then
            local vis = actOverVisible()
            if vis and not was then
                task.wait(0.4); dismissReward(); task.wait(0.3); clickReplay()
                statusCb("🔁 Victory → กดรางวัล+Replay")
            elseif not vis and not playing then
                local cur, total = readWavePair()
                if total > 0 and cur >= total then clickCenter() end   -- ด่านจบ → เก็บไอเทมลอย
            end
            was = vis
        else
            was = false
        end
        task.wait(0.7)
    end
end)

-- watcher 2: เวฟใหม่ (Replay เริ่มด่านใหม่) → เล่น macro
task.spawn(function()
    local lastW = 0
    while true do
        if autoOn and not playing and #macro.events > 0 then
            local w = readWave()
            if w > 0 and w <= 2 and lastW > 2 and not actOverVisible() then
                statusCb("🔁 เวฟใหม่ → PLAY")
                task.wait(0.8); play()
            end
            lastW = w
        end
        task.wait(0.5)
    end
end)

-- ---------- save / load ----------
local function saveClip()
    macro.stage = readStage(); macro.version = MACRO_VERSION
    local m, t = resolveUpgradeIdx()
    local okj, s = pcall(function() return HttpService:JSONEncode(macro) end)
    if not okj then statusCb("encode ไม่สำเร็จ"); return end
    pcall(setClip, s)
    saveFile()
    statusCb(("📋 คัดลอก+เซฟ | %d เหตุการณ์ | อัพเกรด %d/%d | box=%s"):format(#macro.events, m, t, tostring(macro.container)))
    print("[AO MACRO] " .. s)
end
local function loadText(text)
    local ok, m = pcall(function() return HttpService:JSONDecode(text) end)
    if ok and type(m) == "table" and type(m.events) == "table" then
        macro = m; statusCb("โหลด: " .. tostring(m.stage or "?") .. " (" .. #m.events .. ")")
    else statusCb("❌ macro ไม่ถูกต้อง") end
end

-- ---------- บันทึก/โหลด ไฟล์ (ต่อด่าน) ----------
local function safeName(s) return (tostring(s):gsub("[^%w]+", "_")):sub(1, 60) end
local function macroPath(stage) return MACRO_DIR .. "/" .. safeName(stage) .. ".json" end
local function saveFile()
    if not hasFS then return false end
    local st = (macro.stage ~= "" and macro.stage) or readStage()
    macro.stage = st
    local okj, s = pcall(function() return HttpService:JSONEncode(macro) end)
    if not okj then return false end
    pcall(function() if makefolder and not (isfolder and isfolder(MACRO_DIR)) then makefolder(MACRO_DIR) end end)
    return (pcall(function() writefile(macroPath(st), s) end))
end
local function loadFileForStage(stage)
    if not hasFS or stage == "Unknown" then return false end
    local p = macroPath(stage)
    if not (isfile and isfile(p)) then return false end
    local okr, s = pcall(function() return readfile(p) end)
    if not okr then return false end
    local okd, m = pcall(function() return HttpService:JSONDecode(s) end)
    if okd and type(m) == "table" and type(m.events) == "table" then macro = m; return true end
    return false
end
-- เข้าด่านไหน → โหลด macro ของด่านนั้นจากไฟล์เอง
task.spawn(function()
    task.wait(2)
    local last = ""
    while true do
        local st = readStage()
        if hasFS and st ~= "Unknown" and st ~= last and not recording and not playing then
            if macro.stage ~= st or #macro.events == 0 then
                if loadFileForStage(st) then statusCb("📂 โหลดไฟล์ด่าน: " .. st .. " (" .. #macro.events .. " เหตุการณ์)") end
            end
        end
        last = st
        task.wait(2)
    end
end)

-- ---------- UI ----------
local gui = Instance.new("ScreenGui"); gui.Name = "AOMacroUI"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = (gethui and gethui()) or player:WaitForChild("PlayerGui")
local main = Instance.new("Frame"); main.Size = UDim2.fromOffset(300, 268)
main.Position = UDim2.new(0.5, -150, 0.32, 0); main.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel"); title.Size = UDim2.new(1, -16, 0, 26); title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left; title.TextColor3 = Color3.fromRGB(0, 229, 255)
title.Text = "AO PLACE MACRO v" .. MACRO_VERSION; title.Parent = main
local status = Instance.new("TextLabel"); status.Size = UDim2.new(1, -16, 0, 34); status.Position = UDim2.fromOffset(8, 32)
status.BackgroundColor3 = Color3.fromRGB(10, 12, 17); status.Font = Enum.Font.Gotham; status.TextSize = 11
status.TextWrapped = true; status.TextColor3 = Color3.fromRGB(200, 230, 240)
status.Text = hookedOK and "พร้อม — REC แล้วเล่นเอง (วาง+อัพเกรด)" or "⚠️ executor ไม่มี hookmetamethod"
status.Parent = main; Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)
statusCb = function(t) status.Text = t end
local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton"); b.Size = UDim2.fromOffset(w, 30); b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Text = text; b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6); return b
end
local recBtn = mkBtn("● REC", 8, 74, 90, Color3.fromRGB(174, 60, 72))
local playBtn = mkBtn("▶ PLAY", 104, 74, 90, Color3.fromRGB(68, 151, 101))
local clearBtn = mkBtn("🗑 CLEAR", 200, 74, 92, Color3.fromRGB(70, 74, 86))
local copyBtn = mkBtn("📋 COPY", 8, 110, 90, Color3.fromRGB(46, 90, 120))
local autoBtn = mkBtn("🔁 AUTO: OFF", 104, 110, 188, Color3.fromRGB(70, 74, 86))
local loadBtn = mkBtn("📥 LOAD (วางในช่องล่าง)", 8, 146, 284, Color3.fromRGB(46, 90, 120))
local box = Instance.new("TextBox"); box.Size = UDim2.new(1, -16, 0, 66); box.Position = UDim2.fromOffset(8, 184)
box.BackgroundColor3 = Color3.fromRGB(10, 12, 17); box.Font = Enum.Font.Code; box.TextSize = 10
box.TextColor3 = Color3.fromRGB(180, 210, 220); box.TextWrapped = true
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.ClearTextOnFocus = false; box.PlaceholderText = "วาง macro (JSON) แล้วกด LOAD"; box.Text = ""; box.Parent = main
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

recBtn.MouseButton1Click:Connect(function()
    if not hookedOK then statusCb("อัดไม่ได้: ไม่รองรับ hook"); return end
    recording = not recording
    if recording then
        macro.events = {}; resetRecTrack()
        for _, tr in pairs(recTrack) do mapNew(tr) end   -- นับของที่มีอยู่ก่อน = ข้าม
        recStart = os.clock(); recBtn.Text = "■ STOP"; recBtn.BackgroundColor3 = Color3.fromRGB(220, 90, 90)
        statusCb("🔴 อัด — เล่นได้เลย (ด่าน: " .. readStage() .. ")")
    else
        recBtn.Text = "● REC"; recBtn.BackgroundColor3 = Color3.fromRGB(174, 60, 72)
        macro.stage = readStage()
        local m, t = resolveUpgradeIdx()
        local saved = saveFile()
        statusCb(("หยุดอัด — %d เหตุการณ์ | อัพเกรด %d/%d | box=%s | ไฟล์:%s"):format(
            #macro.events, m, t, tostring(macro.container), saved and "เซฟแล้ว" or (hasFS and "เซฟไม่ได้" or "ไม่รองรับ")))
    end
end)
playBtn.MouseButton1Click:Connect(function()
    if playing then stopPlay(); playBtn.Text = "▶ PLAY"; statusCb("หยุดเล่น") else playBtn.Text = "■ STOP"; play() end
end)
clearBtn.MouseButton1Click:Connect(function() macro.events = {}; statusCb("ล้าง macro แล้ว") end)
copyBtn.MouseButton1Click:Connect(saveClip)
loadBtn.MouseButton1Click:Connect(function() loadText(box.Text) end)
autoBtn.MouseButton1Click:Connect(function()
    autoOn = not autoOn
    autoBtn.Text = autoOn and "🔁 AUTO: ON" or "🔁 AUTO: OFF"
    autoBtn.BackgroundColor3 = autoOn and Color3.fromRGB(68, 151, 101) or Color3.fromRGB(70, 74, 86)
    -- เปิด AUTO → เล่นรอบแรกเลย (รอบถัดไป watcher 2 จับเวฟใหม่เอง)
    if autoOn and not playing and #macro.events > 0 and not actOverVisible() then play() end
end)
task.spawn(function()
    while gui.Parent do if not playing and playBtn.Text == "■ STOP" and not autoOn then playBtn.Text = "▶ PLAY" end; task.wait(0.5) end
end)
print("[AO MACRO v" .. MACRO_VERSION .. "] loaded | hook=" .. tostring(hookedOK) .. " | remote=" .. tostring(placeRemote ~= nil))
