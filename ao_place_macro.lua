-- ============================================================
-- ANIME ORIGINS — PLACEMENT MACRO (record / replay) v0.2  แยกจากสคริปต์หลัก
-- อัด: วางตัว (TowerN+ตำแหน่ง+hill) + อัพเกรด (UpgradeTower ตามลำดับที่กด) + เวลาจริง
-- เล่นซ้ำ: วาง+อัพเกรดตามลำดับ/เวลาเดิม (รอเงินเอง) — จบด่าน auto-PLAY ได้
-- โหลด: loadstring(game:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/ao_place_macro.lua"))()
-- ============================================================
local MACRO_VERSION = "0.2"

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- remote วางตัว/อัพเกรด (เส้นเดียวกับสคริปต์หลัก)
local placeRemote = RS:FindFirstChild("LobbyRemotes")
placeRemote = placeRemote and placeRemote:FindFirstChild("TowerHandlerRemotes")
placeRemote = placeRemote and placeRemote:FindFirstChild("TowerHandlerFunction")

local setClip = setclipboard or toclipboard or (syn and syn.setclipboard) or set_clipboard or function() end

-- ---------- helpers ----------
local function clean(s) return (tostring(s or ""):gsub("<[^>]->", "")) end
local function readWave()
    local w = 0
    pcall(function()
        local g = player.PlayerGui:FindFirstChild("GameUI")
        w = tonumber(tostring(clean(g.TopUI.Info.Wave.TextLabel.Text)):match("^(%d+)")) or 0
    end)
    return w
end
local function readStage()
    local s = "Unknown"
    pcall(function()
        local ai = player.PlayerGui.GameUI.ManagementFrame.SideButtons.ActInfo
        s = string.format("%s - %s (%s)", clean(ai.World.Text), clean(ai.Act.Text), clean(ai.Difficulty.Text))
    end)
    return s
end
-- key ของยูนิตที่วางแล้ว (workspace.Towers) — UUID ที่ UpgradeTower ใช้
local function towerKey(c)
    if c.Name and #c.Name >= 8 and c.Name:find("%-") then return c.Name end
    for _, a in ipairs({ "Guid", "GUID", "UUID", "Uuid", "Id", "TowerId" }) do
        local v = c:GetAttribute(a)
        if v ~= nil then return tostring(v) end
    end
    return c.Name
end
local function towerFolder() return workspace:FindFirstChild("Towers") end
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
    if not placeRemote then return false end
    local ok, res = pcall(function() return placeRemote:InvokeServer("UpgradeTower", uuid) end)
    return ok and res == true, res
end

-- ---------- state ----------
local macro = { version = MACRO_VERSION, stage = "", events = {} }
local recording, playing, autoPlay = false, false, false
local recStart = 0
local recOrder, recIndexByUUID = {}, {}   -- ลำดับ UUID ที่โผล่ใน Towers ตอนอัด
local statusCb = function() end

-- ---------- hook remote (อัดตอนเล่นเอง) ----------
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
                    macro.events[#macro.events + 1] = {
                        k = "place", t = math.floor((os.clock() - recStart) * 100) / 100,
                        w = readWave(), slot = slot,
                        pos = { x = pos.X, y = pos.Y, z = pos.Z }, hill = a[7] == true,
                    }
                    statusCb(("🔴 อัด: วาง T%d (%d เหตุการณ์)"):format(slot, #macro.events))
                end
            elseif action == "UpgradeTower" and res == true then
                local uuid = tostring(a[2] or "")
                macro.events[#macro.events + 1] = {
                    k = "up", t = math.floor((os.clock() - recStart) * 100) / 100,
                    action = "UpgradeTower", uuid = uuid,
                }
                statusCb(("🔴 อัด: อัพเกรด (%d เหตุการณ์)"):format(#macro.events))
            end
        end
        return res
    end)
    hookedOK = true
end)

-- ---------- poller: จับลำดับ UUID ที่โผล่ใน Towers ----------
local function mapNewTowers(order, indexByUUID)
    local f = towerFolder()
    if not f then return end
    for _, c in ipairs(f:GetChildren()) do
        local key = towerKey(c)
        if key and not indexByUUID[key] then
            order[#order + 1] = key
            indexByUUID[key] = #order
        end
    end
end
-- record poller
task.spawn(function()
    while true do
        if recording then mapNewTowers(recOrder, recIndexByUUID) end
        task.wait(0.1)
    end
end)

-- ---------- play ----------
local function stopPlay() playing = false end
local function play()
    if playing then return end
    if #macro.events == 0 then statusCb("ไม่มี macro ให้เล่น"); return end
    playing = true
    task.spawn(function()
        local order, indexByUUID = {}, {}
        -- นับของที่มีอยู่แล้วก่อนเริ่ม (กัน map เพี้ยน) — เริ่มนับจากศูนย์เฉพาะที่วางใหม่
        -- poller ระหว่างเล่น
        local pollAlive = true
        task.spawn(function()
            while pollAlive and playing do mapNewTowers(order, indexByUUID); task.wait(0.08) end
        end)
        local playStart = os.clock()
        for i, e in ipairs(macro.events) do
            if not playing then break end
            -- รอให้ถึงเวลาที่อัดไว้ (จังหวะเดียวกับตอนเล่น)
            while playing and os.clock() - playStart < (e.t or 0) do task.wait(0.05) end
            if e.k == "place" then
                local pos = Vector3.new(e.pos.x, e.pos.y, e.pos.z)
                local placed, wrong = false, 0
                while playing and not placed and wrong < 6 do
                    local ok, res = placeTower(e.slot, pos, e.hill)
                    if ok then placed = true
                    elseif res == -1 then task.wait(0.5)      -- เงินไม่พอ → รอ
                    else wrong = wrong + 1; task.wait(0.15) end
                end
                statusCb(("▶️ %d/%d วาง T%d %s"):format(i, #macro.events, e.slot, placed and "✓" or "ข้าม"))
            elseif e.k == "up" and e.idx then
                -- รอให้ยูนิตลำดับที่ idx โผล่ (วางไปแล้ว) แล้วอัพเกรด
                local wt = os.clock()
                while playing and not order[e.idx] and os.clock() - wt < 4 do task.wait(0.1) end
                local uuid = order[e.idx]
                if uuid then
                    local done, tries = false, 0
                    while playing and not done and tries < 8 do
                        tries = tries + 1
                        local ok = upgradeTower(uuid)
                        if ok then done = true else task.wait(0.4) end
                    end
                    statusCb(("▶️ %d/%d อัพเกรด #%d %s"):format(i, #macro.events, e.idx, done and "✓" or "ข้าม"))
                else
                    statusCb(("▶️ %d/%d อัพเกรด #%d (ไม่พบยูนิต)"):format(i, #macro.events, e.idx))
                end
            end
        end
        pollAlive = false
        playing = false
        statusCb("▶️ เล่นจบ (" .. #macro.events .. " เหตุการณ์)")
    end)
end

-- ---------- save / load ----------
local function resolveUpgradeIdx()
    local mapped, unmapped = 0, 0
    for _, e in ipairs(macro.events) do
        if e.k == "up" and e.uuid then
            e.idx = recIndexByUUID[e.uuid]
            e.uuid = nil
            if e.idx then mapped = mapped + 1 else unmapped = unmapped + 1 end
        end
    end
    return mapped, unmapped
end
local function saveClip()
    macro.stage = readStage()
    macro.version = MACRO_VERSION
    local m, u = resolveUpgradeIdx()
    local okj, s = pcall(function() return HttpService:JSONEncode(macro) end)
    if not okj then statusCb("encode ไม่สำเร็จ"); return end
    pcall(setClip, s)
    statusCb(("📋 คัดลอกแล้ว | %d เหตุการณ์ | อัพเกรด map %d/%d"):format(#macro.events, m, m + u))
    print("[AO MACRO] " .. s)
end
local function loadText(text)
    local ok, m = pcall(function() return HttpService:JSONDecode(text) end)
    if ok and type(m) == "table" and type(m.events) == "table" then
        macro = m
        statusCb("โหลด: " .. tostring(m.stage or "?") .. " (" .. #m.events .. " เหตุการณ์)")
    else
        statusCb("❌ macro ที่วางไม่ถูกต้อง")
    end
end

-- ---------- auto-play เมื่อจบด่านแล้วเริ่มเวฟใหม่ ----------
task.spawn(function()
    local lastWave = 0
    while true do
        local w = readWave()
        if autoPlay and not playing and #macro.events > 0 and w > 0 and w <= 2 and lastWave > 2 then
            statusCb("🔁 เวฟใหม่ → auto PLAY")
            task.wait(1.0)   -- ให้สนามพร้อม
            play()
        end
        lastWave = w
        task.wait(0.5)
    end
end)

-- ---------- UI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "AOMacroUI"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = (gethui and gethui()) or player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(300, 268)
main.Position = UDim2.new(0.5, -150, 0.32, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
main.BorderSizePixel = 0; main.Active = true; main.Draggable = true; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 26); title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left; title.TextColor3 = Color3.fromRGB(0, 229, 255)
title.Text = "AO PLACE MACRO v" .. MACRO_VERSION; title.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 34); status.Position = UDim2.fromOffset(8, 32)
status.BackgroundColor3 = Color3.fromRGB(10, 12, 17); status.Font = Enum.Font.Gotham; status.TextSize = 11
status.TextWrapped = true; status.TextColor3 = Color3.fromRGB(200, 230, 240)
status.Text = hookedOK and "พร้อม — กด REC แล้วเล่นเอง (วาง+อัพเกรด)" or "⚠️ executor ไม่มี hookmetamethod (อัดไม่ได้)"
status.Parent = main
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)
statusCb = function(t) status.Text = t end

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 30); b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Text = text; b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local recBtn = mkBtn("● REC", 8, 74, 90, Color3.fromRGB(174, 60, 72))
local playBtn = mkBtn("▶ PLAY", 104, 74, 90, Color3.fromRGB(68, 151, 101))
local clearBtn = mkBtn("🗑 CLEAR", 200, 74, 92, Color3.fromRGB(70, 74, 86))
local copyBtn = mkBtn("📋 COPY", 8, 110, 90, Color3.fromRGB(46, 90, 120))
local autoBtn = mkBtn("🔁 AUTO: OFF", 104, 110, 188, Color3.fromRGB(70, 74, 86))
local loadBtn = mkBtn("📥 LOAD (วางในช่องล่าง)", 8, 146, 284, Color3.fromRGB(46, 90, 120))

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -16, 0, 66); box.Position = UDim2.fromOffset(8, 184)
box.BackgroundColor3 = Color3.fromRGB(10, 12, 17); box.Font = Enum.Font.Code; box.TextSize = 10
box.TextColor3 = Color3.fromRGB(180, 210, 220); box.TextWrapped = true
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.ClearTextOnFocus = false; box.PlaceholderText = "วาง macro (JSON) ที่นี่ แล้วกด LOAD"; box.Text = ""
box.Parent = main
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

recBtn.MouseButton1Click:Connect(function()
    if not hookedOK then statusCb("อัดไม่ได้: executor ไม่รองรับ hook"); return end
    recording = not recording
    if recording then
        macro.events = {}
        recOrder, recIndexByUUID = {}, {}
        mapNewTowers(recOrder, recIndexByUUID)   -- นับของที่มีอยู่ก่อน (ไม่นับเป็นของใหม่)
        recStart = os.clock()
        recBtn.Text = "■ STOP"; recBtn.BackgroundColor3 = Color3.fromRGB(220, 90, 90)
        statusCb("🔴 กำลังอัด — เล่นได้เลย (ด่าน: " .. readStage() .. ")")
    else
        recBtn.Text = "● REC"; recBtn.BackgroundColor3 = Color3.fromRGB(174, 60, 72)
        macro.stage = readStage()
        local m, u = resolveUpgradeIdx()
        statusCb(("หยุดอัด — %d เหตุการณ์ | อัพเกรด map %d/%d"):format(#macro.events, m, m + u))
    end
end)
playBtn.MouseButton1Click:Connect(function()
    if playing then stopPlay(); playBtn.Text = "▶ PLAY"; statusCb("หยุดเล่น")
    else playBtn.Text = "■ STOP"; play() end
end)
clearBtn.MouseButton1Click:Connect(function() macro.events = {}; statusCb("ล้าง macro แล้ว") end)
copyBtn.MouseButton1Click:Connect(saveClip)
loadBtn.MouseButton1Click:Connect(function() loadText(box.Text) end)
autoBtn.MouseButton1Click:Connect(function()
    autoPlay = not autoPlay
    autoBtn.Text = autoPlay and "🔁 AUTO: ON" or "🔁 AUTO: OFF"
    autoBtn.BackgroundColor3 = autoPlay and Color3.fromRGB(68, 151, 101) or Color3.fromRGB(70, 74, 86)
end)

task.spawn(function()
    while gui.Parent do
        if not playing and playBtn.Text == "■ STOP" then playBtn.Text = "▶ PLAY" end
        task.wait(0.5)
    end
end)

print("[AO MACRO v" .. MACRO_VERSION .. "] loaded | hook=" .. tostring(hookedOK)
    .. " | remote=" .. tostring(placeRemote ~= nil))
