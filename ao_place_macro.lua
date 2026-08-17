-- ============================================================
-- ANIME ORIGINS — PLACEMENT MACRO (record / replay)  แยกจากสคริปต์หลัก
-- อัดว่าเล่นด่านไหน วางตัวไหน (TowerN) จุดไหน (ตำแหน่ง+hill) เวฟ+เวลา
-- แล้วเล่นซ้ำ / คัดลอก(clipboard) / วางกลับมาเล่น
-- โหลด: loadstring(game:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/ao_place_macro.lua"))()
-- ============================================================
local MACRO_VERSION = "0.1"

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- remote วางตัว (เส้นเดียวกับสคริปต์หลัก)
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
        local t = g and g.TopUI.Info.Wave.TextLabel.Text
        w = tonumber(tostring(clean(t)):match("^(%d+)")) or 0
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
local function placeTower(slot, pos, hill)
    if not placeRemote then return false, "no remote" end
    local ok, res = pcall(function()
        return placeRemote:InvokeServer("PlaceTower", "Tower" .. tostring(slot), pos, Vector3.new(0, 1, 0), 0, nil, hill)
    end)
    if not ok then return false, res end
    if typeof(res) == "table" then return true, res end
    return false, res   -- res == -1 = เงินไม่พอ
end

-- ---------- state ----------
local macro = { version = MACRO_VERSION, stage = "", placements = {} }
local recording = false
local playing = false
local recStart = 0
local statusCb = function() end

local function recordPlacement(a)
    local slot = tonumber(tostring(a[2] or ""):match("Tower(%d+)"))
    local pos = a[3]
    if not slot or typeof(pos) ~= "Vector3" then return end
    macro.placements[#macro.placements + 1] = {
        w = readWave(),
        t = math.floor((os.clock() - recStart) * 100) / 100,
        slot = slot,
        pos = { x = pos.X, y = pos.Y, z = pos.Z },
        hill = a[7] == true,
    }
    statusCb(("🔴 อัด %d จุด (T%d @ เวฟ%d)"):format(#macro.placements, slot, macro.placements[#macro.placements].w))
end

-- ---------- hook remote (อัดตอนวางเอง) ----------
local hookedOK = false
pcall(function()
    if not (hookmetamethod and getnamecallmethod) then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local a
        if recording and self == placeRemote and method == "InvokeServer" then
            a = { ... }
        end
        local res = old(self, ...)
        if a and a[1] == "PlaceTower" and typeof(res) == "table" then
            pcall(recordPlacement, a)
        end
        return res
    end)
    hookedOK = true
end)

-- ---------- play ----------
local function stopPlay() playing = false end
local function play(honorTiming)
    if playing then return end
    if #macro.placements == 0 then statusCb("ไม่มี macro ให้เล่น"); return end
    playing = true
    task.spawn(function()
        local playStart = os.clock()
        for i, p in ipairs(macro.placements) do
            if not playing then break end
            -- รอให้ถึงเวลาที่อัดไว้ (จังหวะเดียวกับตอนเล่น) — ถ้าปิด honorTiming ก็วางรัวๆ
            if honorTiming then
                while playing and os.clock() - playStart < (p.t or 0) do task.wait(0.05) end
            end
            local pos = Vector3.new(p.pos.x, p.pos.y, p.pos.z)
            local placed, wrong = false, 0
            while playing and not placed and wrong < 6 do
                local ok, res = placeTower(p.slot, pos, p.hill)
                if ok then
                    placed = true
                elseif res == -1 then
                    task.wait(0.5)          -- เงินไม่พอ → รอเงินแล้วลองใหม่ (ไม่นับ wrong)
                else
                    wrong = wrong + 1        -- จุดผิด/เต็ม → ลองสั้นๆ แล้วข้าม
                    task.wait(0.15)
                end
            end
            statusCb(("▶️ เล่น %d/%d (T%d %s)"):format(i, #macro.placements, p.slot, placed and "✓" or "ข้าม"))
        end
        playing = false
        statusCb("▶️ เล่น macro จบ (" .. #macro.placements .. " จุด)")
    end)
end

-- ---------- save / load ----------
local function saveClip()
    macro.stage = readStage()
    macro.version = MACRO_VERSION
    local okj, s = pcall(function() return HttpService:JSONEncode(macro) end)
    if not okj then statusCb("encode ไม่สำเร็จ"); return end
    pcall(setClip, s)
    statusCb("📋 คัดลอก macro แล้ว (" .. #macro.placements .. " จุด) — " .. macro.stage)
    print("[AO MACRO] " .. s)
end
local function loadText(text)
    local ok, m = pcall(function() return HttpService:JSONDecode(text) end)
    if ok and type(m) == "table" and type(m.placements) == "table" then
        macro = m
        macro.placements = m.placements
        statusCb("โหลด: " .. tostring(m.stage or "?") .. " (" .. #m.placements .. " จุด)")
    else
        statusCb("❌ macro ที่วางไม่ถูกต้อง")
    end
end

-- ---------- UI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "AOMacroUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = (gethui and gethui()) or player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(300, 232)
main.Position = UDim2.new(0.5, -150, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(0, 229, 255)
title.Text = "AO PLACE MACRO v" .. MACRO_VERSION
title.Parent = main

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 30)
status.Position = UDim2.fromOffset(8, 32)
status.BackgroundColor3 = Color3.fromRGB(10, 12, 17)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(200, 230, 240)
status.Text = hookedOK and "พร้อม — กด REC แล้ววางเอง" or "⚠️ executor ไม่มี hookmetamethod (อัดไม่ได้)"
status.Parent = main
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)
statusCb = function(t) status.Text = t end

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 30)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local recBtn = mkBtn("● REC", 8, 70, 90, Color3.fromRGB(174, 60, 72))
local playBtn = mkBtn("▶ PLAY", 104, 70, 90, Color3.fromRGB(68, 151, 101))
local clearBtn = mkBtn("🗑 CLEAR", 200, 70, 92, Color3.fromRGB(70, 74, 86))

local copyBtn = mkBtn("📋 COPY", 8, 106, 138, Color3.fromRGB(46, 90, 120))
local loadBtn = mkBtn("📥 LOAD (วางในช่อง)", 152, 106, 140, Color3.fromRGB(46, 90, 120))

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -16, 0, 66)
box.Position = UDim2.fromOffset(8, 144)
box.BackgroundColor3 = Color3.fromRGB(10, 12, 17)
box.Font = Enum.Font.Code
box.TextSize = 10
box.TextColor3 = Color3.fromRGB(180, 210, 220)
box.TextWrapped = true
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.ClearTextOnFocus = false
box.PlaceholderText = "วาง macro (JSON) ที่นี่ แล้วกด LOAD"
box.Text = ""
box.Parent = main
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

recBtn.MouseButton1Click:Connect(function()
    if not hookedOK then statusCb("อัดไม่ได้: executor ไม่รองรับ hook"); return end
    recording = not recording
    if recording then
        macro.placements = {}
        recStart = os.clock()
        recBtn.Text = "■ STOP"
        recBtn.BackgroundColor3 = Color3.fromRGB(220, 90, 90)
        statusCb("🔴 กำลังอัด — วางตัวได้เลย (ด่าน: " .. readStage() .. ")")
    else
        recBtn.Text = "● REC"
        recBtn.BackgroundColor3 = Color3.fromRGB(174, 60, 72)
        macro.stage = readStage()
        statusCb("หยุดอัด — ได้ " .. #macro.placements .. " จุด | ด่าน " .. macro.stage)
    end
end)
playBtn.MouseButton1Click:Connect(function()
    if playing then stopPlay(); playBtn.Text = "▶ PLAY"; statusCb("หยุดเล่น")
    else playBtn.Text = "■ STOP"; play(true); end
end)
clearBtn.MouseButton1Click:Connect(function()
    macro.placements = {}
    statusCb("ล้าง macro แล้ว")
end)
copyBtn.MouseButton1Click:Connect(saveClip)
loadBtn.MouseButton1Click:Connect(function() loadText(box.Text) end)

task.spawn(function()
    while gui.Parent do
        if not playing and playBtn.Text == "■ STOP" then playBtn.Text = "▶ PLAY" end
        task.wait(0.5)
    end
end)

print("[AO MACRO v" .. MACRO_VERSION .. "] loaded | hook=" .. tostring(hookedOK)
    .. " | remote=" .. tostring(placeRemote ~= nil))
