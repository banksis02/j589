-- ============================================================
-- ANIME ORIGINS TEST UI/HEADLESS v2.2
-- Standalone test only - not part of s789
-- ============================================================

local AO_TEST_VERSION = "2.6"
local AO_LOBBY_PLACE_ID = 129932912185311
local AO_HEADLESS = _G.AO_HEADLESS == true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local oldGui = (gethui and gethui() or CoreGui):FindFirstChild("AnimeOriginsTestUI")
if oldGui then
    oldGui:Destroy()
end

local MODES = {"Story", "Legend"}

local MAPS = {
    Story = {
        {Label = "West City", Value = "WestCity"},
        {Label = "Hidden Sand", Value = "SandVillage"},
        {Label = "Katakura Town", Value = "KatakuraTown"},
        {Label = "Entertainment District", Value = "EntertainmentDistrict_Story"},
    },
    Legend = {
        {Label = "West City", Value = "WestCity"},
        {Label = "Hidden Sand", Value = "SandVillage"},
        {Label = "Katakura Town", Value = "KatakuraTown"},
    },
}

local ACTS = {
    Story = {
        {Label = "Act 1", Value = "1"},
        {Label = "Act 2", Value = "2"},
        {Label = "Act 3", Value = "3"},
        {Label = "Act 4", Value = "4"},
        {Label = "Act 5", Value = "5"},
        {Label = "Act 6", Value = "6"},
        {Label = "Infinite", Value = "Infinite"},
    },
    Legend = {
        {Label = "Act 1", Value = "Legend1"},
        {Label = "Act 2", Value = "Legend2"},
        {Label = "Act 3", Value = "Legend3"},
    },
}

local selectedMode = "Story"
local selectedMap = MAPS.Story[1]
local selectedAct = AO_HEADLESS and ACTS.Story[#ACTS.Story] or ACTS.Story[1]

local gui = Instance.new("ScreenGui")
gui.Name = "AnimeOriginsTestUI"
gui.ResetOnSpawn = false
gui.Enabled = not AO_HEADLESS
-- Global ทำให้ popup ของ dropdown อยู่เหนือ dropdown แถวถัดไปจริง ๆ
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = gethui and gethui() or CoreGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(430, 380)
main.Position = UDim2.new(0.5, -215, 0.5, -190)
main.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(71, 91, 145)
stroke.Thickness = 1.5
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 48)
title.Position = UDim2.fromOffset(18, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Anime Origins Test v" .. AO_TEST_VERSION
title.TextColor3 = Color3.fromRGB(238, 241, 255)
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.Position = UDim2.new(1, -44, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(166, 53, 67)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 14
closeButton.Parent = main
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)
closeButton.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -36, 0, 38)
status.Position = UDim2.fromOffset(18, 324)
status.BackgroundColor3 = Color3.fromRGB(29, 32, 42)
status.BorderSizePixel = 0
status.Font = Enum.Font.Gotham
status.Text = game.PlaceId == AO_LOBBY_PLACE_ID and "พร้อมใช้งานใน Lobby" or "ต้องใช้งานใน Lobby"
status.TextColor3 = game.PlaceId == AO_LOBBY_PLACE_ID and Color3.fromRGB(122, 224, 150) or Color3.fromRGB(255, 121, 121)
status.TextSize = 13
status.TextWrapped = true
status.Parent = main
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 8)

local function makeLabel(text, y)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromOffset(118, 40)
    label.Position = UDim2.fromOffset(18, y)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.Text = text
    label.TextColor3 = Color3.fromRGB(191, 198, 218)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = main
end

local openDropdown

local function createDropdown(y, initialText)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromOffset(270, 40)
    holder.Position = UDim2.fromOffset(140, y)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 5
    holder.Parent = main

    local button = Instance.new("TextButton")
    button.Name = "Selected"
    button.Size = UDim2.new(1, 0, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(36, 40, 53)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.Text = initialText .. "   v"
    button.TextColor3 = Color3.fromRGB(238, 241, 255)
    button.TextSize = 14
    button.ZIndex = 6
    button.Parent = holder
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    local list = Instance.new("Frame")
    list.Name = "List"
    list.Size = UDim2.new(1, 0, 0, 0)
    list.Position = UDim2.fromOffset(0, 44)
    list.BackgroundColor3 = Color3.fromRGB(30, 33, 44)
    list.BorderSizePixel = 0
    list.Visible = false
    list.ClipsDescendants = true
    list.ZIndex = 100
    list.Parent = holder
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = Color3.fromRGB(79, 96, 151)
    listStroke.Thickness = 1.5
    listStroke.ZIndex = 101
    listStroke.Parent = list

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.Parent = list

    local dropdown = {Holder = holder, Button = button, List = list, Items = {}}

    function dropdown:Close()
        self.List.Visible = false
        self.List.Size = UDim2.new(1, 0, 0, 0)
        self.Holder.ZIndex = 5
        self.Button.ZIndex = 6
        if openDropdown == self then
            openDropdown = nil
        end
    end

    function dropdown:SetText(text)
        self.Button.Text = tostring(text) .. "   v"
    end

    function dropdown:SetItems(items, callback)
        for _, itemButton in ipairs(self.Items) do
            itemButton:Destroy()
        end
        table.clear(self.Items)

        for _, item in ipairs(items) do
            local itemData = type(item) == "table" and item or {Label = tostring(item), Value = item}
            local itemButton = Instance.new("TextButton")
            itemButton.Size = UDim2.new(1, -8, 0, 32)
            itemButton.BackgroundColor3 = Color3.fromRGB(42, 47, 62)
            itemButton.BorderSizePixel = 0
            itemButton.Font = Enum.Font.Gotham
            itemButton.Text = itemData.Label
            itemButton.TextColor3 = Color3.fromRGB(232, 235, 248)
            itemButton.TextSize = 13
            itemButton.ZIndex = 102
            itemButton.Parent = self.List
            Instance.new("UICorner", itemButton).CornerRadius = UDim.new(0, 6)
            table.insert(self.Items, itemButton)

            itemButton.MouseButton1Click:Connect(function()
                self:SetText(itemData.Label)
                self:Close()
                callback(itemData)
            end)
        end
    end

    button.MouseButton1Click:Connect(function()
        if openDropdown and openDropdown ~= dropdown then
            openDropdown:Close()
        end
        local opening = not list.Visible
        if opening then
            local count = #dropdown.Items
            holder.ZIndex = 99
            button.ZIndex = 103
            list.Size = UDim2.new(1, 0, 0, count * 35 + 6)
            list.Visible = true
            openDropdown = dropdown
        else
            dropdown:Close()
        end
    end)

    return dropdown
end

makeLabel("Mode", 64)
makeLabel("Map", 116)
makeLabel("Act", 168)

local modeDropdown = createDropdown(64, "Story")
local mapDropdown = createDropdown(116, selectedMap.Label)
local actDropdown = createDropdown(168, selectedAct.Label)

local function refreshForMode()
    selectedMap = MAPS[selectedMode][1]
    selectedAct = ACTS[selectedMode][1]

    mapDropdown:SetText(selectedMap.Label)
    actDropdown:SetText(selectedAct.Label)

    mapDropdown:SetItems(MAPS[selectedMode], function(item)
        selectedMap = item
    end)

    actDropdown:SetItems(ACTS[selectedMode], function(item)
        selectedAct = item
    end)
end

modeDropdown:SetItems(MODES, function(item)
    selectedMode = item.Value
    refreshForMode()
end)

local enterButton = Instance.new("TextButton")
enterButton.Size = UDim2.new(1, -36, 0, 52)
enterButton.Position = UDim2.fromOffset(18, 248)
enterButton.BackgroundColor3 = Color3.fromRGB(76, 104, 219)
enterButton.BorderSizePixel = 0
enterButton.Font = Enum.Font.GothamBold
enterButton.Text = "SELECT STAGE"
enterButton.TextColor3 = Color3.new(1, 1, 1)
enterButton.TextSize = 16
enterButton.Parent = main
Instance.new("UICorner", enterButton).CornerRadius = UDim.new(0, 10)

local busy = false

-- เก็บจาก Pod 5 ขณะ InProgress: ตำแหน่ง HRP ภายในห้องเทียบกับ DoorUIPart
local POD_ENTRY_OFFSET = CFrame.new(
    0.0225524902, -4.20016479, -6.64593506,
    0.999899983, 1.81122335e-08, -0.0141505329,
    -1.84142745e-08, 1, -2.12148077e-08,
    0.0141505329, 2.14732552e-08, 0.999899983
)

local function guiEnabled(object)
    if not object then
        return false
    elseif object:IsA("LayerCollector") then
        return object.Enabled
    elseif object:IsA("GuiObject") then
        return object.Visible
    end

    return false
end

local function findNearestEmptyStoryDoor(root)
    local mainFolder = workspace:FindFirstChild("MainFolder")
    local lobby = mainFolder and mainFolder:FindFirstChild("Lobby")
    local selectors = lobby and lobby:FindFirstChild("MapSelectors")
    -- Legend อาจมีชุด Pod แยกจาก Story; ถ้าเกมใช้ Pod ร่วมกันให้ fallback กลับ Story
    local story = selectors and (selectors:FindFirstChild(selectedMode) or selectors:FindFirstChild("Story"))

    if not story then
        return nil, "ไม่พบ MapSelectors." .. tostring(selectedMode) .. "/Story"
    end

    local nearestDoor
    local nearestDistance = math.huge

    for _, pod in ipairs(story:GetChildren()) do
        if pod.Name == "Pod" then
            local door = pod:FindFirstChild("DoorUIPart", true)
            local empty = door and door:FindFirstChild("Empty")

            if door and door:IsA("BasePart") and guiEnabled(empty) then
                local distance = (door.Position - root.Position).Magnitude

                if distance < nearestDistance then
                    nearestDoor = door
                    nearestDistance = distance
                end
            end
        end
    end

    if not nearestDoor then
        return nil, "ไม่พบ Pod ว่าง"
    end

    return nearestDoor, nearestDistance
end

local function teleportThroughNearestDoor()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid then
        return false, "ไม่พบตัวละคร/Humanoid"
    end

    -- StartSelection จะวาร์ปผู้เล่นมาหน้าทางเข้า รอให้ตำแหน่งนิ่งก่อนหา Pod
    task.wait(1.5)

    local door, distanceOrError = findNearestEmptyStoryDoor(root)

    if not door then
        return false, distanceOrError
    end

    local target = door.CFrame * POD_ENTRY_OFFSET
    local front = door.CFrame * CFrame.new(0, -4.20016479, 9)
    local inProgress = door:FindFirstChild("InProgress")

    status.Text = string.format("กำลังไปหน้าประตู Pod (%.1f studs)", distanceOrError)
    status.TextColor3 = Color3.fromRGB(255, 213, 106)

    humanoid:Move(Vector3.zero, false)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- ไปยืนหน้าประตูตามแกน local ของ DoorUIPart ก่อน เพื่อไม่ตัดเข้าด้านข้าง Pod
    root.CFrame = CFrame.lookAt(front.Position, target.Position)
    task.wait(0.35)

    local startedAt = os.clock()
    while os.clock() - startedAt < 12 do
        if guiEnabled(inProgress) then
            return true, "เข้า Pod สำเร็จ (InProgress)"
        end

        if not root.Parent or humanoid.Health <= 0 then
            return false, "ตัวละครหายหรือเสียชีวิต"
        end

        -- เดินจริงจากหน้าประตูเข้าด้านใน เพื่อให้ Trigger รับการชน
        humanoid:MoveTo(target.Position)
        task.wait(0.35)
    end

    return false, "เดินชนประตูแล้ว แต่ Pod ไม่เปลี่ยนเป็น InProgress"
end

local function fireGuiButton(button)
    if not button or not button:IsA("GuiButton") then
        return false, "ไม่พบปุ่ม"
    end

    if type(getconnections) == "function" then
        for _, signal in ipairs({button.Activated, button.MouseButton1Click}) do
            local fired = false
            local ok = pcall(function()
                for _, connection in ipairs(getconnections(signal)) do
                    connection:Fire()
                    fired = true
                end
            end)
            if ok and fired then return true end
        end
    end

    if type(firesignal) == "function" then
        local ok = pcall(firesignal, button.Activated)
        if ok then
            return true
        end
        ok = pcall(firesignal, button.MouseButton1Click)
        if ok then
            return true
        end
    end

    return false, "กด connection ของปุ่มไม่ได้"
end

local function performInfinityMansionEntry()
    if busy then return false, "entry already running" end
    if game.PlaceId ~= AO_LOBBY_PLACE_ID then return false, "ต้องใช้งานจาก Lobby" end

    busy = true
    local function finish(ok, message)
        busy = false
        return ok, message
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local mainFolder = workspace:FindFirstChild("MainFolder")
    local zones = mainFolder and mainFolder:FindFirstChild("Zones")
    local zone = zones and zones:FindFirstChild("InfinityCastle")
    if not root or not humanoid or not zone or not zone:IsA("BasePart") then
        return finish(false, "ไม่พบ Zones.InfinityCastle หรือตัวละคร")
    end

    status.Text = "กำลังเปิด Infinite Mansion"
    humanoid:Move(Vector3.zero, false)
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = zone.CFrame * CFrame.new(0, 2, 0)
    if type(firetouchinterest) == "function" then
        pcall(firetouchinterest, root, zone, 0)
        task.wait(0.1)
        pcall(firetouchinterest, root, zone, 1)
    end

    local mansionFrame
    local openedAt = os.clock()
    while os.clock() - openedAt < 10 do
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
        local misc = mainUI and mainUI:FindFirstChild("Misc")
        mansionFrame = misc and misc:FindFirstChild("InfinityCastleFrame")
        if mansionFrame and mansionFrame.Visible then break end
        root.CFrame = zone.CFrame * CFrame.new(0, 2, 0)
        task.wait(0.25)
    end
    if not mansionFrame or not mansionFrame.Visible then
        return finish(false, "หน้า InfinityCastleFrame ไม่เปิดภายใน 10 วินาที")
    end

    local enterButton
    pcall(function()
        enterButton = mansionFrame.Main.ContentFrame.Main.EnterButton
    end)
    local clicked, clickError = fireGuiButton(enterButton)
    if not clicked then return finish(false, "กด Enter Floor ไม่ได้: " .. tostring(clickError)) end

    status.Text = "กด Enter Floor แล้ว — รอเข้าด่าน"
    local waitStarted = os.clock()
    while game.PlaceId == AO_LOBBY_PLACE_ID and os.clock() - waitStarted < 30 do
        task.wait(0.5)
    end
    if game.PlaceId == AO_LOBBY_PLACE_ID then
        return finish(false, "กด Enter Floor แล้วแต่ยังอยู่ Lobby")
    end
    return finish(true, "เข้า Infinite Mansion สำเร็จ")
end

local function waitForMapSelectContent(timeout)
    local startedAt = os.clock()

    while os.clock() - startedAt < timeout do
        local mainUI = player:FindFirstChildOfClass("PlayerGui")
        mainUI = mainUI and mainUI:FindFirstChild("MainUI")
        local mapSelect = mainUI and mainUI:FindFirstChild("MapSelect")
        local frame = mapSelect and mapSelect:FindFirstChild("MapSelectFrame")
        local main = frame and frame:FindFirstChild("Main")
        local content = main and main:FindFirstChild("ContentFrame")

        if content and content.Visible then
            return content
        end

        task.wait(0.2)
    end

    return nil
end

local function waitForAfterMapSelectContent(timeout)
    local startedAt = os.clock()

    while os.clock() - startedAt < timeout do
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
        local mapSelect = mainUI and mainUI:FindFirstChild("MapSelect")
        local frame = mapSelect and mapSelect:FindFirstChild("AfterMapSelectFrame")
        local main = frame and frame:FindFirstChild("Main")
        local content = main and main:FindFirstChild("ContentFrame")

        if frame and frame.Visible and content and content.Visible then
            return content
        end

        task.wait(0.2)
    end

    return nil
end

local function selectGameStageUI()
    status.Text = "รอหน้าเลือกด่านของเกม..."
    status.TextColor3 = Color3.fromRGB(255, 213, 106)

    local content = waitForMapSelectContent(10)
    if not content then
        return false, "หน้า MapSelect ไม่เปิดภายใน 10 วินาที"
    end

    local stageSelection = content:FindFirstChild("StageSelection")
    local stageMain = stageSelection and stageSelection:FindFirstChild("Main")
    local modeButton = stageMain and stageMain:FindFirstChild(selectedMode)

    status.Text = "เลือกโหมด " .. selectedMode
    local ok, err = fireGuiButton(modeButton)
    if not ok then
        return false, "กดโหมดไม่ได้: " .. tostring(err)
    end
    task.wait(0.45)

    local worldSelect = content:FindFirstChild("WorldSelect")
    local scrollingFrame = worldSelect and worldSelect:FindFirstChild("ScrollingFrame")
    local mapButton = scrollingFrame and scrollingFrame:FindFirstChild(selectedMap.Value)

    status.Text = "เลือกด่าน " .. selectedMap.Label
    ok, err = fireGuiButton(mapButton)
    if not ok then
        return false, "กดด่านไม่ได้: " .. tostring(err)
    end
    task.wait(0.45)

    local actSelect = content:FindFirstChild("ActSelect")
    local actButtonName = tostring(selectedAct.Value)

    if selectedMode == "Legend" then
        actButtonName = actButtonName:match("%d+") or actButtonName
    end

    local actButton = actSelect and actSelect:FindFirstChild(actButtonName)

    status.Text = "เลือก " .. selectedAct.Label
    ok, err = fireGuiButton(actButton)
    if not ok then
        return false, "กด Act ไม่ได้: " .. tostring(err)
    end
    task.wait(0.45)

    local actFrame = content:FindFirstChild("ActFrame")
    local difficulty = actFrame and actFrame:FindFirstChild("Difficulty")
    local hardButton = difficulty and difficulty:FindFirstChild("Hard")

    status.Text = "เลือก Hard"
    ok, err = fireGuiButton(hardButton)
    if not ok then
        return false, "กด Hard ไม่ได้: " .. tostring(err)
    end
    task.wait(0.45)

    local bottomFrame = content:FindFirstChild("BottomFrame")
    local buttons = bottomFrame and bottomFrame:FindFirstChild("Buttons")
    local startButton = buttons and buttons:FindFirstChild("Start")

    status.Text = "กด Start"
    ok, err = fireGuiButton(startButton)
    if not ok then
        return false, "กด Start ไม่ได้: " .. tostring(err)
    end

    status.Text = "รอหน้าต่างยืนยัน Start..."
    local afterContent = waitForAfterMapSelectContent(10)
    if not afterContent then
        return false, "หน้า AfterMapSelectFrame ไม่เปิดภายใน 10 วินาที"
    end

    local afterButtons = afterContent:FindFirstChild("Buttons")
    local confirmStart = afterButtons and afterButtons:FindFirstChild("Start")

    status.Text = "กด Start ยืนยัน"
    ok, err = fireGuiButton(confirmStart)
    if not ok then
        return false, "กด Start ยืนยันไม่ได้: " .. tostring(err)
    end

    return true, string.format(
        "%s | %s | %s | Hard",
        selectedMode,
        selectedMap.Label,
        selectedAct.Label
    )
end

-- ============================================================
-- ⭐ UI ใหม่ (2026-09): เข้าด่านแบบ "กดปุ่มจริง" (fire connection + VIM คลิกกลางปุ่ม) — เลิกยิง remote
--   flow ยืนยันจาก dump: Play → CoreSelection[โหมด] → WorldSelect[map] → ActSelect[act]
--                        → Difficulty[diff] → BottomFrame.Buttons.Start (Select) → PartyFrame.Buttons.Start
-- ============================================================
local VIM_AO = game:GetService("VirtualInputManager")

local function aoVimClick(obj)
    if not obj then return false end
    return pcall(function()
        local ap, sz = obj.AbsolutePosition, obj.AbsoluteSize
        local x = ap.X + sz.X / 2
        local y = ap.Y + sz.Y / 2
        VIM_AO:SendMouseMoveEvent(x, y, game)
        task.wait(0.03)
        VIM_AO:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.04)
        VIM_AO:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

-- กดปุ่ม: จำลองเมาส์จริงล้วน (VIM) เหมือน AE — ไม่ fire connection (กันจอดำ/ยิง handler เกิน)
local function aoClick(obj, label)
    if not obj then
        if AO_HEADLESS then print("[AO ENTER] ✗ ไม่เจอปุ่ม: " .. tostring(label)) end
        return false
    end
    local okc, sx, sy = pcall(function()
        local ap, sz = obj.AbsolutePosition, obj.AbsoluteSize
        return math.floor(ap.X + sz.X / 2), math.floor(ap.Y + sz.Y / 2)
    end)
    aoVimClick(obj)
    if AO_HEADLESS then
        print(("[AO ENTER] ✓ กด %s @ %s,%s"):format(tostring(label), okc and tostring(sx) or "?", okc and tostring(sy) or "?"))
    end
    return true
end

local function aoFind(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

-- รอจน getter() คืน object ที่ Visible (ไล่ขึ้นถึง ScreenGui) ภายใน timeout
local function aoWaitVisible(getter, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        local obj = getter()
        if obj then
            local vis, n = true, obj
            while n and n:IsA("GuiObject") do if not n.Visible then vis = false break end n = n.Parent end
            if vis then return obj end
        end
        task.wait(0.15)
    end
    return nil
end

local function performEntry()
    if busy then
        return false, "entry already running"
    end

    if game.PlaceId ~= AO_LOBBY_PLACE_ID then
        status.Text = "ผิด PlaceId: ต้องกดจาก Lobby เท่านั้น"
        status.TextColor3 = Color3.fromRGB(255, 121, 121)
        return false, status.Text
    end

    busy = true
    local diff = tostring(_G.AO_DIFFICULTY or "Hard")   -- ฟาร์มใช้ Hard | override ด้วย _G.AO_DIFFICULTY
    local mode = selectedMode                            -- "Story" / "Legend"
    local mapV = selectedMap.Value                       -- "WestCity" ...
    local actName = tostring(selectedAct.Value)          -- "1".."6" / "Infinite" / "Legend1"
    if mode == "Legend" then actName = actName:match("%d+") or actName end   -- Legend act ใช้เลขล้วน
    if AO_HEADLESS then print(("[AO ENTER v%s] (กดจริง) %s / %s / %s / %s"):format(AO_TEST_VERSION, mode, mapV, actName, diff)) end
    enterButton.Text = "ENTERING..."
    status.Text = string.format("%s | %s | %s | %s", mode, selectedMap.Label, selectedAct.Label, diff)
    status.TextColor3 = Color3.fromRGB(255, 213, 106)

    local function fail(msg)
        busy = false
        enterButton.Text = "SELECT STAGE"
        status.Text = msg
        status.TextColor3 = Color3.fromRGB(255, 121, 121)
        return false, msg
    end

    local pg = player:FindFirstChildOfClass("PlayerGui")
    local mainUI = pg and pg:FindFirstChild("MainUI")
    if not mainUI then return fail("ไม่พบ MainUI") end

    -- (1) กด Play เปิดหน้าเลือกโหมด
    aoClick(aoFind(mainUI, "HUD", "LeftButtons", "Play") or aoFind(mainUI, "HUD", "Play"), "Play")

    -- (2) รอ CoreSelection แล้วกด tile โหมด (Story/Legend)
    local coreItems = aoWaitVisible(function()
        return aoFind(mainUI, "MapSelect", "CoreSelection", "Main", "ScrollingFrame", "CoreModes", "Items")
    end, 8)
    if coreItems then
        aoClick(coreItems:FindFirstChild(mode), "โหมด " .. mode)
    elseif AO_HEADLESS then
        print("[AO ENTER] CoreSelection ไม่โผล่ (อาจเปิด MapSelect อยู่แล้ว) — ไปต่อ")
    end

    -- (3) รอ MapSelectFrame ContentFrame
    local content = aoWaitVisible(function()
        return aoFind(mainUI, "MapSelect", "MapSelectFrame", "Main", "ContentFrame")
    end, 10)
    if not content then return fail("หน้า MapSelect ไม่เปิดภายใน 10 วิ") end

    -- (4) แท็บ Story/Legend
    local tab = aoFind(content, "StageSelection", "Main", mode)
    if tab then aoClick(tab, "แท็บ " .. mode); task.wait(0.4) end

    -- (5) เลือกโลก
    local worldBtn = aoFind(content, "WorldSelect", "ScrollingFrame", mapV)
    if not worldBtn then return fail("ไม่เจอปุ่มโลก " .. mapV) end
    aoClick(worldBtn, "โลก " .. selectedMap.Label)
    task.wait(0.5)

    -- (6) เลือก act
    local actBtn = aoFind(content, "ActSelect", actName)
    if not actBtn then return fail("ไม่เจอปุ่ม act " .. actName) end
    aoClick(actBtn, "act " .. selectedAct.Label)
    task.wait(0.5)

    -- (7) ความยาก
    local diffBtn = aoFind(content, "ActFrame", "Difficulty", diff)
    if diffBtn then aoClick(diffBtn, diff); task.wait(0.4) end

    -- (8) ปุ่ม Select/Start ใน MapSelect → เปิด PartyFrame
    local selBtn = aoFind(content, "BottomFrame", "Buttons", "Start")
    if not selBtn then return fail("ไม่เจอปุ่ม Select (BottomFrame.Buttons.Start)") end
    aoClick(selBtn, "Select (ยืนยันด่าน)")

    -- (9) รอ PartyFrame แล้วกด Start เข้าด่าน
    local function getPartyStart()
        return aoFind(mainUI, "MapSelect", "PartyFrame", "Main", "Buttons", "Start")
    end
    local partyStart = aoWaitVisible(getPartyStart, 10)
    if partyStart then
        task.wait(0.4)
        aoClick(partyStart, "Start (เข้าด่าน)")
    else
        if AO_HEADLESS then print("[AO ENTER] PartyFrame ไม่โผล่ — กด Select ซ้ำ") end
        aoClick(selBtn, "Select ซ้ำ")
        partyStart = aoWaitVisible(getPartyStart, 6)
        if partyStart then task.wait(0.4); aoClick(partyStart, "Start (เข้าด่าน)") end
    end

    if AO_HEADLESS then print("[AO ENTER v" .. AO_TEST_VERSION .. "] กดครบทุกปุ่ม → รอเข้าด่าน") end
    enterButton.Text = "WAITING FOR GAME..."
    local waitStarted = os.clock()
    while game.PlaceId == AO_LOBBY_PLACE_ID and os.clock() - waitStarted < 30 do
        task.wait(0.5)
    end
    busy = false
    enterButton.Text = "SELECT STAGE"
    if game.PlaceId == AO_LOBBY_PLACE_ID then
        return false, "กดครบทุกปุ่มแล้ว แต่ครบ 30 วิยังอยู่ Lobby"
    end
    return true, string.format("เข้าด่าน %s/%s/%s (%s)", mode, mapV, actName, diff)
end

enterButton.MouseButton1Click:Connect(performEntry)

refreshForMode()

if AO_HEADLESS then
    selectedMode = "Story"
    selectedMap = MAPS.Story[1]
    selectedAct = ACTS.Story[#ACTS.Story]
end

_G.AO_ENTER_WESTCITY_INFINITE = function()
    selectedMode = "Story"
    selectedMap = MAPS.Story[1]
    selectedAct = ACTS.Story[#ACTS.Story]
    return performEntry()
end

_G.AO_ENTER_STAGE = function(mode, mapValue, actValue)
    mode = tostring(mode or "")
    mapValue = tostring(mapValue or "")
    actValue = tostring(actValue or "")
    if not MAPS[mode] or not ACTS[mode] then return false, "unsupported mode: " .. mode end

    local mapInfo
    for _, item in ipairs(MAPS[mode]) do
        if item.Value == mapValue or item.Label == mapValue then mapInfo = item break end
    end
    local actInfo
    for _, item in ipairs(ACTS[mode]) do
        if item.Value == actValue or item.Label == actValue then actInfo = item break end
    end
    if not mapInfo then return false, "unsupported map: " .. mapValue end
    if not actInfo then return false, "unsupported act: " .. actValue end

    selectedMode = mode
    selectedMap = mapInfo
    selectedAct = actInfo
    return performEntry()
end

_G.AO_ENTER_INFINITY_MANSION = performInfinityMansionEntry

print("[AO TEST v" .. AO_TEST_VERSION .. "] " .. (AO_HEADLESS and "headless loaded" or "UI loaded"))
