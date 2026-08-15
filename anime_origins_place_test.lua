-- ============================================================
-- ANIME ORIGINS PATH + AUTO PLACE TEST v0.3
-- Standalone in-game test - not part of s789
-- ============================================================

local TEST_VERSION = "0.3"
local GAME_PLACE_ID = 116173040971120

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

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
    local offsets = {3.5, -3.5, 5, -5, 6.5, -6.5, 8, -8, 10, -10, 12, -12}

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
    local sides = {8, -8, 12, -12, 16, -16, 20, -20, 25, -25, 30, -30, 36, -36, 42, -42}
    local alongs = {0, 6, -6, 12, -12, 18, -18}

    for _, side in ipairs(sides) do
        for _, along in ipairs(alongs) do
            local sample = base + perpendicular * side + direction * along
            local hit = workspace:Raycast(sample + Vector3.new(0, 120, 0), Vector3.new(0, -180, 0), params)
            if hit and hit.Normal.Y >= 0.65 and hit.Position.Y >= base.Y + 2.5 then
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
    return candidates
end

local function invokePlacement(slot, position, isHill)
    if not placeRemote then return false, "ไม่พบ TowerHandlerFunction" end
    local before = placementCount()
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
    if not ok then return false, tostring(result) end

    local startedAt = os.clock()
    while os.clock() - startedAt < 1 do
        if placementCount() > before then return true, result end
        task.wait(0.1)
    end

    -- บางเซิร์ฟเวอร์คืน true เมื่อตำแหน่งถูกจอง แต่ยังไม่สร้าง Tower เพราะเงินไม่พอ
    if result == true then return true, result end
    return false, result
end

local function tryCandidates(slot, candidates, isHill, statusCallback)
    for index, position in ipairs(candidates) do
        statusCallback(string.format("Tower%d %s จุด %d/%d", slot, isHill and "Hill" or "Ground", index, #candidates))
        local placed, result = invokePlacement(slot, position, isHill)
        if placed then
            return true, position, result
        end
        task.wait(0.12)
    end
    return false
end

local gui = Instance.new("ScreenGui")
gui.Name = "AOPlaceTestUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(390, 330)
main.Position = UDim2.new(0.5, -195, 0.5, -165)
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

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(360, 44)
status.Position = UDim2.fromOffset(15, 274)
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
    if placementType == "Ground" or placementType == "Auto" then
        local ok, position = tryCandidates(slot, groundCandidates(percent), false, setStatus)
        if ok then return true, "Ground", position end
    end
    if placementType == "Hill" or placementType == "Auto" then
        local ok, position = tryCandidates(slot, hillCandidates(percent), true, setStatus)
        if ok then return true, "Hill", position end
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
    allButton.Text = "STOP SMART AUTO"
    allButton.BackgroundColor3 = Color3.fromRGB(174, 60, 72)

    task.spawn(function()
        local function stillRunning()
            return smartRunning and myGeneration == smartGeneration
        end

        local function queueOne(slot, placementType, percent, label)
            if not stillRunning() then return false end
            placing = true
            setStatus(string.format("%s | Tower%d @ %.1f%%", label, slot, percent))
            local ok, kind, position = placeSlot(slot, placementType, percent)
            placing = false

            if ok then
                slotTypes[slot] = kind
                slotPlaced[slot] += 1
                status.Text = string.format("%s สำเร็จ | Tower%d %s @ %.1f%%", label, slot, kind, percent)
                status.TextColor3 = Color3.fromRGB(124, 225, 151)
                task.wait(0.45)
                return true
            end

            setStatus(string.format("%s ไม่สำเร็จ | Tower%d @ %.1f%%", label, slot, percent), false)
            task.wait(0.5)
            return false
        end

        -- 1) ตัวเงิน Leorio ก่อนเสมอ 3 ตัว ไม่สนเงิน (เกมจะจองตำแหน่งไว้)
        local moneySlot = findSlotByUnitName("Leorio")
        if not moneySlot then
            smartRunning = false
            allButton.Text = "START SMART AUTO"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            setStatus("ไม่พบ Leorio ใน Tower1-6", false)
            placing = false
            return
        end

        slotTypes[moneySlot] = "Ground"
        local leorioQueued = 0
        for _, percent in ipairs({30, 33, 36, 39, 42, 45, 48, 27, 24}) do
            if not stillRunning() or leorioQueued >= 3 then break end
            if queueOne(moneySlot, "Ground", percent, "Leorio ตัวเงิน " .. (leorioQueued + 1) .. "/3") then
                leorioQueued += 1
            end
        end

        if leorioQueued < 3 then
            smartRunning = false
            allButton.Text = "START SMART AUTO"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            setStatus("จอง Leorio ได้เพียง " .. leorioQueued .. "/3 — หยุดเพื่อไม่ข้ามขั้น", false)
            placing = false
            return
        end

        -- รอให้มีมอนจริง เพื่อคำนวณตำแหน่งนำหน้า ไม่เดาจาก Wave
        local monsterPercent
        local waitStarted = os.clock()
        while stillRunning() and os.clock() - waitStarted < 30 do
            monsterPercent = enemyProgressPercent()
            if monsterPercent then break end
            setStatus("วาง Leorio แล้ว | รอมอนเกิดเพื่อคำนวณเปอร์เซ็นต์...")
            task.wait(0.5)
        end

        monsterPercent = monsterPercent or 0
        local interceptPercent = math.clamp(monsterPercent + 20, 20, 92)

        local damageSlots = {}
        for slot = 1, 6 do
            if slot ~= moneySlot and slotHasUnit(slot) then
                damageSlots[#damageSlots + 1] = slot
            end
        end


        if #damageSlots == 0 then
            smartRunning = false
            allButton.Text = "START SMART AUTO"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            setStatus("ไม่พบตัวดาเมจในช่องที่เหลือ", false)
            placing = false
            return
        end

        -- 2) ดักหน้ามอน +20% จำนวน 2-3 ตัว
        local interceptOffsets = {-2, 0, 2}
        for index = 1, math.min(3, #damageSlots) do
            local slot = damageSlots[index]
            queueOne(
                slot,
                slotTypes[slot] or "Auto",
                math.clamp(interceptPercent + interceptOffsets[index], 5, 95),
                string.format("ดักหน้ามอน %.1f%% +20", monsterPercent)
            )
        end

        -- 3) ตัวดาเมจที่เหลือกองช่วง 5-10% เพื่อฆ่าต้นทางและจบไว
        local earlyPercents = {5, 6.5, 8, 9.5, 7, 10, 5.5, 8.5, 6, 9}
        local earlyIndex = 1

        for round = 1, 3 do
            for _, slot in ipairs(damageSlots) do
                if not stillRunning() then break end
                local percent = earlyPercents[earlyIndex] or 8
                earlyIndex = earlyIndex % #earlyPercents + 1
                queueOne(slot, slotTypes[slot] or "Auto", percent, "เคลียร์ต้นทาง")
            end
        end

        smartRunning = false
        allButton.Text = "SMART AUTO COMPLETE"
        allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
        local total = 0
        for slot = 1, 6 do total += slotPlaced[slot] end
        status.Text = string.format("จองวางครบ | Leorio=Tower%d | รวม %d ตำแหน่ง", moneySlot, total)
        status.TextColor3 = Color3.fromRGB(124, 225, 151)
        placing = false
    end)
end)

local ok, message = drawPath()
if not ok then setStatus(message, false) end

print("[AO PLACE v" .. TEST_VERSION .. "] loaded | " .. tostring(message))
