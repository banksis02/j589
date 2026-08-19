-- ============================================================
-- ANIME ORIGINS PATH + AUTO PLACE TEST/HEADLESS v0.17
-- Standalone in-game test - not part of s789
-- ============================================================

local TEST_VERSION = "0.33"
local GAME_PLACE_ID = 116173040971120
local AO_HEADLESS = _G.AO_HEADLESS == true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local guiParent = gethui and gethui() or CoreGui

local oldGui = guiParent:FindFirstChild("AOPlaceTestUI")
if oldGui then oldGui:Destroy() end

local oldPath = workspace:FindFirstChild("AO_Path_Debug")
if oldPath then oldPath:Destroy() end

local pathFolder = workspace:FindFirstChild("PathFolder")
local towersFolder = workspace:FindFirstChild("Towers")
local remoteFolder = RS:FindFirstChild("LobbyRemotes")
local handlerFolder = remoteFolder and remoteFolder:FindFirstChild("TowerHandlerRemotes")
local placeRemote = handlerFolder and handlerFolder:FindFirstChild("TowerHandlerFunction")

local function buildPath()
    if not pathFolder then return nil, "ไม่พบ Workspace.PathFolder" end

    local parts = {}
    for _, object in ipairs(pathFolder:GetChildren()) do
        if object:IsA("BasePart") and tonumber(object.Name) then
            parts[#parts + 1] = object
        end
    end
    table.sort(parts, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)
    if #parts < 2 then return nil, "PathFolder มี Waypoint น้อยกว่า 2 จุด" end

    local points, cumulative = {}, {0}
    for index, part in ipairs(parts) do
        points[index] = part.Position
        if index > 1 then
            cumulative[index] = cumulative[index - 1] + (points[index] - points[index - 1]).Magnitude
        end
    end
    return {Points = points, Cumulative = cumulative, Total = cumulative[#cumulative]}
end

local path, pathError = buildPath()

local function posAndDirectionAt(percent)
    if not path then return nil end
    local distance = math.clamp(percent, 0, 100) / 100 * path.Total
    for index = 2, #path.Points do
        if path.Cumulative[index] >= distance then
            local startDistance = path.Cumulative[index - 1]
            local segmentLength = path.Cumulative[index] - startDistance
            local alpha = segmentLength > 0 and (distance - startDistance) / segmentLength or 0
            local a, b = path.Points[index - 1], path.Points[index]
            local direction = b - a
            return a:Lerp(b, alpha), direction.Magnitude > 0 and direction.Unit or Vector3.zAxis
        end
    end
    local last = #path.Points
    return path.Points[last], (path.Points[last] - path.Points[last - 1]).Unit
end

local function addPercentLabel(parent, position, text)
    local anchor = Instance.new("Part")
    anchor.Name = "Label_" .. text
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = position + Vector3.new(0, 2.5, 0)
    anchor.Transparency = 1
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Parent = parent

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(70, 28)
    billboard.AlwaysOnTop = true
    billboard.Parent = anchor

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    label.BackgroundTransparency = 0.15
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 70, 70)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Parent = billboard
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
end

local function drawPath()
    local existing = workspace:FindFirstChild("AO_Path_Debug")
    if existing then existing:Destroy() end
    if not path then return false, pathError end

    local folder = Instance.new("Folder")
    folder.Name = "AO_Path_Debug"
    folder.Parent = workspace

    for index = 2, #path.Points do
        local a = path.Points[index - 1] + Vector3.new(0, 0.35, 0)
        local b = path.Points[index] + Vector3.new(0, 0.35, 0)
        local length = (b - a).Magnitude
        local segment = Instance.new("Part")
        segment.Name = "Segment_" .. tostring(index - 1)
        segment.Size = Vector3.new(0.55, 0.18, length)
        segment.CFrame = CFrame.lookAt((a + b) / 2, b)
        segment.Color = Color3.fromRGB(255, 25, 25)
        segment.Material = Enum.Material.Neon
        segment.Transparency = 0.08
        segment.Anchored = true
        segment.CanCollide = false
        segment.CanTouch = false
        segment.CanQuery = false
        segment.Parent = folder
    end

    for _, percent in ipairs({0, 25, 50, 75, 100}) do
        local position = posAndDirectionAt(percent)
        addPercentLabel(folder, position, tostring(percent) .. "%")
    end

    return true, string.format("เส้นทาง %d จุด | %.1f studs", #path.Points, path.Total)
end

local function placementCount()
    towersFolder = workspace:FindFirstChild("Towers")
    local units = towersFolder and #towersFolder:GetChildren() or 0
    local nodes = workspace:FindFirstChild("UnitNodes")
    local reserved = nodes and #nodes:GetChildren() or 0
    return units + reserved
end

local function raycastParams()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded = {}
    if player.Character then excluded[#excluded + 1] = player.Character end
    if workspace:FindFirstChild("Characters") then excluded[#excluded + 1] = workspace.Characters end
    if workspace:FindFirstChild("Enemies") then excluded[#excluded + 1] = workspace.Enemies end
    if workspace:FindFirstChild("Towers") then excluded[#excluded + 1] = workspace.Towers end
    if workspace:FindFirstChild("AO_Path_Debug") then excluded[#excluded + 1] = workspace.AO_Path_Debug end
    if pathFolder then excluded[#excluded + 1] = pathFolder end
    params.FilterDescendantsInstances = excluded
    return params
end

local function groundCandidates(percent)
    local base, direction = posAndDirectionAt(percent)
    if not base then return {} end
    local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit
    local candidates, params = {}, raycastParams()
    -- ชิดขอบถนนก่อน แล้วค่อยขยายออกเมื่อพื้นที่เต็ม
    -- Ground ต้องอยู่ชิดขอบทาง ลดโอกาสล้ำเข้าอาคาร/สิ่งกีดขวาง
    local offsets = {2.25, -2.25, 3, -3, 3.75, -3.75, 4.5, -4.5, 5.25, -5.25}

    for _, offset in ipairs(offsets) do
        local sample = base + perpendicular * offset
        local hit = workspace:Raycast(sample + Vector3.new(0, 18, 0), Vector3.new(0, -40, 0), params)
        if hit and hit.Normal.Y >= 0.65 and math.abs(hit.Position.Y - base.Y) <= 3.5 then
            candidates[#candidates + 1] = hit.Position + hit.Normal * 0.08
        else
            candidates[#candidates + 1] = Vector3.new(sample.X, base.Y - 0.1, sample.Z)
        end
    end
    return candidates
end

local function hillCandidates(percent)
    local base, direction = posAndDirectionAt(percent)
    if not base then return {} end
    local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit
    local candidates, params, seen = {}, raycastParams(), {}

    -- เกมกำหนดเขตวาง Hill จริงไว้ใน Workspace.PlacementParts.Hill
    -- ใช้พื้นที่นี้โดยตรงเพื่อไม่เดาจากหลังคา ต้นไม้ หรือสิ่งกีดขวางใน Map
    local placementParts = workspace:FindFirstChild("PlacementParts")
    if placementParts then
        local hillParts = {}
        for _, object in ipairs(placementParts:GetDescendants()) do
            if object:IsA("BasePart") then
                local current = object
                local isHill = false
                while current and current ~= placementParts.Parent do
                    if string.lower(current.Name) == "hill" then
                        isHill = true
                        break
                    end
                    if current == placementParts then break end
                    current = current.Parent
                end
                if isHill then hillParts[#hillParts + 1] = object end
            end
        end

        for _, part in ipairs(hillParts) do
            local localBase = part.CFrame:PointToObjectSpace(base)
            local halfX = math.max(0, part.Size.X / 2 - 0.75)
            local halfZ = math.max(0, part.Size.Z / 2 - 0.75)
            local centerX = math.clamp(localBase.X, -halfX, halfX)
            local centerZ = math.clamp(localBase.Z, -halfZ, halfZ)

            for _, offset in ipairs({
                Vector2.new(0, 0),
                Vector2.new(2, 0), Vector2.new(-2, 0),
                Vector2.new(0, 2), Vector2.new(0, -2),
                Vector2.new(3.5, 0), Vector2.new(-3.5, 0),
                Vector2.new(0, 3.5), Vector2.new(0, -3.5),
            }) do
                local x = math.clamp(centerX + offset.X, -halfX, halfX)
                local z = math.clamp(centerZ + offset.Y, -halfZ, halfZ)
                local position = part.CFrame:PointToWorldSpace(Vector3.new(x, part.Size.Y / 2 + 0.08, z))
                local horizontalDistance = Vector3.new(position.X - base.X, 0, position.Z - base.Z).Magnitude

                if horizontalDistance <= 24 then
                    local key = string.format("%.1f:%.1f:%.1f", position.X, position.Y, position.Z)
                    if not seen[key] then
                        seen[key] = true
                        candidates[#candidates + 1] = position
                    end
                end
            end
        end

        table.sort(candidates, function(a, b)
            local da = Vector3.new(a.X - base.X, 0, a.Z - base.Z).Magnitude
            local db = Vector3.new(b.X - base.X, 0, b.Z - base.Z).Magnitude
            return da < db
        end)

        while #candidates > 12 do table.remove(candidates) end
        if #candidates > 0 then return candidates end
    end

    -- Fallback สำหรับแมพที่ไม่มี PlacementParts.Hill
    -- Hill ค้นเฉพาะหลังคา/หินที่ติดทางเดิน ไม่กวาดลึกเข้าแผนที่
    local sides = {5, -5, 7, -7, 9, -9, 11, -11, 13, -13, 15, -15}
    local alongs = {0, 4, -4}

    for _, side in ipairs(sides) do
        for _, along in ipairs(alongs) do
            local sample = base + perpendicular * side + direction * along
            local hit = workspace:Raycast(sample + Vector3.new(0, 120, 0), Vector3.new(0, -180, 0), params)
            local horizontalDistance = hit and Vector3.new(
                hit.Position.X - base.X,
                0,
                hit.Position.Z - base.Z
            ).Magnitude or math.huge

            if hit and hit.Normal.Y >= 0.65 and hit.Position.Y >= base.Y + 2.5 and horizontalDistance <= 16 then
                local key = string.format("%.1f:%.1f:%.1f", hit.Position.X, hit.Position.Y, hit.Position.Z)
                if not seen[key] then
                    seen[key] = true
                    candidates[#candidates + 1] = hit.Position + hit.Normal * 0.08
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        local da = Vector3.new(a.X - base.X, 0, a.Z - base.Z).Magnitude
        local db = Vector3.new(b.X - base.X, 0, b.Z - base.Z).Magnitude
        return da < db
    end)

    while #candidates > 12 do
        table.remove(candidates)
    end

    return candidates
end

local function invokePlacement(slot, position, isHill)
    if not placeRemote then return false, "ไม่พบ TowerHandlerFunction" end
    local before = placementCount()
    local invT0 = os.clock()
    local ok, result = pcall(function()
        return placeRemote:InvokeServer(
            "PlaceTower",
            "Tower" .. tostring(slot),
            position,
            Vector3.new(0, 1, 0),
            0,
            nil,
            isHill
        )
    end)
    local invDt = os.clock() - invT0
    if invDt > 1.5 then
        print(string.format("[AO DBG invoke] ⏰ T%d InvokeServer ช้า %.1f วิ (isHill=%s, result=%s)",
            slot, invDt, tostring(isHill), tostring(result)))
    end
    if not ok then return false, tostring(result) end

    -- server คืน "table" (object ของ tower ที่วางแล้ว) = วางติดจริง
    -- result = -1 (number) = เงินไม่พอ / วางไม่ได้ ; false/nil = จุดผิด
    if _G.AO_INVOKE_LOG == nil then _G.AO_INVOKE_LOG = 0 end
    if _G.AO_INVOKE_LOG < 10 then
        _G.AO_INVOKE_LOG += 1
        print(string.format("[AO DBG invoke] T%d result=%s (%s) dt=%.2fวิ", slot, tostring(result), typeof(result), invDt))
    end
    if typeof(result) == "table" then return true, result end
    return false, result   -- result อาจเป็น -1 (เงินไม่พอ) — ผู้เรียกเช็คได้
end

local function tryCandidates(slot, candidates, isHill, statusCallback)
    for index, position in ipairs(candidates) do
        statusCallback(string.format("Tower%d %s จุด %d/%d", slot, isHill and "Hill" or "Ground", index, #candidates))
        local placed, result = invokePlacement(slot, position, isHill)
        if placed then
            return true, position, result
        end
        if result == -1 then
            return false, nil, -1   -- เงินไม่พอ → จุดอื่นก็ไม่ติด ไม่ต้องเสียเวลาลองต่อ
        end
        task.wait(0.04)
    end
    return false
end

local gui = Instance.new("ScreenGui")
gui.Name = "AOPlaceTestUI"
gui.ResetOnSpawn = false
gui.Enabled = not AO_HEADLESS
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(390, 382)
main.Position = UDim2.new(0.5, -195, 0.5, -191)
main.BackgroundColor3 = Color3.fromRGB(21, 23, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -55, 0, 44)
title.Position = UDim2.fromOffset(15, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "AO Path + Place Test v" .. TEST_VERSION
title.TextColor3 = Color3.fromRGB(240, 242, 255)
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -43, 0, 9)
close.BackgroundColor3 = Color3.fromRGB(174, 54, 67)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Parent = main
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function()
    local debugPath = workspace:FindFirstChild("AO_Path_Debug")
    if debugPath then debugPath:Destroy() end
    gui:Destroy()
end)

local function makeButton(text, x, y, width, height)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width, height)
    button.Position = UDim2.fromOffset(x, y)
    button.BackgroundColor3 = Color3.fromRGB(48, 54, 72)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(239, 241, 250)
    button.TextSize = 13
    button.Parent = main
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    return button
end

local selectedSlot, selectedType = 1, "Auto"
local slotButton = makeButton("Slot: Tower1", 15, 58, 170, 40)
local typeButton = makeButton("Type: Auto", 200, 58, 175, 40)

local percentLabel = Instance.new("TextLabel")
percentLabel.Size = UDim2.fromOffset(170, 38)
percentLabel.Position = UDim2.fromOffset(15, 110)
percentLabel.BackgroundTransparency = 1
percentLabel.Font = Enum.Font.GothamSemibold
percentLabel.Text = "Path Percent (0-100)"
percentLabel.TextColor3 = Color3.fromRGB(190, 197, 218)
percentLabel.TextSize = 13
percentLabel.TextXAlignment = Enum.TextXAlignment.Left
percentLabel.Parent = main

local percentBox = Instance.new("TextBox")
percentBox.Size = UDim2.fromOffset(175, 38)
percentBox.Position = UDim2.fromOffset(200, 110)
percentBox.BackgroundColor3 = Color3.fromRGB(35, 39, 52)
percentBox.BorderSizePixel = 0
percentBox.Font = Enum.Font.GothamBold
percentBox.Text = "50"
percentBox.PlaceholderText = "0-100"
percentBox.TextColor3 = Color3.fromRGB(255, 100, 100)
percentBox.TextSize = 15
percentBox.ClearTextOnFocus = false
percentBox.Parent = main
Instance.new("UICorner", percentBox).CornerRadius = UDim.new(0, 8)

local drawButton = makeButton("REDRAW RED PATH", 15, 162, 360, 40)
drawButton.BackgroundColor3 = Color3.fromRGB(150, 45, 55)
local placeButton = makeButton("PLACE SELECTED", 15, 214, 175, 48)
placeButton.BackgroundColor3 = Color3.fromRGB(65, 101, 208)
local allButton = makeButton("START SMART AUTO", 200, 214, 175, 48)
allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
local gemButton = makeButton("GEM W20: OFF", 15, 274, 360, 40)
gemButton.BackgroundColor3 = Color3.fromRGB(103, 75, 180)

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(360, 44)
status.Position = UDim2.fromOffset(15, 326)
status.BackgroundColor3 = Color3.fromRGB(29, 32, 42)
status.BorderSizePixel = 0
status.Font = Enum.Font.Gotham
status.Text = path and string.format("พร้อม | %d จุด | %.1f studs", #path.Points, path.Total) or tostring(pathError)
status.TextColor3 = path and Color3.fromRGB(124, 225, 151) or Color3.fromRGB(255, 110, 110)
status.TextSize = 12
status.TextWrapped = true
status.Parent = main
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 8)

local function setStatus(text, good)
    status.Text = tostring(text)
    status.TextColor3 = good == false and Color3.fromRGB(255, 110, 110) or Color3.fromRGB(255, 213, 106)
end

local function getSpeedControls()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local gameUI = playerGui and playerGui:FindFirstChild("GameUI")
    local topUI = gameUI and gameUI:FindFirstChild("TopUI")
    local gameSpeed = topUI and topUI:FindFirstChild("GameSpeed")
    local mainSpeed = gameSpeed and gameSpeed:FindFirstChild("Main")
    local buttonFrame = mainSpeed and mainSpeed:FindFirstChild("ButtonFrame")

    return {
        One = buttonFrame and buttonFrame:FindFirstChild("One"),
        Two = buttonFrame and buttonFrame:FindFirstChild("Two"),
        Three = buttonFrame and buttonFrame:FindFirstChild("Three"),
        Circle = mainSpeed and mainSpeed:FindFirstChild("Circle"),
    }
end

local function guiCenter(guiObject)
    return guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
end

local function selectedSpeedLevel(controls)
    if not controls.Circle then return nil end
    local circleCenter = guiCenter(controls.Circle)
    local selected, bestDistance = nil, math.huge

    for _, level in ipairs({"One", "Two", "Three"}) do
        local button = controls[level]
        if button and button:IsA("GuiButton") then
            local distance = (guiCenter(button) - circleCenter).Magnitude
            if distance < bestDistance then
                selected = level
                bestDistance = distance
            end
        end
    end

    return selected
end


local function activateSpeedButton(button)
    if not button or not button:IsA("GuiButton") then return false end

    if type(firesignal) == "function" then
        local ok = pcall(firesignal, button.MouseButton1Click)
        if ok then return true end
    end

    if type(getconnections) == "function" then
        local ok = pcall(function()
            for _, connection in ipairs(getconnections(button.MouseButton1Click)) do
                if connection.Function then connection.Function() end
            end
        end)
        if ok then return true end
    end

    return pcall(function() button:Activate() end)
end

local function setBestGameSpeed()
    local controls = getSpeedControls()
    if not controls.Two or not controls.Three or not controls.Circle then
        return nil, "ไม่พบปุ่ม Game Speed ครบ"
    end

    -- ลองขั้น 3 ก่อน แล้วอ่านตำแหน่ง Circle เพื่อยืนยันว่าเกมยอมรับจริง
    activateSpeedButton(controls.Three)
    task.wait(0.8)
    if selectedSpeedLevel(controls) == "Three" then
        return 3, "Game Speed ขั้น 3"
    end

    -- ไม่มีสิทธิ์ขั้น 3 หรือเกมไม่ยอมรับ: กลับมาใช้ขั้น 2
    activateSpeedButton(controls.Two)
    task.wait(0.5)
    if selectedSpeedLevel(controls) == "Two" then
        return 2, "Game Speed ขั้น 2"
    end

    return nil, "ตั้ง Game Speed ไม่สำเร็จ"
end

_G.AO_SET_BEST_SPEED = setBestGameSpeed

local gemFarmEnabled = false
local gemRestartLocked = false
local gemRestartStartedAt = 0
local gemLastWave = nil
local gemRoundCaptured = false
local gemRoundStartedAt = os.clock()
local gemStats = {
    Runs = 0,
    Gems = 0,
    TraitRerolls = 0,
    LastGems = 0,
    LastTraitRerolls = 0,
    LastWave = 0,
    LastPlaySeconds = 0,
}

local function readCurrentWave()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local gameUI = playerGui and playerGui:FindFirstChild("GameUI")
    local topUI = gameUI and gameUI:FindFirstChild("TopUI")
    local info = topUI and topUI:FindFirstChild("Info")
    local waveFrame = info and info:FindFirstChild("Wave")
    local waveLabel = waveFrame and waveFrame:FindFirstChild("TextLabel")
    local text = waveLabel and tostring(waveLabel.Text) or ""
    return tonumber(text:match("(%d+)")), text
end

local function findRestartButton()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
    local settingsFrame = mainUI and mainUI:FindFirstChild("SettingsFrame")
    if not settingsFrame then return nil end

    for _, object in ipairs(settingsFrame:GetDescendants()) do
        local text = nil
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            text = string.lower(tostring(object.Text):match("^%s*(.-)%s*$"))
        end

        if text == "restart" then
            if object:IsA("GuiButton") then return object end
            local current = object.Parent
            while current and current ~= settingsFrame do
                if current:IsA("GuiButton") then return current end
                current = current.Parent
            end
        end
    end

    return nil
end

local function guiIsActuallyVisible(object)
    local current = object
    while current and current ~= player.PlayerGui do
        if current:IsA("GuiObject") and current.Visible == false then return false end
        if current:IsA("LayerCollector") and current.Enabled == false then return false end
        current = current.Parent
    end
    return true
end

-- reward จริงอยู่ใน MainUI — ต้องข้าม BottomUI/TowersToolbar (Glow ของยูนิตในช่อง
-- เข้าเงื่อนไข "กลางจอ+ใหญ่+มีรูป" แล้วโดนคลิกวนไม่หยุด = สแปม/แลค)
local function isInToolbar(object)
    local anc = object.Parent
    while anc do
        local n = anc.Name
        if n == "BottomUI" or n == "TowersToolbar" or n == "Hotbar" then return true end
        anc = anc.Parent
    end
    return false
end

-- รางวัล AO โผล่เป็นรูปไอเทมขนาดใหญ่กลางจอและต้องคลิกก่อน Auto Replay
-- จะทำงานทั้งกรณีแพ้ก่อน Wave 20 และกรณี Restart ที่ Wave 20
local function findCenteredRewardItem()
    local camera = workspace.CurrentCamera
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not camera or not playerGui then return nil end

    local viewport = camera.ViewportSize
    if viewport.X <= 0 or viewport.Y <= 0 then return nil end

    local screenCenter = viewport / 2
    local best, bestScore = nil, -math.huge
    for _, object in ipairs(playerGui:GetDescendants()) do
        local isImage = object:IsA("ImageLabel") or object:IsA("ImageButton")
        local isViewport = object:IsA("ViewportFrame")
        if (isImage or isViewport) and guiIsActuallyVisible(object) and not isInToolbar(object) then
            local size = object.AbsoluteSize
            local center = object.AbsolutePosition + size / 2
            local areaRatio = (size.X * size.Y) / math.max(1, viewport.X * viewport.Y)
            local centered = math.abs(center.X - screenCenter.X) <= viewport.X * 0.24
                and math.abs(center.Y - screenCenter.Y) <= viewport.Y * 0.28
            local rewardSize = size.X >= math.max(80, viewport.X * 0.10)
                and size.Y >= math.max(80, viewport.Y * 0.12)
                and areaRatio >= 0.012 and areaRatio <= 0.28
            local hasVisual = isViewport or tostring(object.Image or "") ~= ""

            if centered and rewardSize and hasVisual then
                local score = (object.ZIndex or 0) * 1000000 + size.X * size.Y
                if score > bestScore then
                    best, bestScore = object, score
                end
            end
        end
    end
    return best
end

local lastRewardItemClick = 0
local function dismissRewardItem()
    if os.clock() - lastRewardItemClick < 0.65 then return false end
    local item = findCenteredRewardItem()
    if not item then return false end

    local center = item.AbsolutePosition + item.AbsoluteSize / 2
    local x, y = math.floor(center.X), math.floor(center.Y)
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.06)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    if ok then
        lastRewardItemClick = os.clock()
        print("[AO REWARD] clicked " .. item:GetFullName() .. " @ " .. x .. "," .. y)
    end
    return ok
end

_G.AO_DISMISS_REWARD_ITEM = dismissRewardItem

local function readRewardAmount(rewardName)
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local gameUI = playerGui and playerGui:FindFirstChild("GameUI")
    local management = gameUI and gameUI:FindFirstChild("ManagementFrame")
    local stageInfo = management and management:FindFirstChild("StageInfoFrame")
    local mainFrame = stageInfo and stageInfo:FindFirstChild("Main")
    local canvas = mainFrame and mainFrame:FindFirstChild("CanvasGroup")
    local scrolling = canvas and canvas:FindFirstChild("ScrollingFrame")
    local gained = scrolling and scrolling:FindFirstChild("GainedRewards")
    local inner = gained and gained:FindFirstChild("InnerFrame")
    local reward = inner and inner:FindFirstChild(rewardName)
    if not reward then return 0 end

    local imageLabel = reward:FindFirstChild("ImageLabel")
    local info = imageLabel and imageLabel:FindFirstChild("Info")
    local amountText = info and info:FindFirstChild("AmountText")
    local text = amountText and tostring(amountText.Text) or ""
    return tonumber(text:match("(%d+)")) or 0
end

local function readRoundRewards()
    return {
        Gems = readRewardAmount("Currency_Gems"),
        TraitRerolls = readRewardAmount("Currency_TraitReroll"),
    }
end

local function captureRoundRewards(wave)
    if gemRoundCaptured then return false, readRoundRewards() end
    local rewards = readRoundRewards()
    gemRoundCaptured = true
    gemStats.Runs += 1
    gemStats.Gems += rewards.Gems
    gemStats.TraitRerolls += rewards.TraitRerolls
    gemStats.LastGems = rewards.Gems
    gemStats.LastTraitRerolls = rewards.TraitRerolls
    gemStats.LastWave = wave or 0
    gemStats.LastPlaySeconds = math.max(0, os.clock() - gemRoundStartedAt)

    print(string.format(
        "[AO GEM] Run %d | Wave %s | +%d Gems | +%d Trait Reroll | Total=%d Gems/%d Trait",
        gemStats.Runs,
        tostring(wave or "?"),
        rewards.Gems,
        rewards.TraitRerolls,
        gemStats.Gems,
        gemStats.TraitRerolls
    ))

    return true, rewards
end

local function triggerGemRestart()
    local button = findRestartButton()
    if not button then return false, "ไม่พบปุ่ม Restart ใน SettingsFrame" end
    local ok = activateSpeedButton(button)
    return ok, ok and "กด Restart ที่เวฟ 20 แล้ว" or "เรียกปุ่ม Restart ไม่สำเร็จ"
end

local function setGemFarmEnabled(enabled)
    gemFarmEnabled = enabled == true
    if not gemFarmEnabled then gemRestartLocked = false end
    gemButton.Text = gemFarmEnabled and "GEM W20: ON" or "GEM W20: OFF"
    gemButton.BackgroundColor3 = gemFarmEnabled and Color3.fromRGB(65, 151, 105) or Color3.fromRGB(103, 75, 180)
    return gemFarmEnabled
end

_G.AO_GET_WAVE = readCurrentWave
_G.AO_GET_ROUND_REWARDS = readRoundRewards
_G.AO_GEM_STATS = function()
    local copy = {}
    for key, value in pairs(gemStats) do copy[key] = value end
    return copy
end
_G.AO_GEM_W20_START = function() return setGemFarmEnabled(true) end
_G.AO_GEM_W20_STOP = function() return setGemFarmEnabled(false) end

gemButton.MouseButton1Click:Connect(function()
    local enabled = setGemFarmEnabled(not gemFarmEnabled)
    local wave = readCurrentWave()
    setStatus(string.format("Gem W20 %s | Wave=%s", enabled and "ON" or "OFF", tostring(wave or "?")))
end)

slotButton.MouseButton1Click:Connect(function()
    selectedSlot = selectedSlot % 6 + 1
    slotButton.Text = "Slot: Tower" .. selectedSlot
end)

local types = {"Auto", "Ground", "Hill"}
local typeIndex = 1
typeButton.MouseButton1Click:Connect(function()
    typeIndex = typeIndex % #types + 1
    selectedType = types[typeIndex]
    typeButton.Text = "Type: " .. selectedType
end)

drawButton.MouseButton1Click:Connect(function()
    local ok, message = drawPath()
    setStatus(message, ok)
end)

local placing = false
local smartRunning = false
local smartGeneration = 0
local slotTypes = {}
local slotPlaced = {0, 0, 0, 0, 0, 0}
local slotFailures = {0, 0, 0, 0, 0, 0}
local SMART_MAX_PER_SLOT = 3

-- ต้นทางก่อนเพื่อเริ่มยิงไว → กลางทาง → ด่านท้ายสำรอง
local SMART_PERCENT_PLAN = {
    10, 14, 18, 22, 27, 32,
    38, 44, 50, 57,
    64, 71, 78,
}
local smartPlanIndex = 1

local function getGameToolbar()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local gameUI = playerGui and playerGui:FindFirstChild("GameUI")
    local bottomUI = gameUI and gameUI:FindFirstChild("BottomUI")
    return bottomUI and bottomUI:FindFirstChild("TowersToolbar")
end

local function slotContainsUnit(slot, wantedName)
    local toolbar = getGameToolbar()
    local button = toolbar and toolbar:FindFirstChild("Tower" .. tostring(slot))
    if not button then return false end

    local wanted = string.lower(tostring(wantedName))

    if string.lower(button.Name):find(wanted, 1, true) then return true end

    for key, value in pairs(button:GetAttributes()) do
        if string.lower(tostring(key)):find(wanted, 1, true) or string.lower(tostring(value)):find(wanted, 1, true) then
            return true
        end
    end

    for _, object in ipairs(button:GetDescendants()) do
        if string.lower(object.Name):find(wanted, 1, true) then return true end

        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            if string.lower(tostring(object.Text)):find(wanted, 1, true) then return true end
        elseif object:IsA("StringValue") then
            if string.lower(tostring(object.Value)):find(wanted, 1, true) then return true end
        end

        for key, value in pairs(object:GetAttributes()) do
            if string.lower(tostring(key)):find(wanted, 1, true) or string.lower(tostring(value)):find(wanted, 1, true) then
                return true
            end
        end
    end

    return false
end

local function findSlotByUnitName(unitName)
    for slot = 1, 6 do
        if slotContainsUnit(slot, unitName) then return slot end
    end
    return nil
end

local function slotHasUnit(slot)
    local toolbar = getGameToolbar()
    local button = toolbar and toolbar:FindFirstChild("Tower" .. tostring(slot))
    if not button then return false end

    for _, object in ipairs(button:GetDescendants()) do
        if object.Name == "NameLabel" and
            (object:IsA("TextLabel") or object:IsA("TextButton")) and
            tostring(object.Text):match("%S") then
            return true
        end

        if object:IsA("Model") and object:FindFirstAncestorOfClass("ViewportFrame") then
            return true
        end
    end

    return false
end

local function enemyProgressPercent()
    if not path then return nil end
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local furthest = nil

    for _, enemy in ipairs(enemies:GetChildren()) do
        local root = enemy:FindFirstChild("HumanoidRootPart")
        if not root and enemy:IsA("Model") then root = enemy.PrimaryPart end
        if root and root:IsA("BasePart") then
            local bestDistance = math.huge
            local bestPathDistance = 0

            for index = 2, #path.Points do
                local a, b = path.Points[index - 1], path.Points[index]
                local segment = b - a
                local lengthSquared = segment:Dot(segment)
                local alpha = lengthSquared > 0 and math.clamp((root.Position - a):Dot(segment) / lengthSquared, 0, 1) or 0
                local nearest = a + segment * alpha
                local distance = (root.Position - nearest).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPathDistance = path.Cumulative[index - 1] + segment.Magnitude * alpha
                end
            end

            local percent = bestPathDistance / path.Total * 100
            if not furthest or percent > furthest then furthest = percent end
        end
    end

    return furthest
end

local function nextSmartPercent()
    local percent = SMART_PERCENT_PLAN[smartPlanIndex]
    smartPlanIndex = smartPlanIndex % #SMART_PERCENT_PLAN + 1
    return percent
end

local function placeSlot(slot, placementType, percent)
    if placementType == "Auto" then
        local ground = groundCandidates(percent)
        local hill = hillCandidates(percent)
        local candidateCount = math.min(6, math.max(#ground, #hill))

        -- ไม่ลอง Ground จนหมดก่อน เพราะถ้ายูนิตเป็น Hill จะทำให้แต่ละตัวช้ามาก
        -- สลับ Ground/Hill ทีละตำแหน่งและจำกัดจำนวน probe
        -- ป้องกันการไล่ Hill มากกว่า 100 จุดเมื่อยูนิต/พื้นที่วางไม่ได้
        local lastRes
        for index = 1, candidateCount do
            local gRes, hRes
            if ground[index] then
                setStatus(string.format("Tower%d Auto Ground %d/%d", slot, index, #ground))
                local ok, result = invokePlacement(slot, ground[index], false)
                if ok then return true, "Ground", ground[index], result end
                gRes = result; lastRes = result
            end

            -- ⭐ ต้องลอง Hill ต่อแม้ Ground ได้ -1 (ยูนิต Hill-only วางบนพื้นไม่ได้ = -1 แต่วางบนตึกได้)
            if hill[index] then
                setStatus(string.format("Tower%d Auto Hill %d/%d", slot, index, #hill))
                local ok, result = invokePlacement(slot, hill[index], true)
                if ok then return true, "Hill", hill[index], result end
                hRes = result; lastRes = result
            end

            -- ข้ามจุดอื่นเฉพาะตอนทั้ง Ground+Hill คืน -1 (เงินไม่พอจริง) — ไม่ใช่แค่ Ground -1
            if gRes == -1 and (hRes == -1 or not hill[index]) then return false, nil, nil, -1 end
            task.wait(0.04)
        end

        return false, nil, nil, lastRes
    end

    if placementType == "Ground" then
        local ok, position, res = tryCandidates(slot, groundCandidates(percent), false, setStatus)
        if ok then return true, "Ground", position, res end
        return false, nil, nil, res
    end
    if placementType == "Hill" then
        local ok, position, res = tryCandidates(slot, hillCandidates(percent), true, setStatus)
        if ok then return true, "Hill", position, res end
        return false, nil, nil, res
    end
    return false
end

placeButton.MouseButton1Click:Connect(function()
    if placing then return end
    placing = true
    local percent = math.clamp(tonumber(percentBox.Text) or 50, 0, 100)
    percentBox.Text = tostring(percent)
    local ok, kind, position = placeSlot(selectedSlot, selectedType, percent)
    if ok then
        status.Text = string.format("Tower%d วาง %s @ %.0f%% | %s", selectedSlot, kind, percent, tostring(position))
        status.TextColor3 = Color3.fromRGB(124, 225, 151)
    else
        setStatus("Tower" .. selectedSlot .. " วางไม่ติดทุกจุดที่ลอง", false)
    end
    placing = false
end)

allButton.MouseButton1Click:Connect(function()
    if smartRunning then
        smartRunning = false
        smartGeneration += 1
        allButton.Text = "START SMART AUTO"
        allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
        setStatus("หยุด Smart Auto แล้ว")
        return
    end

    if placing then return end
    smartRunning = true
    smartGeneration += 1
    local myGeneration = smartGeneration
    smartPlanIndex = 1
    for slot = 1, 6 do
        slotPlaced[slot] = 0
        slotFailures[slot] = 0
        slotTypes[slot] = nil
    end
    allButton.Text = "STOP SMART AUTO"
    allButton.BackgroundColor3 = Color3.fromRGB(174, 60, 72)

    task.spawn(function()
        local function stillRunning()
            return smartRunning and myGeneration == smartGeneration
        end
        local function dbg(msg) print(string.format("[AO DBG v%s|gen%d] %s", TEST_VERSION, myGeneration, msg)) end
        local function hotbarSnap()
            local parts = {}
            for slot = 1, 6 do parts[#parts + 1] = "T" .. slot .. (slotHasUnit(slot) and "=Y" or "=-") end
            return table.concat(parts, " ")
        end
        _G.AO_INVOKE_LOG = 0   -- รีเซ็ตทุกครั้งที่เริ่ม → รอบ 2+ ได้เห็นค่า result (table/-1/false) สดๆ
        dbg(string.format("========== START วางตัว | wave=%s | บนสนาม=%d | hotbar[%s] ==========",
            tostring(readCurrentWave()), placementCount(), hotbarSnap()))

        local speedLevel, speedMessage = setBestGameSpeed()
        dbg("ตั้ง game speed: " .. tostring(speedMessage))
        setStatus(speedMessage, speedLevel ~= nil)
        task.wait(0.15)

        -- ⭐ Legend: ปิด AutoUpgradeOnPlacement ของเกม "ในด่านเลย" ก่อนวางตัวแรก
        --    (ถ้าเปิด เกมจะอัพเกรดตัวที่วางทันที กินเงินที่เราต้องใช้วาง Leorio/ดาเมจ).
        --    ระบบเราคุมอัพเกรดเอง: ตัวเงิน max ก่อน แล้วค่อยดาเมจ. โหมดอื่นไม่แตะ.
        if tostring(_G.AO_PLACE_MODE) == "ao_legend" and type(_G.AO_SET_TOGGLE) == "function" then
            local okUp = _G.AO_SET_TOGGLE("AutoUpgradeOnPlacement", false)
            dbg("[Legend] ปิด AutoUpgradeOnPlacement เกม = " .. tostring(okUp))
        end

        -- รอ hotbar โหลดยูนิตให้ "เสถียร" ก่อนเริ่มวาง
        -- (ตอน replay เกมรีเร็ว ช่องยูนิตยังขึ้นไม่ครบ → เดิมวางเอ๋อ:
        --  วางตัวเดียว/ไม่วาง/ไม่เจอตัวเงิน แล้ว placementCount>0 ทำให้ monitor ไม่ retry)
        do
            local function countUnitSlots()
                local n = 0
                for slot = 1, 6 do if slotHasUnit(slot) then n += 1 end end
                return n
            end
            local waitStart = os.clock()
            local lastCount, stableSince = -1, os.clock()
            while stillRunning() and os.clock() - waitStart < 8 do
                local c = countUnitSlots()
                if c ~= lastCount then
                    lastCount = c
                    stableSince = os.clock()
                elseif c > 0 and os.clock() - stableSince >= 0.6 then
                    break
                end
                setStatus("รอ hotbar โหลดยูนิต... (" .. c .. " ช่อง)")
                task.wait(0.2)
            end
            dbg("hotbar พร้อม: " .. lastCount .. " ช่อง [" .. hotbarSnap() .. "]")
        end

        local function queueOne(slot, placementType, percent, label)
            if not stillRunning() then return false end
            placing = true
            setStatus(string.format("%s | Tower%d @ %.1f%%", label, slot, percent))
            local t0 = os.clock()
            local ok, kind, position, result = placeSlot(slot, placementType, percent)
            local took = os.clock() - t0
            placing = false
            local reason = ok and ("สำเร็จ " .. tostring(kind))
                or ("ไม่ติด" .. (result == -1 and "[เงินไม่พอ]" or "[จุดผิด/เต็ม]"))
            dbg(string.format("  วาง T%d %s @%.1f%% [%s] -> %s (ใช้ %.1f วิ)",
                slot, tostring(placementType), percent, label, reason, took))

            if ok then
                slotTypes[slot] = kind
                slotPlaced[slot] += 1
                status.Text = string.format("%s สำเร็จ | Tower%d %s @ %.1f%%", label, slot, kind, percent)
                status.TextColor3 = Color3.fromRGB(124, 225, 151)
                task.wait(0.12)
                return true, nil
            end

            setStatus(string.format("%s ไม่สำเร็จ | Tower%d @ %.1f%%", label, slot, percent), false)
            task.wait(0.15)
            return false, result   -- result == -1 = เงินไม่พอ ; อื่นๆ = จุดผิด/เต็ม
        end

        -- 1) ตัวเงิน Leorio ก่อน 3 ตัว ไม่สนเงิน (เกมจะจองตำแหน่งไว้)
        --    บางไอดีไม่มี Leorio → ข้ามขั้นวางตัวเงิน ไปวางตัวดาเมจแทน (ไม่หยุดค้าง)
        local moneySlot = findSlotByUnitName("Leorio")
        dbg("[1] ตัวเงิน: Leorio = " .. (moneySlot and ("Tower" .. moneySlot) or "ไม่พบ"))
        if moneySlot then
            slotTypes[moneySlot] = "Ground"
            local leorioQueued = 0
            local leoStart = os.clock()
            local leoPercents = {30, 33, 36, 39, 42, 45, 48, 27, 24}
            local leoIdx = 1
            -- วาง Leo ให้ครบ 3 (ตัวเงิน=รายได้) — เงินไม่พอก็รอสั้นๆ ให้ตัวที่วางแล้วหาเงิน แล้วลองใหม่ (ไม่ STOP)
            while stillRunning() and leorioQueued < 3 and os.clock() - leoStart < 15 do
                local percent = leoPercents[leoIdx]
                leoIdx = leoIdx % #leoPercents + 1
                if queueOne(moneySlot, "Ground", percent, "Leorio ตัวเงิน " .. (leorioQueued + 1) .. "/3") then
                    leorioQueued += 1
                else
                    task.wait(0.6)   -- เงินไม่พอ → รอเงินจาก Leo ที่วางไปแล้ว
                end
            end
            dbg("[1] Leorio จองได้ " .. leorioQueued .. "/3 → ไปวางตัวดาเมจต่อ")
        else
            setStatus("ไม่พบ Leorio — ข้ามตัวเงิน วางตัวดาเมจแทน")
        end

        local damageSlots = {}
        for slot = 1, 6 do
            if slot ~= moneySlot and slotHasUnit(slot) then
                damageSlots[#damageSlots + 1] = slot
            end
        end
        dbg("[2] ตัวดาเมจ: " .. #damageSlots .. " ช่อง [Tower" .. table.concat(damageSlots, ",Tower") .. "]")

        if #damageSlots == 0 then
            dbg("❌ STOP: ไม่มีตัวดาเมจในช่องที่เหลือ")
            smartRunning = false
            allButton.Text = "START SMART AUTO"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            setStatus("ไม่พบตัวดาเมจในช่องที่เหลือ", false)
            placing = false
            return
        end

        -- ⭐ โหมด Legend (ด่านยาก): นอกจากตัวเงิน → ตัวที่เหลือทั้งหมดกระจุกที่ 75-85%
        --    + ใช้ Hill ด้วย (Auto = ลอง ground+hill) เพราะมอน Hill โผล่ตั้งแต่ต้นเกม
        --    ข้ามชุดดักหน้ามอน/เติม 5-10% ของโหมดอื่น
        if tostring(_G.AO_PLACE_MODE) == "ao_legend" then
            dbg("[Legend] วางตัวที่เหลือกระจุก 75-85% (Auto=ground+hill)")
            local legendPercents = {75, 78, 81, 84, 85, 82, 79, 76, 80, 83, 77}
            local lpIdx, emptyRounds = 1, 0
            local fillStart = os.clock()
            while stillRunning() and os.clock() - fillStart < 90 and emptyRounds < 3 do
                local placedThisRound, moneyBlocked = false, false
                for _, slot in ipairs(damageSlots) do
                    if not stillRunning() then break end
                    local percent = legendPercents[lpIdx]
                    lpIdx = lpIdx % #legendPercents + 1
                    local ok, res = queueOne(slot, "Auto", percent, "Legend กระจุก 75-85%")
                    if ok then placedThisRound = true
                    elseif res == -1 then moneyBlocked = true end
                end
                if placedThisRound then emptyRounds = 0
                elseif moneyBlocked then setStatus("[Legend] เงินไม่พอ — รอเงินแล้ววางต่อ"); task.wait(1.5)
                else emptyRounds = emptyRounds + 1; task.wait(0.3) end
            end
            local total = 0
            for slot = 1, 6 do total += slotPlaced[slot] end
            dbg(string.format("========== วาง Legend เสร็จ | กระจุก 75-85% | วางรวม %d | บนสนาม=%d | empty=%d ==========",
                total, placementCount(), emptyRounds))

            -- ⭐ ออโต้อัพเกรดเอง (Legend ปิดออโต้อัพเกรดเกม): ตัวเงินจน max ก่อน แล้วค่อยตัวดาเมจ
            local function umSF()
                local ok, sf = pcall(function()
                    return player.PlayerGui.GameUI.ManagementFrame.UnitManagerFrame.Main.CanvasGroup.ScrollingFrame
                end)
                return ok and sf or nil
            end
            local function upgradeOnce(uuid)
                if not placeRemote then return false end
                local ok, res = pcall(function() return placeRemote:InvokeServer("UpgradeTower", uuid) end)
                return ok and res == true
            end
            local function towerMaxed(uuid)
                local sf = umSF(); if not sf then return false end
                local c = sf:FindFirstChild(uuid); if not c then return true end
                local maxed = false
                pcall(function()
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("TextLabel") and tostring(d.Text):upper():find("MAX") then maxed = true; break end
                    end
                end)
                return maxed
            end
            local function readPlaced()
                local moneyU, damageU = {}, {}
                local sf = umSF()
                if sf then
                    for _, c in ipairs(sf:GetChildren()) do
                        if c:IsA("GuiObject") and #c.Name >= 30 and c.Name:find("%-") then
                            local nm = ""
                            pcall(function() nm = tostring(c.Main.TowerButton.ImageLabel.Info.NameLabel.Text) end)
                            if nm:lower():find("leorio") then moneyU[#moneyU + 1] = c.Name
                            else damageU[#damageU + 1] = c.Name end
                        end
                    end
                end
                return moneyU, damageU
            end
            task.wait(0.5)
            local moneyU, damageU = readPlaced()
            dbg(("[Legend] อัพเกรดเอง: ตัวเงิน %d / ดาเมจ %d"):format(#moneyU, #damageU))
            -- 1) ตัวเงินจน max (ทีละตัว) — เงินไม่พอก็รอ
            for _, uuid in ipairs(moneyU) do
                local t0 = os.clock()
                while stillRunning() and os.clock() - t0 < 25 do
                    if towerMaxed(uuid) then break end
                    if upgradeOnce(uuid) then task.wait(0.15) else task.wait(0.6) end
                end
            end
            dbg("[Legend] ตัวเงิน max แล้ว → อัพเกรดตัวดาเมจ")
            -- 2) ตัวดาเมจทั้งหมด (วน round-robin จน max หรือหมดเวลา)
            local dmgT0, allMax = os.clock(), false
            while stillRunning() and not allMax and os.clock() - dmgT0 < 150 do
                allMax = true
                for _, uuid in ipairs(damageU) do
                    if not stillRunning() then break end
                    if not towerMaxed(uuid) then
                        allMax = false
                        if upgradeOnce(uuid) then task.wait(0.15) else task.wait(0.5) end
                    end
                end
            end
            dbg("[Legend] อัพเกรดตัวดาเมจเสร็จ (allMax=" .. tostring(allMax) .. ")")

            smartRunning = false
            allButton.Text = "SMART AUTO COMPLETE"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            status.Text = string.format("Legend วางครบ | รวม %d ตำแหน่ง", total)
            status.TextColor3 = Color3.fromRGB(124, 225, 151)
            placing = false
            return
        end

        -- รอมอนสั้นๆ 6 วิ เพื่อจับตำแหน่งนำหน้า (เดิม 30 วิ = หน่วงนานตั้งแต่ต้น)
        local monsterPercent
        local waitStarted = os.clock()
        while stillRunning() and os.clock() - waitStarted < 6 do
            monsterPercent = enemyProgressPercent()
            if monsterPercent then break end
            setStatus("วาง Leorio แล้ว | รอมอนเกิด...")
            task.wait(0.4)
        end

        -- ไม่เจอมอนใน 6 วิ → ไม่หยุด ใช้ค่า default (มอน ~10%) เพื่อวางดักต่อเลย
        if monsterPercent == nil then
            monsterPercent = 10
            dbg("[3] ไม่เจอมอนใน 6 วิ → ใช้ default 10% (ดักหน้าที่ 30%)")
        else
            dbg(string.format("[3] เจอมอนที่ %.1f%% → ดักหน้าที่ %.1f%%", monsterPercent, math.clamp(monsterPercent + 35, 20, 95)))
        end

        local INTERCEPT_LEAD = 35   -- นำหน้ามอนกี่ % (เดิม 20 = ใกล้ไป) — ปรับตรงนี้
        local interceptPercent = math.clamp(monsterPercent + INTERCEPT_LEAD, 20, 95)

        -- 2) ดักหน้ามอน +20% ให้สำเร็จ 2-3 ตัวก่อนเท่านั้น
        local interceptOffsets = {-2, 0, 2, -4, 4, -6, 6}
        local interceptIndex = 1
        local interceptQueued = 0
        local interceptNoProgress = 0
        local preferredInterceptSlot = nil

        -- วนวางชุดดัก +20% จนได้ 3 ตัว หรือครบ 20 วิ — เงินไม่พอก็รอสั้นๆ แล้วลองใหม่ (ไม่ข้ามไป 5%)
        local interceptStart = os.clock()
        while stillRunning() and interceptQueued < 3 and os.clock() - interceptStart < 20 do
            local placedThisRound = false

            if preferredInterceptSlot then
                local offset = interceptOffsets[interceptIndex]
                interceptIndex = interceptIndex % #interceptOffsets + 1
                local ok = queueOne(
                    preferredInterceptSlot,
                    slotTypes[preferredInterceptSlot] or "Auto",
                    math.clamp(interceptPercent + offset, 5, 95),
                    string.format("ดักหน้ามอน %.1f%% +20 (%d/3)", monsterPercent, interceptQueued + 1)
                )

                if ok then
                    interceptQueued += 1
                    placedThisRound = true
                else
                    preferredInterceptSlot = nil
                end
            end

            if not placedThisRound then
                for _, slot in ipairs(damageSlots) do
                    if not stillRunning() or interceptQueued >= 3 then break end

                    local offset = interceptOffsets[interceptIndex]
                    interceptIndex = interceptIndex % #interceptOffsets + 1
                    local ok = queueOne(
                        slot,
                        slotTypes[slot] or "Auto",
                        math.clamp(interceptPercent + offset, 5, 95),
                        string.format("ดักหน้ามอน %.1f%% +20 (%d/3)", monsterPercent, interceptQueued + 1)
                    )

                    if ok then
                        interceptQueued += 1
                        placedThisRound = true
                        preferredInterceptSlot = slot
                        break
                    end
                end
            end

            -- ทั้งรอบวางไม่ได้ (เงินไม่พอ) → รอ 0.6 วิ ให้เงินสะสมแล้วลองใหม่ (ไม่เลิก ไม่ข้าม)
            if not placedThisRound then task.wait(0.6) end
        end

        dbg("[3] ชุดดักหน้ามอน +20% จองได้ " .. interceptQueued .. "/3 → ไปวางต้นทางต่อ")

        -- 3) ชุดดักเดิมอาจเลือก Hill ทั้งหมด: เติมตัวดาเมจ Ground ที่ +20% อีก 1-2 ตัว
        -- ไม่ใช้ Leorio และไม่ลองช่องที่รู้แล้วว่าเป็น Hill
        local groundInterceptQueued = 0
        local groundNoProgress = 0
        local preferredGroundSlot = nil
        local groundOffsets = {3, -3, 5, -5, 7, -7, 1, -1}
        local groundOffsetIndex = 1

        while stillRunning() and groundInterceptQueued < 2 and groundNoProgress < 2 do
            local placedGroundThisRound = false

            if preferredGroundSlot then
                local offset = groundOffsets[groundOffsetIndex]
                groundOffsetIndex = groundOffsetIndex % #groundOffsets + 1
                local ok = queueOne(
                    preferredGroundSlot,
                    "Ground",
                    math.clamp(interceptPercent + offset, 5, 95),
                    string.format("เติม Ground ดักหน้า +20 (%d/2)", groundInterceptQueued + 1)
                )

                if ok then
                    groundInterceptQueued += 1
                    placedGroundThisRound = true
                else
                    preferredGroundSlot = nil
                end
            end

            if not placedGroundThisRound then
                for _, slot in ipairs(damageSlots) do
                    if not stillRunning() or groundInterceptQueued >= 2 then break end
                    if slotTypes[slot] ~= "Hill" then
                        local offset = groundOffsets[groundOffsetIndex]
                        groundOffsetIndex = groundOffsetIndex % #groundOffsets + 1
                        local ok = queueOne(
                            slot,
                            slotTypes[slot] or "Auto",
                            math.clamp(interceptPercent + offset, 5, 95),
                            string.format("ค้น Ground ดักหน้า +20 (%d/2)", groundInterceptQueued + 1)
                        )

                        if ok and slotTypes[slot] == "Ground" then
                            groundInterceptQueued += 1
                            placedGroundThisRound = true
                            preferredGroundSlot = slot
                            break
                        end
                    end
                end
            end

            groundNoProgress = placedGroundThisRound and 0 or (groundNoProgress + 1)
        end

        dbg("[4] เติม Ground ดักหน้า จองได้ " .. groundInterceptQueued .. "/2 → ไปวางต้นทางต่อ")
        dbg("[5] เริ่มเคลียร์ต้นทาง 5-10% (วางที่เหลือจนเต็ม)")

        -- 4) วางตัวที่เหลือทั้งหมดช่วง 5-10% (เคลียร์ต้นทาง — ทุกโหมด)
        --    เคยลอง gem กระจุก 60-80% แต่งานช้าลงรอบละ 1-2 นาที → กลับมา 5-10% เหมือนเดิม
        -- วางต่อเนื่องจนเต็มจริง — ไม่เลิกหลัง 2-3 ตัว
        -- ถ้ารอบไหนวางไม่เพิ่ม (เงินยังไม่พอ) หน่วง 1.5 วิ ให้เงินสะสม แล้วลองใหม่
        -- เลิกเมื่อ: วางไม่เพิ่มติดกัน 5 รอบ (สนามเต็มจริง) หรือครบ 90 วิ (กันค้าง)
        local earlyPercents = {5, 6, 7, 8, 9, 10, 5.5, 6.5, 7.5, 8.5, 9.5}
        local restLabel = "เคลียร์ต้นทางที่เหลือ"
        local earlyIndex = 1
        local emptyRounds = 0
        local fillStart = os.clock()

        while stillRunning() and os.clock() - fillStart < 60 and emptyRounds < 3 do
            local placedThisRound = false
            local moneyBlockedThisRound = false

            for _, slot in ipairs(damageSlots) do
                if not stillRunning() then break end
                local percent = earlyPercents[earlyIndex]
                earlyIndex = earlyIndex % #earlyPercents + 1

                local ok, res = queueOne(slot, slotTypes[slot] or "Auto", percent, restLabel)
                if ok then
                    placedThisRound = true
                elseif res == -1 then
                    moneyBlockedThisRound = true
                end
            end

            -- วางติด = ยังมีที่ให้วาง → วนต่อ
            -- ⭐ วางไม่ติดเพราะ "เงินไม่พอ" (-1) = ไม่ใช่สนามเต็ม → รอเงิน 1.5 วิ ไม่นับ empty
            --    วางไม่ติดเพราะ "ตำแหน่ง/เต็ม" = สนามเต็มจริง → นับถอย เลิกได้
            if placedThisRound then
                emptyRounds = 0
            elseif moneyBlockedThisRound then
                setStatus("[5] เงินไม่พอ — รอเงินสะสมแล้ววางต่อ")
                task.wait(1.5)
            else
                emptyRounds += 1
                task.wait(0.3)
            end
        end
        dbg("[5] จบเคลียร์ต้นทาง | empty=" .. emptyRounds .. " | ใช้เวลา " .. math.floor(os.clock() - fillStart) .. " วิ")

        smartRunning = false
        allButton.Text = "SMART AUTO COMPLETE"
        allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
        local total = 0
        for slot = 1, 6 do total += slotPlaced[slot] end
        dbg(string.format("========== จบ วางรวม %d ตำแหน่ง | ต่อช่อง T1=%d T2=%d T3=%d T4=%d T5=%d T6=%d | บนสนาม=%d ==========",
            total, slotPlaced[1], slotPlaced[2], slotPlaced[3], slotPlaced[4], slotPlaced[5], slotPlaced[6], placementCount()))
        status.Text = string.format("จองวางครบ | Leorio=%s | รวม %d ตำแหน่ง", moneySlot and ("Tower" .. moneySlot) or "ไม่มี", total)
        status.TextColor3 = Color3.fromRGB(124, 225, 151)
        placing = false
    end)
end)

local ok, message = drawPath()
if AO_HEADLESS then
    local debugPath = workspace:FindFirstChild("AO_Path_Debug")
    if debugPath then debugPath:Destroy() end
    ok, message = path ~= nil, path and "headless path ready" or pathError
elseif not ok then
    setStatus(message, false)
end

_G.AO_SMART_START = function()
    if smartRunning then return true, "already running" end
    return activateSpeedButton(allButton)
end

_G.AO_SMART_STOP = function()
    if not smartRunning then return true, "already stopped" end
    return activateSpeedButton(allButton)
end
_G.AO_PLACEMENT_COUNT = placementCount
_G.AO_SMART_RUNNING = function() return smartRunning end
_G.AO_CORE_READY = true

task.spawn(function()
    local speedLevel, speedMessage = setBestGameSpeed()
    print("[AO PLACE v" .. TEST_VERSION .. "] " .. speedMessage)
    if speedLevel then setStatus(speedMessage) end
end)

local lastEmptyFieldRecovery = 0
task.spawn(function()
    while gui.Parent do
        -- ไม่ผูกกับ Wave 20: ตอนแพ้ก่อนถึงเป้าก็มีรูปไอเทมบัง Auto Replay
        if AO_HEADLESS or gemFarmEnabled then
            pcall(dismissRewardItem)
        end

        local wave = readCurrentWave()

        -- Replay อาจรีเซ็ตเร็วเกินจนตัวตรวจจากสคริปต์หลักพลาด Wave 1-2
        -- ใช้สถานะจริงของสนามเป็นตัวตัดสิน: ถ้ายังเล่นอยู่แต่ไม่มี Tower ให้เริ่มวางใหม่เอง
        if AO_HEADLESS and wave and wave > 0 and wave < 20
            and placementCount() == 0 and not smartRunning
            and os.clock() - lastEmptyFieldRecovery >= 5 then
            lastEmptyFieldRecovery = os.clock()
            print(string.format(
                "[AO PLACE v%s] empty field at Wave %d -> restart Smart Auto",
                TEST_VERSION,
                wave
            ))
            task.spawn(function()
                -- รีเวฟ (20→1) ในแมตช์เดิมมีช่วง transition: เงิน/มอน/remote ยังไม่พร้อม
                -- ถ้าวางทันทีจะโดนปฏิเสธบางตัว → วางไม่ครบ แล้ว placementCount>0 ทำให้ไม่ retry
                -- หน่วงให้รีเซ็ตเสร็จก่อน แล้วยืนยันซ้ำว่ายังเป็นรอบใหม่ที่ว่างจริง
                task.wait(2)
                if not smartRunning then
                    local w = readCurrentWave()
                    if w and w > 0 and w < 20 and placementCount() == 0 then
                        pcall(_G.AO_SMART_START)
                    end
                end
            end)
        end

        if gemFarmEnabled then
            gemLastWave = wave or gemLastWave
            gemButton.Text = "GEM W20: ON | W" .. tostring(wave or "?")

            if wave and wave <= 2 and gemRestartLocked then
                gemRestartLocked = false
                gemRoundCaptured = false
                gemRoundStartedAt = os.clock()
                setStatus("Gem W20: เริ่มรอบใหม่ Wave " .. tostring(wave))
            elseif wave and wave >= 20 and gemRestartLocked and os.clock() - gemRestartStartedAt >= 6 then
                gemRestartLocked = false
                setStatus("Gem W20: Wave ยังไม่รีเซ็ต | เตรียมลอง Restart ใหม่", false)
            elseif wave and wave >= 20 and not gemRestartLocked then
                gemRestartLocked = true
                gemRestartStartedAt = os.clock()
                local _, rewards = captureRoundRewards(wave)
                setStatus(string.format(
                    "W%d | +%d Gem +%d Trait | กำลังกด Restart...",
                    wave,
                    rewards.Gems,
                    rewards.TraitRerolls
                ))

                local ok, restartMessage = triggerGemRestart()
                setStatus(restartMessage, ok)

                if not ok then
                    task.wait(2)
                    gemRestartLocked = false
                end
            end
        end

        task.wait(0.2)
    end
end)

print("[AO PLACE v" .. TEST_VERSION .. "] loaded | " .. tostring(message))
