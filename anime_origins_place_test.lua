-- ============================================================
-- ANIME ORIGINS PATH + AUTO PLACE TEST/HEADLESS v0.54
-- Standalone in-game test - not part of s789
-- ============================================================

local TEST_VERSION = "0.54"
local GAME_PLACE_ID = 116173040971120
local AO_HEADLESS = _G.AO_HEADLESS == true
_G.AO_PLACE_MODULE_GEN = (_G.AO_PLACE_MODULE_GEN or 0) + 1
local PLACE_MODULE_GEN = _G.AO_PLACE_MODULE_GEN

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local guiParent = gethui and gethui() or CoreGui

local function usesResilientPlacement()
    local mode = tostring(_G.AO_PLACE_MODE or "")
    return mode == "ao_mansion" or mode == "ao_gem" or mode == "ao_legend"
end

local oldGui = guiParent:FindFirstChild("AOPlaceTestUI")
if oldGui then oldGui:Destroy() end

local oldPath = workspace:FindFirstChild("AO_Path_Debug")
if oldPath then oldPath:Destroy() end

local pathFolder = workspace:FindFirstChild("PathFolder")
local towersFolder = workspace:FindFirstChild("Towers")
local remoteFolder = RS:FindFirstChild("LobbyRemotes")
local handlerFolder = remoteFolder and remoteFolder:FindFirstChild("TowerHandlerRemotes")
local placeRemote = handlerFolder and handlerFolder:FindFirstChild("TowerHandlerFunction")

local function buildOnePath(parts)
    if #parts < 2 then return nil end
    table.sort(parts, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)

    local points, cumulative = {}, {0}
    for index, part in ipairs(parts) do
        points[index] = part.Position
        if index > 1 then
            cumulative[index] = cumulative[index - 1] + (points[index] - points[index - 1]).Magnitude
        end
    end
    return {Points = points, Cumulative = cumulative, Total = cumulative[#cumulative]}
end

local function numericParts(container, recursive)
    local parts = {}
    local objects = recursive and container:GetDescendants() or container:GetChildren()
    for _, object in ipairs(objects) do
        if object:IsA("BasePart") and tonumber(object.Name) then
            parts[#parts + 1] = object
        end
    end
    return parts
end

local function buildPaths()
    if not pathFolder then return nil, "ไม่พบ Workspace.PathFolder" end

    -- ด่านทั่วไป: PathFolder.1, PathFolder.2, ... เป็น BasePart โดยตรง
    local direct = numericParts(pathFolder, false)
    if #direct >= 2 then
        return {buildOnePath(direct)}
    end

    -- Infinite Mansion: PathFolder มีโฟลเดอร์เลน 1-7 และแต่ละเลนมีจุด 1..N
    local lanes = {}
    for _, lane in ipairs(pathFolder:GetChildren()) do
        if tonumber(lane.Name) then
            local lanePath = buildOnePath(numericParts(lane, true))
            if lanePath then
                lanePath.Lane = tonumber(lane.Name)
                lanes[#lanes + 1] = {Order = tonumber(lane.Name), Path = lanePath}
            end
        end
    end
    table.sort(lanes, function(a, b) return a.Order < b.Order end)

    local paths = {}
    for _, lane in ipairs(lanes) do paths[#paths + 1] = lane.Path end
    if #paths == 0 then
        return nil, "PathFolder ไม่มีเส้นทางที่มี Waypoint อย่างน้อย 2 จุด"
    end
    return paths
end

local paths, pathError = buildPaths()
local path = paths and paths[1] or nil
local activeMansionPath = nil
local activeMansionLane = nil

local function buildMansionEntrancePath()
    if not paths or #paths == 0 then return nil end
    if #paths == 1 then return paths[1] end

    -- สอง waypoint แรกเป็นช่วงทางเข้าที่ทุกเส้นใช้ร่วมกัน
    -- ใช้ค่าเฉลี่ยเพื่อชดเชยบางเลนที่เหลื่อมกันประมาณ 1 stud
    local entrancePoints = {}
    for pointIndex = 1, 2 do
        local sum = Vector3.zero
        local count = 0
        for _, candidatePath in ipairs(paths) do
            if candidatePath.Points[pointIndex] then
                sum += candidatePath.Points[pointIndex]
                count += 1
            end
        end
        if count == 0 then return nil end
        entrancePoints[pointIndex] = sum / count
    end

    local total = (entrancePoints[2] - entrancePoints[1]).Magnitude
    if total <= 0 then return nil end
    return {
        Points = entrancePoints,
        Cumulative = {0, total},
        Total = total,
        Lane = "ทางเข้าร่วม",
    }
end

local mansionEntrancePath = buildMansionEntrancePath()

local function distanceToPathXZ(position, selectedPath)
    local bestDistance = math.huge
    for index = 2, #selectedPath.Points do
        local a = selectedPath.Points[index - 1]
        local b = selectedPath.Points[index]
        local segmentX = b.X - a.X
        local segmentZ = b.Z - a.Z
        local lengthSquared = segmentX * segmentX + segmentZ * segmentZ
        local alpha = 0
        if lengthSquared > 0 then
            alpha = math.clamp(
                ((position.X - a.X) * segmentX + (position.Z - a.Z) * segmentZ) / lengthSquared,
                0,
                1
            )
        end
        local nearestX = a.X + segmentX * alpha
        local nearestZ = a.Z + segmentZ * alpha
        local dx = position.X - nearestX
        local dz = position.Z - nearestZ
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance < bestDistance then bestDistance = distance end
    end
    return bestDistance
end

local function currentEnemyPositions()
    local positions = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return positions end

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy:IsA("Model") then
            local ok, pivot = pcall(enemy.GetPivot, enemy)
            if ok then positions[#positions + 1] = pivot.Position end
        elseif enemy:IsA("BasePart") then
            positions[#positions + 1] = enemy.Position
        end
    end
    return positions
end

local function scoreMansionPath(selectedPath, enemyPositions)
    local totalDistance = 0
    local farthestDistance = 0
    for _, position in ipairs(enemyPositions) do
        local distance = distanceToPathXZ(position, selectedPath)
        totalDistance += distance
        if distance > farthestDistance then farthestDistance = distance end
    end
    local averageDistance = #enemyPositions > 0 and totalDistance / #enemyPositions or math.huge
    -- ใช้ตัวที่แยกออกจากช่วงต้นร่วมเป็นน้ำหนักหลัก เพราะทั้ง 7 เส้นเริ่มทับกัน
    return farthestDistance + averageDistance * 0.15, averageDistance, farthestDistance
end

local function detectActiveMansionPath(timeoutSeconds, shouldContinue, progressCallback)
    if not paths or #paths == 0 then return nil, nil, "ไม่มีข้อมูลเส้นทาง" end
    if #paths == 1 then return paths[1], paths[1].Lane or 1, "มีเส้นทางเดียว" end

    local started = os.clock()
    local lastSummary = "ยังไม่มีมอน"
    while os.clock() - started < (timeoutSeconds or 30) do
        if shouldContinue and not shouldContinue() then
            return nil, nil, "ยกเลิกการหาเส้นทาง"
        end

        local enemyPositions = currentEnemyPositions()
        if #enemyPositions > 0 then
            local ranked = {}
            for index, candidatePath in ipairs(paths) do
                local score, average, farthest = scoreMansionPath(candidatePath, enemyPositions)
                ranked[#ranked + 1] = {
                    Path = candidatePath,
                    Lane = candidatePath.Lane or index,
                    Score = score,
                    Average = average,
                    Farthest = farthest,
                }
            end
            table.sort(ranked, function(a, b) return a.Score < b.Score end)

            local best = ranked[1]
            local second = ranked[2]
            local gap = second and (second.Score - best.Score) or math.huge
            lastSummary = string.format(
                "มอน %d | เส้น %d %.2f | อันดับสอง %.2f | gap %.2f",
                #enemyPositions,
                best.Lane,
                best.Score,
                second and second.Score or -1,
                gap
            )

            -- เส้นจริงต้องเกาะตำแหน่งมอน และต้องชนะอันดับสองชัดเจน
            -- ถ้ามอนยังอยู่ช่วงต้นที่ทุกเส้นทับกัน จะรอต่อโดยไม่เดา
            if best.Farthest <= 4 and gap >= 0.75 then
                return best.Path, best.Lane, lastSummary
            end
        end

        if progressCallback then progressCallback(lastSummary) end
        task.wait(0.25)
    end

    return nil, nil, "หมดเวลารอเส้นทางที่แยกได้ชัดเจน | " .. lastSummary
end

local function selectedPlacementPath()
    if tostring(_G.AO_PLACE_MODE or "") == "ao_mansion" then
        return activeMansionPath
    end
    return path
end

local function posAndDirectionAt(percent, selectedPath)
    selectedPath = selectedPath or selectedPlacementPath()
    if not selectedPath then return nil end
    local distance = math.clamp(percent, 0, 100) / 100 * selectedPath.Total
    for index = 2, #selectedPath.Points do
        if selectedPath.Cumulative[index] >= distance then
            local startDistance = selectedPath.Cumulative[index - 1]
            local segmentLength = selectedPath.Cumulative[index] - startDistance
            local alpha = segmentLength > 0 and (distance - startDistance) / segmentLength or 0
            local a, b = selectedPath.Points[index - 1], selectedPath.Points[index]
            local direction = b - a
            return a:Lerp(b, alpha), direction.Magnitude > 0 and direction.Unit or Vector3.zAxis
        end
    end
    local last = #selectedPath.Points
    return selectedPath.Points[last], (selectedPath.Points[last] - selectedPath.Points[last - 1]).Unit
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
    local drawTarget = selectedPlacementPath() or path
    if not drawTarget then return false, pathError end

    local folder = Instance.new("Folder")
    folder.Name = "AO_Path_Debug"
    folder.Parent = workspace

    for index = 2, #drawTarget.Points do
        local a = drawTarget.Points[index - 1] + Vector3.new(0, 0.35, 0)
        local b = drawTarget.Points[index] + Vector3.new(0, 0.35, 0)
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
        local position = posAndDirectionAt(percent, drawTarget)
        addPercentLabel(folder, position, tostring(percent) .. "%")
    end

    return true, string.format(
        "เส้นทาง%s %d จุด | %.1f studs",
        drawTarget.Lane and (" " .. tostring(drawTarget.Lane)) or "",
        #drawTarget.Points,
        drawTarget.Total
    )
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
    local selectedPath = selectedPlacementPath()
    local base, direction = posAndDirectionAt(percent, selectedPath)
    if not base then return {} end
    local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit
    local candidates, seen = {}, {}
    local isMansion = tostring(_G.AO_PLACE_MODE or "") == "ao_mansion"
    local params = raycastParams()
    if isMansion then
        local placementParts = workspace:FindFirstChild("PlacementParts")
        local groundPart = placementParts and placementParts:FindFirstChild("Ground", true)
        if groundPart and groundPart:IsA("BasePart") then
            params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {groundPart}
        end
    end
    -- ชิดขอบถนนก่อน แล้วค่อยขยายออกเมื่อพื้นที่เต็ม
    -- Ground ต้องอยู่ชิดขอบทาง ลดโอกาสล้ำเข้าอาคาร/สิ่งกีดขวาง
    -- Infinite Mansion มีทางมอนกว้างกว่าด่านปกติ จึงค้นแบบขยายออกทั้งสองฝั่ง
    -- โดยยังคำนวณจาก PathFolder ทุกจุด ไม่ใช้พิกัดแผนที่ตายตัว
    local offsets = isMansion
        and {4, -4, 5, -5, 6, -6, 8, -8, 10, -10, 12, -12, 14, -14, 16, -16,
             18, -18, 21, -21, 24, -24, 28, -28, 32, -32}
        or {2.25, -2.25, 3, -3, 3.75, -3.75, 4.5, -4.5, 5.25, -5.25}
    local alongs = isMansion and {0, 4, -4, 8, -8} or {0}

    for _, offset in ipairs(offsets) do
        for _, along in ipairs(alongs) do
            local sample = base + perpendicular * offset + direction * along
            local castHeight = isMansion and 40 or 18
            local castDepth = isMansion and 80 or 40
            local hit = workspace:Raycast(
                sample + Vector3.new(0, castHeight, 0),
                Vector3.new(0, -castDepth, 0),
                params
            )
            if hit and hit.Normal.Y >= 0.65
                and math.abs(hit.Position.Y - base.Y) <= (isMansion and 8 or 3.5) then
                local position = hit.Position + hit.Normal * 0.08
                local key = string.format("%.1f:%.1f:%.1f", position.X, position.Y, position.Z)
                if not seen[key] then
                    seen[key] = true
                    candidates[#candidates + 1] = position
                end
            elseif not isMansion then
                candidates[#candidates + 1] = Vector3.new(sample.X, base.Y - 0.1, sample.Z)
            end
            if isMansion and #candidates >= 48 then return candidates end
        end
    end
    return candidates
end

local function hillCandidates(percent)
    local selectedPath = selectedPlacementPath()
    local base, direction = posAndDirectionAt(percent, selectedPath)
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
    -- result = -1 (number) = server ปฏิเสธได้หลายเหตุผล เช่น เงิน/ลิมิต/จุด/สถานะยังไม่พร้อม
    if _G.AO_INVOKE_LOG == nil then _G.AO_INVOKE_LOG = 0 end
    if _G.AO_INVOKE_LOG < 10 then
        _G.AO_INVOKE_LOG += 1
        print(string.format("[AO DBG invoke] T%d result=%s (%s) dt=%.2fวิ", slot, tostring(result), typeof(result), invDt))
    end
    if typeof(result) == "table" then return true, result end
    return false, result
end

local function tryCandidates(slot, candidates, isHill, statusCallback)
    local resilient = usesResilientPlacement()
    local lastResult = nil
    for index, position in ipairs(candidates) do
        statusCallback(string.format("Tower%d %s จุด %d/%d", slot, isHill and "Hill" or "Ground", index, #candidates))
        local placed, result = invokePlacement(slot, position, isHill)
        lastResult = result
        if placed then
            return true, position, result
        end
        if result == -1 and not resilient then
            return false, nil, -1
        end
        task.wait(0.04)
    end
    return false, nil, lastResult
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

local function guiShown(object)
    local node = object
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return true
end

local function normalizedGuiText(object)
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        return tostring(object.Text or ""):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    end
    return ""
end

local function subtreeHasText(root, wanted)
    wanted = tostring(wanted):lower()
    if normalizedGuiText(root) == wanted and guiShown(root) then return true end
    for _, object in ipairs(root:GetDescendants()) do
        if normalizedGuiText(object) == wanted and guiShown(object) then return true end
    end
    return false
end

local function findTextButton(root, wanted)
    wanted = tostring(wanted):lower()
    for _, button in ipairs(root:GetDescendants()) do
        if button:IsA("GuiButton") and guiShown(button)
            and button.Active ~= false and button.AbsoluteSize.X > 10 and button.AbsoluteSize.Y > 10 then
            if normalizedGuiText(button) == wanted or subtreeHasText(button, wanted) then
                return button
            end
        end
    end
    return nil
end

-- กล่องก่อนเริ่มเวฟจากภาพจริง: มี Start Game + Ready และปุ่ม Confirm ใน container เดียวกัน
local function findStartGameConfirmButton()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end

    for _, title in ipairs(playerGui:GetDescendants()) do
        if normalizedGuiText(title) == "start game" and guiShown(title) then
            local container = title.Parent
            for _ = 1, 8 do
                if not container or container == playerGui then break end
                if subtreeHasText(container, "ready") then
                    local confirm = findTextButton(container, "confirm")
                    if confirm then return confirm end
                end
                container = container.Parent
            end
        end
    end
    return nil
end

local function fireGuiConnections(signal)
    local connectionFunction = getconnections
        or (getgenv and type(getgenv) == "function" and getgenv().getconnections)
    if type(connectionFunction) ~= "function" then return false end

    local fired = false
    local ok, connections = pcall(connectionFunction, signal)
    if not ok then return false end
    for _, connection in ipairs(connections) do
        local didFire = false
        if type(connection.Fire) == "function" then
            didFire = pcall(function() connection:Fire() end)
        elseif type(connection.Function) == "function" then
            didFire = pcall(connection.Function)
        end
        fired = fired or didFire
    end
    return fired
end

local function clickStartGameConfirm()
    local button = findStartGameConfirmButton()
    if not button then return false, "not visible" end

    -- จาก UI เกมปุ่มลักษณะนี้ผูก Activated เป็นหลัก
    if fireGuiConnections(button.Activated) then
        task.wait(0.3)
        if not findStartGameConfirmButton() then return true, "Activated connection" end
    end

    if type(firesignal) == "function" then
        local ok = pcall(firesignal, button.Activated)
        if ok then
            task.wait(0.3)
            if not findStartGameConfirmButton() then return true, "firesignal Activated" end
        end
    end

    local activated = pcall(function() button:Activate() end)
    if activated then
        task.wait(0.3)
        if not findStartGameConfirmButton() then return true, "GuiButton:Activate" end
    end

    -- สำรองสุดท้ายสำหรับ executor ที่เรียก connection ไม่ได้: คลิกกึ่งกลางจาก AbsolutePosition
    local center = button.AbsolutePosition + button.AbsoluteSize / 2
    local clicked = pcall(function()
        VIM:SendMouseMoveEvent(center.X, center.Y, game)
        task.wait(0.06)
        VIM:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)
    task.wait(0.35)
    return clicked and not findStartGameConfirmButton(), "mouse"
end

local bestSpeedLevel = nil
local bestSpeedConfirmedAt = 0
local speedSettingInProgress = false

local function setBestGameSpeed()
    if bestSpeedLevel and os.clock() - bestSpeedConfirmedAt < 30 then
        return bestSpeedLevel, "Game Speed ขั้น " .. tostring(bestSpeedLevel) .. " (ยืนยันแล้ว)"
    end

    if speedSettingInProgress then
        local waitStarted = os.clock()
        while speedSettingInProgress and os.clock() - waitStarted < 2 do task.wait(0.05) end
        if bestSpeedLevel and os.clock() - bestSpeedConfirmedAt < 30 then
            return bestSpeedLevel, "Game Speed ขั้น " .. tostring(bestSpeedLevel) .. " (ยืนยันแล้ว)"
        end
    end

    local controls = getSpeedControls()
    if not controls.Two or not controls.Three or not controls.Circle then
        return nil, "ไม่พบปุ่ม Game Speed ครบ"
    end

    speedSettingInProgress = true

    -- ลองขั้น 3 ก่อน แล้วอ่านตำแหน่ง Circle เพื่อยืนยันว่าเกมยอมรับจริง
    activateSpeedButton(controls.Three)
    task.wait(0.8)
    if selectedSpeedLevel(controls) == "Three" then
        bestSpeedLevel = 3
        bestSpeedConfirmedAt = os.clock()
        speedSettingInProgress = false
        return 3, "Game Speed ขั้น 3"
    end

    -- ไม่มีสิทธิ์ขั้น 3 หรือเกมไม่ยอมรับ: กลับมาใช้ขั้น 2
    activateSpeedButton(controls.Two)
    task.wait(0.5)
    if selectedSpeedLevel(controls) == "Two" then
        bestSpeedLevel = 2
        bestSpeedConfirmedAt = os.clock()
        speedSettingInProgress = false
        return 2, "Game Speed ขั้น 2"
    end

    speedSettingInProgress = false
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

local function guiIsActuallyVisible(object)
    local current = object
    while current and current ~= player.PlayerGui do
        if current:IsA("GuiObject") and current.Visible == false then return false end
        if current:IsA("LayerCollector") and current.Enabled == false then return false end
        current = current.Parent
    end
    return true
end

local function isActOverVisible()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local gameUI = playerGui and playerGui:FindFirstChild("GameUI")
    local actOver = gameUI and gameUI:FindFirstChild("ActOver")
    -- ActOver.Visible ของเกมค้าง true หลัง Replay ได้ แต่ parent/ScreenGui ถูกซ่อนแล้ว
    -- เช็กทั้ง ancestor ไม่งั้น Legend จะหยุด Smart Auto ก่อนวางและวน empty field ทุกเวฟ
    return actOver ~= nil and guiIsActuallyVisible(actOver)
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

local function isInNonRewardPanel(object)
    local anc = object
    while anc do
        local name = tostring(anc.Name):lower()
        -- ของรางวัล Anime Origins ใช้ path MainUI.Summon.PopupFrame.ImageLabel จริง
        -- จึงห้ามตัด ancestor ชื่อ Summon ออก ไม่งั้นรางวัลจะค้างและ Replay ไม่เดินต่อ
        if name == "unitmanagerframe" or name == "settingsframe" then
            return true
        end
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
        if (isImage or isViewport) and guiIsActuallyVisible(object)
            and not isInToolbar(object) and not isInNonRewardPanel(object) then
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
local shuffleRng = Random.new()
local resilientCandidateCursors = {}
local expectedHotbarSlots = 0
-- สถานะรอบต้องประกาศก่อน callback เริ่ม Smart Auto เพื่อให้รอบใหม่ล้างค่า Wave เก่าได้ทันที
local lastEmptyFieldRecovery = os.clock()
local roundRecoveryToken = 0
local lastObservedWave = nil
local wasActOverVisible = false

local function resilientCandidateWindow(candidates, key, limit)
    if not usesResilientPlacement() or #candidates <= limit then
        return candidates
    end
    local selected = {}
    local startIndex = resilientCandidateCursors[key] or 1
    for offset = 0, limit - 1 do
        local index = (startIndex + offset - 1) % #candidates + 1
        selected[#selected + 1] = candidates[index]
    end
    resilientCandidateCursors[key] = (startIndex + limit - 1) % #candidates + 1
    return selected
end

local function shuffledCopy(source)
    local result = {}
    for index, value in ipairs(source) do result[index] = value end
    for index = #result, 2, -1 do
        local swapIndex = shuffleRng:NextInteger(1, index)
        result[index], result[swapIndex] = result[swapIndex], result[index]
    end
    return result
end

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
    local progressPath = selectedPlacementPath()
    if not progressPath then return nil end
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local furthest = nil

    for _, enemy in ipairs(enemies:GetChildren()) do
        local root = enemy:FindFirstChild("HumanoidRootPart")
        if not root and enemy:IsA("Model") then root = enemy.PrimaryPart end
        if root and root:IsA("BasePart") then
            local bestDistance = math.huge
            local bestPathDistance = 0

            for index = 2, #progressPath.Points do
                local a, b = progressPath.Points[index - 1], progressPath.Points[index]
                local segment = b - a
                local lengthSquared = segment:Dot(segment)
                local alpha = lengthSquared > 0 and math.clamp((root.Position - a):Dot(segment) / lengthSquared, 0, 1) or 0
                local nearest = a + segment * alpha
                local distance = (root.Position - nearest).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPathDistance = progressPath.Cumulative[index - 1] + segment.Magnitude * alpha
                end
            end

            local percent = bestPathDistance / progressPath.Total * 100
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
        local ground = resilientCandidateWindow(
            groundCandidates(percent),
            tostring(slot) .. ":Auto:Ground",
            1
        )
        local hill = resilientCandidateWindow(
            hillCandidates(percent),
            tostring(slot) .. ":Auto:Hill",
            1
        )
        local resilientAuto = usesResilientPlacement()
        local candidateCount = math.min(resilientAuto and 1 or 6, math.max(#ground, #hill))

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

            -- รอบใหม่ของ Mansion/Gem/Legend อาจคืน -1 ระหว่างที่จุด/สถานะยังไม่พร้อม
            -- จึงหมุน candidate ในรอบถัดไปแทนการสรุปทันทีว่าเงินไม่พอ
            if not resilientAuto and gRes == -1 and (hRes == -1 or not hill[index]) then
                return false, nil, nil, -1
            end
            task.wait(0.04)
        end

        return false, nil, nil, lastRes
    end

    if placementType == "Ground" then
        local candidates = resilientCandidateWindow(
            groundCandidates(percent),
            tostring(slot) .. ":Ground",
            2
        )
        local ok, position, res = tryCandidates(slot, candidates, false, setStatus)
        if ok then return true, "Ground", position, res end
        return false, nil, nil, res
    end
    if placementType == "Hill" then
        local candidates = resilientCandidateWindow(
            hillCandidates(percent),
            tostring(slot) .. ":Hill",
            2
        )
        local ok, position, res = tryCandidates(slot, candidates, true, setStatus)
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
    if usesResilientPlacement() then
        -- ยกเลิก recovery ที่ตั้งจากรอบเก่า และตั้ง baseline เป็น Wave ปัจจุบัน
        -- กัน race: รอบเก่า Wave 7 -> รอบใหม่ Wave 0 แล้ว monitor มายกเลิก generation ใหม่
        roundRecoveryToken += 1
        lastObservedWave = readCurrentWave()
        wasActOverVisible = isActOverVisible()
    end
    smartPlanIndex = 1
    resilientCandidateCursors = {}
    for slot = 1, 6 do
        slotPlaced[slot] = 0
        slotFailures[slot] = 0
        slotTypes[slot] = nil
    end
    allButton.Text = "STOP SMART AUTO"
    allButton.BackgroundColor3 = Color3.fromRGB(174, 60, 72)

    task.spawn(function()
        local placeMode = tostring(_G.AO_PLACE_MODE or "")
        local isLegend = placeMode == "ao_legend"
        local isGem = placeMode == "ao_gem"
        local isMansion = placeMode == "ao_mansion"
        local isScriptedRound = isLegend or isGem or isMansion
        local function stillRunning()
            return smartRunning and myGeneration == smartGeneration
                and (not isScriptedRound or not isActOverVisible())
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

        -- Replay จะมีช่วง Wave 0 ซึ่ง Towers/เงิน/สนามยังรีเซ็ตไม่เสร็จ
        -- ห้ามเริ่มวางในช่วงนี้ เพราะ monitor อาจเห็น transition ของรอบเก่าและยกเลิกงานใหม่
        if isScriptedRound then
            local waveWaitStarted = os.clock()
            local currentWave = readCurrentWave()
            while stillRunning() and (not currentWave or currentWave <= 0)
                and os.clock() - waveWaitStarted < 20 do
                setStatus("รอรอบใหม่เริ่ม Wave 1...")
                task.wait(0.2)
                currentWave = readCurrentWave()
            end
            if not stillRunning() then return end
            if not currentWave or currentWave <= 0 then
                smartRunning = false
                placing = false
                allButton.Text = "START SMART AUTO"
                allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
                dbg("ยังเป็น Wave 0 เกิน 20 วิ — หยุดรอ monitor เริ่มใหม่เมื่อ Wave 1")
                return
            end
            lastObservedWave = currentWave
            dbg("รอบพร้อมแล้ว Wave " .. tostring(currentWave) .. " → เริ่มวาง")
        end

        local speedLevel, speedMessage = setBestGameSpeed()
        dbg("ตั้ง game speed: " .. tostring(speedMessage))
        setStatus(speedMessage, speedLevel ~= nil)
        task.wait(0.15)

        -- Legend/Gem/Mansion คุมลำดับอัพเกรดเอง: ปิด AutoUpgradeOnPlacement ก่อนวางตัวแรก
        -- ไม่ให้เกมกินเงินไปอัพดาเมจก่อนตัวเงินและชุดดักหน้ามอนพร้อม
        if isLegend or isGem or isMansion then
            local modeLabel = isLegend and "Legend" or (isMansion and "Mansion" or "Gem")
            local autoUpgradeDisabled = _G.AO_AUTO_UPGRADE_CONFIRMED_OFF == true
            if autoUpgradeDisabled then
                dbg("[" .. modeLabel .. "] AutoUpgradeOnPlacement ยืนยัน OFF จากตัวควบคุมหลักแล้ว")
            elseif type(_G.AO_SET_TOGGLE) == "function" then
                for attempt = 1, 3 do
                    local called, result = pcall(_G.AO_SET_TOGGLE, "AutoUpgradeOnPlacement", false)
                    autoUpgradeDisabled = called and result == true
                    dbg(string.format("[%s] ปิด AutoUpgradeOnPlacement ในด่าน รอบ %d = %s",
                        modeLabel, attempt, tostring(autoUpgradeDisabled)))
                    if autoUpgradeDisabled then break end
                    task.wait(0.5)
                end
                if autoUpgradeDisabled then _G.AO_AUTO_UPGRADE_CONFIRMED_OFF = true end
            else
                dbg("[" .. modeLabel .. "] ไม่พบ AO_SET_TOGGLE ในด่าน")
            end

            -- ห้ามวางแม้แต่ตัวแรกถ้ายังยืนยันไม่ได้ เพราะ Auto Upgrade ของเกมจะแย่งเงิน
            if not autoUpgradeDisabled then
                if myGeneration ~= smartGeneration then return end
                smartRunning = false
                allButton.Text = "START SMART AUTO"
                allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
                setStatus("ยังปิด Auto Upgrade ของเกมไม่ได้ — ยังไม่เริ่มวางตัว", false)
                placing = false
                warn("[AO PLACE v" .. TEST_VERSION .. "] STOP: AutoUpgradeOnPlacement is not confirmed OFF")
                return
            end
        end

        -- Mansion ใช้ผล Victory/Defeat เลือก Next หรือ Replay เอง
        -- ยืนยันซ้ำตรงโมดูลวางตัวเพื่อกัน Auto Replay ของเกมกลับมาเปิดระหว่างโหลดด่าน
        if isMansion then
            local autoReplayDisabled = false
            if type(_G.AO_SET_TOGGLE) == "function" then
                for attempt = 1, 3 do
                    local called, result = pcall(_G.AO_SET_TOGGLE, "AutoReplayGame", false)
                    autoReplayDisabled = called and result == true
                    dbg(string.format("[Mansion] ปิด AutoReplayGame ในด่าน รอบ %d = %s",
                        attempt, tostring(autoReplayDisabled)))
                    if autoReplayDisabled then break end
                    task.wait(0.5)
                end
            end
            if not autoReplayDisabled then
                if myGeneration ~= smartGeneration then return end
                smartRunning = false
                allButton.Text = "START SMART AUTO"
                allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
                setStatus("ยังปิด Auto Replay ของเกมไม่ได้ — ยังไม่เริ่ม Mansion", false)
                placing = false
                warn("[AO PLACE v" .. TEST_VERSION .. "] STOP: AutoReplayGame is not confirmed OFF")
                return
            end

            -- หอคอยควรขายตัวเงินอัตโนมัติในเวฟท้าย เพื่อนำเงินไปอัปตัวดาเมจ
            -- ถ้ายืนยันค่าไม่ได้ยังให้เล่นต่อได้ เพราะไม่ใช่เงื่อนไขบังคับก่อนเริ่มวางตัว
            local sellFarmsEnabled = false
            if type(_G.AO_SET_TOGGLE) == "function" then
                for attempt = 1, 3 do
                    local called, result = pcall(_G.AO_SET_TOGGLE, "SellFarms", true)
                    sellFarmsEnabled = called and result == true
                    dbg(string.format("[Mansion] เปิด SellFarms ในด่าน รอบ %d = %s",
                        attempt, tostring(sellFarmsEnabled)))
                    if sellFarmsEnabled then break end
                    task.wait(0.5)
                end
            end
            if not sellFarmsEnabled then
                warn("[AO PLACE v" .. TEST_VERSION .. "] Mansion: ยังยืนยัน SellFarms=ON ไม่ได้ — เล่นต่อ")
            end
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
            -- อ่านครั้งแรกก่อนเช็ก stillRunning เพื่อไม่ให้ log เป็น -1 ทั้งที่ T1-T6 พร้อม
            local firstCount = countUnitSlots()
            local lastCount, maxCount, stableSince = firstCount, firstCount, os.clock()
            while stillRunning() and os.clock() - waitStart < 10 do
                local c = countUnitSlots()
                if c ~= lastCount then
                    lastCount = c
                    stableSince = os.clock()
                end
                if c > maxCount then maxCount = c end
                -- ทีมครบ 6 ช่องตามที่ระบบรองรับแล้ว เริ่มทันที ไม่เสียเวลารอซ้ำอีก 2 วินาที
                -- ถ้าทีมมีน้อยกว่า 6 ช่อง ยังใช้ baseline/ความนิ่งเดิมเพื่อกันอ่าน hotbar ไม่ครบ
                if c >= 6
                    or (expectedHotbarSlots > 0 and c >= expectedHotbarSlots
                        and os.clock() - stableSince >= 0.4)
                    or (expectedHotbarSlots == 0 and c > 0 and os.clock() - stableSince >= 2) then
                    break
                end
                setStatus(string.format("รอ hotbar โหลดยูนิต... (%d/%d ช่อง)", c, expectedHotbarSlots))
                task.wait(0.2)
            end
            expectedHotbarSlots = math.max(expectedHotbarSlots, maxCount)
            dbg(string.format("hotbar พร้อม: %d ช่อง | คาดหวัง=%d [%s]",
                lastCount, expectedHotbarSlots, hotbarSnap()))
            if lastCount <= 0 then
                if myGeneration ~= smartGeneration then return end
                smartRunning = false
                allButton.Text = "START SMART AUTO"
                allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
                setStatus("hotbar ยังไม่พร้อม — รอระบบเริ่มใหม่", false)
                placing = false
                return
            end
        end

        local function queueOne(slot, placementType, percent, label)
            if not stillRunning() then return false end
            placing = true
            setStatus(string.format("%s | Tower%d @ %.1f%%", label, slot, percent))
            local t0 = os.clock()
            local ok, kind, position, result = placeSlot(slot, placementType, percent)
            local took = os.clock() - t0
            placing = false
            local rejectedReason = isScriptedRound and "[server ปฏิเสธ: เงิน/ลิมิต/จุด/สถานะ]" or "[เงินไม่พอ]"
            local reason = ok and ("สำเร็จ " .. tostring(kind))
                or ("ไม่ติด" .. (result == -1 and rejectedReason or "[จุดผิด/เต็ม]"))
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
            return false, result
        end

        -- Infinite Mansion ใช้แผนวางเฉพาะโหมด ห้ามไหลเข้าโลจิค Gem/Legend/ด่านทั่วไป:
        -- 1) วาง Leo 3 ตัวทันทีบนช่วงทางเข้าร่วม เพื่อให้ตัวแรกลงตั้งแต่ Wave 1
        -- 2) ตรวจเส้นที่มอนเดินจริง แล้ววาง Bluma 1 ตัว
        -- 3) วางดาเมจช่วง 60-80% ให้ได้ 5 ตัวก่อน
        -- 4) อัป Leo ทั้ง 3 ตัว MAX
        -- 5) อัป Bluma ถึง 4/6 แล้วอัป Aneko/Vegita ถึง 8/10 ทีละตัว ก่อนสุ่มอัปตัวอื่น
        if isMansion then
            local function mansionEnded()
                return isActOverVisible()
            end

            local function mansionUnitManager()
                local ok, scrolling = pcall(function()
                    return player.PlayerGui.GameUI.ManagementFrame.UnitManagerFrame.Main.CanvasGroup.ScrollingFrame
                end)
                return ok and scrolling or nil
            end

            local function mansionPlacedUnits()
                local units = {}
                local scrolling = mansionUnitManager()
                if not scrolling then return units end
                for _, card in ipairs(scrolling:GetChildren()) do
                    if card:IsA("GuiObject") and #card.Name >= 30 and card.Name:find("%-") then
                        local unitName = ""
                        pcall(function()
                            unitName = tostring(card.Main.TowerButton.ImageLabel.Info.NameLabel.Text)
                        end)
                        units[#units + 1] = {
                            uuid = card.Name,
                            name = unitName,
                            towerName = tostring(card:GetAttribute("TowerName") or ""),
                        }
                    end
                end
                return units
            end

            local function mansionTowerMaxed(uuid)
                local scrolling = mansionUnitManager()
                local card = scrolling and scrolling:FindFirstChild(uuid)
                if not card then return false end
                for _, object in ipairs(card:GetDescendants()) do
                    if object:IsA("TextLabel") and tostring(object.Text):upper() == "MAX" then
                        return true
                    end
                end
                return false
            end

            local function mansionTowerUpgradeLevel(uuid)
                local scrolling = mansionUnitManager()
                local card = scrolling and scrolling:FindFirstChild(uuid)
                if not card then return nil, nil end
                for _, object in ipairs(card:GetDescendants()) do
                    if object:IsA("TextLabel") or object:IsA("TextButton") then
                        local current, maximum = tostring(object.Text):match("[Uu]pgrade%s*(%d+)%s*/%s*(%d+)")
                        if current and maximum then
                            return tonumber(current), tonumber(maximum)
                        end
                    end
                end
                return nil, nil
            end

            local function mansionUpgradeOnce(uuid)
                if not placeRemote then return false end
                local ok, result = pcall(function()
                    return placeRemote:InvokeServer("UpgradeTower", uuid)
                end)
                return ok and result == true
            end

            local function mansionUpgradeBatch(units, maxCount)
                local launched = math.min(#units, maxCount)
                if launched <= 0 then return 0 end
                local completed = 0
                local successes = 0
                for index = 1, launched do
                    local uuid = units[index].uuid
                    task.spawn(function()
                        if mansionUpgradeOnce(uuid) then successes += 1 end
                        completed += 1
                    end)
                end
                local started = os.clock()
                while completed < launched and os.clock() - started < 8 do
                    task.wait(0.02)
                end
                return successes
            end

            local function exactName(actual, expected)
                return tostring(actual):lower() == tostring(expected):lower()
            end

            local function internalName(unit, expected)
                return exactName(unit and unit.towerName, expected)
            end

            -- ชื่อภายในที่ยืนยันจาก Dump จริง ไม่อิงชื่อแสดงผลและไม่อิงเลขช่อง
            -- Hotbar/Workspace: Vegeta_Evolved, Unit Manager: VegetaSSJ_Evolved
            local PRIORITY_INTERNAL_NAMES = {
                ["akeno_evolved"] = true,
                ["vegeta_evolved"] = true,
                ["vegetassj_evolved"] = true,
            }
            local function isPriorityDamage(unit)
                return PRIORITY_INTERNAL_NAMES[tostring(unit and unit.towerName or ""):lower()] == true
            end

            local leoSlot = findSlotByUnitName("Leorio")
            local bulmaSlot = findSlotByUnitName("Bulma")
            local akenoSlot = findSlotByUnitName("Akeno_Evolved")
            local vegetaSlot = findSlotByUnitName("Vegeta_Evolved")
            if leoSlot then slotTypes[leoSlot] = "Ground" end

            local function countPlacedInternal(towerName)
                local count = 0
                for _, unit in ipairs(mansionPlacedUnits()) do
                    if internalName(unit, towerName) then count += 1 end
                end
                return count
            end

            dbg(string.format("[Mansion 1] ตัวเงิน Leorio=%s | Bulma=%s",
                leoSlot and ("Tower" .. leoSlot .. " x3") or "ไม่มี",
                bulmaSlot and ("Tower" .. bulmaSlot .. " x1") or "ไม่มี"))

            local moneyPercents = {30, 34, 38, 42, 46, 26, 50, 22}
            local moneyPercentIndex = 1
            local function placeNamed(slot, placedName, target, placementType, label, timeoutSeconds)
                if not slot then return 0 end
                local started = os.clock()
                while stillRunning() and not mansionEnded()
                    and (slotPlaced[slot] or 0) < target
                    and os.clock() - started < timeoutSeconds do
                    local percent = moneyPercents[moneyPercentIndex]
                    moneyPercentIndex = moneyPercentIndex % #moneyPercents + 1
                    local current = slotPlaced[slot] or 0
                    local ok, result = queueOne(
                        slot,
                        placementType,
                        percent,
                        string.format("%s %d/%d", label, current + 1, target)
                    )
                    if not ok then task.wait(result == -1 and 0.8 or 0.25) end
                end
                return slotPlaced[slot] or 0
            end

            local function upgradeNamedToMax(towerName, target, label)
                if target <= 0 then return 0 end
                local upgradeCount = 0
                local started = os.clock()
                while stillRunning() and not mansionEnded() and os.clock() - started < 300 do
                    local matched = {}
                    for _, unit in ipairs(mansionPlacedUnits()) do
                        if internalName(unit, towerName) then matched[#matched + 1] = unit end
                    end
                    local allReady = #matched >= target
                    local pending = {}
                    for _, unit in ipairs(matched) do
                        if not mansionTowerMaxed(unit.uuid) then
                            allReady = false
                            pending[#pending + 1] = unit
                        end
                    end
                    if allReady then break end
                    local upgraded = mansionUpgradeBatch(pending, target)
                    if upgraded > 0 then
                        upgradeCount += upgraded
                        setStatus(string.format("[Mansion] อัป %s พร้อมกัน +%d | รวม %d ครั้ง",
                            label, upgraded, upgradeCount))
                    end
                    task.wait(upgraded > 0 and 0.06 or 0.35)
                end
                return upgradeCount
            end

            -- วาง Leo ก่อนตรวจเส้น โดยใช้เฉพาะช่วงทางเข้าที่ทั้ง 7 เส้นใช้ร่วมกัน
            -- ตัวแรกจึงลงได้ตั้งแต่ Wave 1 โดยไม่ต้องเดาว่าชั้นนี้สุ่มเลนไหน
            activeMansionPath = mansionEntrancePath
            activeMansionLane = nil
            if leoSlot and not activeMansionPath then
                if myGeneration ~= smartGeneration then return end
                smartRunning = false
                allButton.Text = "START SMART AUTO"
                allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
                setStatus("[Mansion] ไม่พบช่วงทางเข้าร่วม — ไม่เดาจุดวาง Leo", false)
                placing = false
                return
            end
            local leoPlaced = placeNamed(leoSlot, "Leo", 3, "Ground", "Mansion Leo", 120)
            dbg(string.format("[Mansion 1] วาง Leo ช่วงทางเข้าร่วม %d/3 | wave=%s",
                leoPlaced, tostring(readCurrentWave() or "?")))

            -- ถ้าไอดีไม่มี Leo แต่มี Bluma ให้ Bluma เป็นตัวแรกบน Wave 1 แทน
            local bulmaPlacedBeforeRoute = 0
            if not leoSlot and bulmaSlot then
                bulmaPlacedBeforeRoute = placeNamed(
                    bulmaSlot, "Bluma", 1, "Auto", "Mansion Bluma ตัวแรก", 120
                )
                dbg(string.format("[Mansion 1] ไม่มี Leo — วาง Bluma ช่วงทางเข้าร่วม %d/1",
                    bulmaPlacedBeforeRoute))
            end

            -- หลัง Leo ลงแล้ว มอนมีเวลาถึงทางแยก จึงตรวจเส้นจริงของชั้นนี้
            activeMansionPath = nil
            setStatus("[Mansion] รอดูเส้นทางที่มอนเดินจริง...")
            local detectedPath, detectedLane, routeMessage
            while stillRunning() and not mansionEnded() and not detectedPath do
                detectedPath, detectedLane, routeMessage = detectActiveMansionPath(
                    12,
                    stillRunning,
                    function(message)
                        setStatus("[Mansion] กำลังหาเส้นทาง | " .. tostring(message))
                    end
                )
                if not detectedPath and stillRunning() and not mansionEnded() then
                    warn("[AO Mansion PATH] ยังแยกเส้นไม่ได้ จะรอดูมอนต่อ | " .. tostring(routeMessage))
                    task.wait(0.25)
                end
            end
            if not detectedPath then
                if myGeneration ~= smartGeneration then return end
                smartRunning = false
                allButton.Text = "START SMART AUTO"
                allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
                setStatus("[Mansion] ด่านจบก่อนพบเส้นทาง", false)
                placing = false
                return
            end
            activeMansionPath = detectedPath
            activeMansionLane = detectedLane
            dbg(string.format("[Mansion PATH] เลือกเส้น %d | %s",
                activeMansionLane, tostring(routeMessage)))
            setStatus(string.format("[Mansion] พบเส้นที่มอนเดิน: เส้น %d", activeMansionLane), true)

            -- วาง Bluma หลัง Leo แต่ยังไม่อัปเกรด
            local bulmaPlaced = placeNamed(bulmaSlot, "Bluma", 1, "Auto", "Mansion Bluma", 120)
            dbg(string.format("[Mansion 2] วาง Bluma %d/1 — ยังไม่อัป", bulmaPlaced))

            local damageSlots = {}
            for slot = 1, 6 do
                if slot ~= leoSlot and slot ~= bulmaSlot and slotHasUnit(slot) then
                    damageSlots[#damageSlots + 1] = slot
                end
            end
            dbg("[Mansion 3] ช่องดาเมจ " .. #damageSlots .. " ช่อง [Tower"
                .. table.concat(damageSlots, ",Tower") .. "]")

            local priorityDamageSlots = {}
            if akenoSlot then priorityDamageSlots[#priorityDamageSlots + 1] = akenoSlot end
            if vegetaSlot and vegetaSlot ~= akenoSlot then
                priorityDamageSlots[#priorityDamageSlots + 1] = vegetaSlot
            end
            dbg(string.format("[Mansion 3] ตัวแบกภายใน Akeno_Evolved=%s | Vegeta_Evolved=%s",
                akenoSlot and ("Tower" .. akenoSlot) or "ไม่มี",
                vegetaSlot and ("Tower" .. vegetaSlot) or "ไม่มี"))

            -- วางตำแหน่งดาเมจตามระยะทางมอนช่วง 60-80%
            -- เส้นสั้นจะหมุนลองจุดรอบข้างทั้งหมด แต่ลองครั้งละ 1-2 จุดเพื่อไม่ให้ InvokeServer บล็อกนาน
            local damagePercents = {60, 62, 64, 66, 68, 70, 72, 74, 76, 78, 80, 61, 65, 69, 73, 77, 79}
            local damagePercentIndex = 1
            local function placeDamageSlot(slot, phaseLabel)
                local percent = damagePercents[damagePercentIndex]
                damagePercentIndex = damagePercentIndex % #damagePercents + 1
                return queueOne(
                    slot,
                    slotTypes[slot] or "Auto",
                    percent,
                    phaseLabel .. " 60-80%"
                )
            end

            local function placeDamageBatch(targetCount, timeoutSeconds, phaseLabel)
                if #damageSlots == 0 or targetCount <= 0 then return 0 end
                local placedCount = 0
                local started = os.clock()
                local noPointRounds = 0
                while stillRunning() and not mansionEnded()
                    and placedCount < targetCount
                    and os.clock() - started < timeoutSeconds
                    and noPointRounds < 5 do
                    local placedThisRound = false
                    local moneyBlocked = false
                    for _, slot in ipairs(shuffledCopy(damageSlots)) do
                        if not stillRunning() or mansionEnded() or placedCount >= targetCount then break end
                        local ok, result = placeDamageSlot(slot, phaseLabel)
                        if ok then
                            placedThisRound = true
                            placedCount += 1
                        elseif result == -1 then
                            moneyBlocked = true
                        end
                    end
                    if placedThisRound then
                        noPointRounds = 0
                    elseif moneyBlocked then
                        setStatus("[Mansion] Server ปฏิเสธจุดนี้ — รอสั้น ๆ แล้วลองจุดอื่น")
                        task.wait(0.8)
                    else
                        noPointRounds += 1
                        task.wait(0.3)
                    end
                end
                return placedCount
            end

            -- ให้ Aneko/Vegita ที่มีในทีมลงสนามอย่างน้อยชนิดละหนึ่งตัวก่อน
            -- เพื่อรับประกันว่าหลังอัปตัวเงินแล้วจะมีตัวแบกให้อัป 8/10 ได้ทันที
            local openingDamage = 0
            for _, slot in ipairs(priorityDamageSlots) do
                if openingDamage >= 5 then break end
                local started = os.clock()
                local before = slotPlaced[slot] or 0
                while stillRunning() and not mansionEnded()
                    and (slotPlaced[slot] or 0) <= before
                    and os.clock() - started < 45 do
                    local ok, result = placeDamageSlot(slot, "Mansion ตัวแบกชุดแรก")
                    if ok then
                        openingDamage += 1
                        break
                    end
                    task.wait(result == -1 and 0.8 or 0.25)
                end
            end
            openingDamage += placeDamageBatch(5 - openingDamage, 150, "Mansion ดาเมจชุดแรก")
            dbg(string.format("[Mansion 4] ดาเมจชุดแรก %d/5 ตัว", openingDamage))

            -- จากนั้นอัป Leo ทั้ง 3 ตัวให้ MAX
            local leoUpgradeCount = upgradeNamedToMax("Leorio", leoSlot and 3 or 0, "Leo")
            dbg("[Mansion 5] Leo MAX ครบ/หมดเวลา | อัป " .. leoUpgradeCount .. " ครั้ง")

            -- หลัง Leo MAX ให้ทำทุกอย่างต่อเนื่องจนด่านจบ:
            -- วางดาเมจทีละตัว + อัป Bluma 4/6 ก่อน แล้วจึงอัปตัวแบกและดาเมจอื่น
            -- ไม่รอขั้นวางดาเมจ 180 วินาทีให้จบก่อนเหมือนเวอร์ชันเก่า
            local remainingDamage = 0
            local bulmaUpgradeCount = 0
            local damageUpgradeCount = 0

            local function namedReachedStage(towerName, target, targetStage)
                if target <= 0 then return true end
                local matched, ready = 0, 0
                for _, unit in ipairs(mansionPlacedUnits()) do
                    if internalName(unit, towerName) then
                        matched += 1
                        local current = mansionTowerUpgradeLevel(unit.uuid)
                        if current and current >= targetStage then ready += 1 end
                    end
                end
                return matched >= target and ready >= target
            end

            local function upgradeOneNamed(towerName, targetStage)
                for _, unit in ipairs(mansionPlacedUnits()) do
                    if internalName(unit, towerName) then
                        local current = mansionTowerUpgradeLevel(unit.uuid)
                        if current and current < targetStage then
                            return mansionUpgradeOnce(unit.uuid)
                        end
                    end
                end
                return false
            end

            -- ล็อกตัวแบกทีละ UUID: อัปตัวแรกถึง 8/10 ก่อน แล้วค่อยเปลี่ยนตัว
            local activePriorityUuid = nil
            local function upgradePriorityDamageStep()
                local units = mansionPlacedUnits()
                local selected = nil
                local foundAkeno = false
                local foundVegeta = false
                for _, unit in ipairs(units) do
                    if internalName(unit, "Akeno_Evolved") then foundAkeno = true end
                    if internalName(unit, "Vegeta_Evolved")
                        or internalName(unit, "VegetaSSJ_Evolved") then
                        foundVegeta = true
                    end
                end
                if activePriorityUuid then
                    for _, unit in ipairs(units) do
                        if unit.uuid == activePriorityUuid and isPriorityDamage(unit) then
                            local current = mansionTowerUpgradeLevel(unit.uuid)
                            if current and current < 8 then selected = unit end
                            break
                        end
                    end
                    if not selected then activePriorityUuid = nil end
                end
                if not selected then
                    for _, unit in ipairs(units) do
                        if isPriorityDamage(unit) then
                            local current = mansionTowerUpgradeLevel(unit.uuid)
                            if current and current < 8 then
                                selected = unit
                                activePriorityUuid = unit.uuid
                                break
                            end
                        end
                    end
                end
                if not selected then
                    -- ถ้ามีตัวแบกในทีมแต่ Unit Manager ยังไม่เห็นตัวที่วาง ห้ามข้ามไปสุ่มอัปตัวอื่น
                    -- ลูปวางด้านนอกจะพยายามวางต่อ แล้วรอบถัดไปจึงกลับมาตรวจชื่อภายในใหม่
                    if (akenoSlot and not foundAkeno) or (vegetaSlot and not foundVegeta) then
                        return false, true
                    end
                    return false, false
                end

                local current = mansionTowerUpgradeLevel(selected.uuid)
                local upgraded = mansionUpgradeOnce(selected.uuid)
                if upgraded then
                    damageUpgradeCount += 1
                    setStatus(string.format("[Mansion] อัปตัวแบก %s %d/10 → เป้าหมาย 8/10",
                        tostring(selected.towerName), tonumber(current) or 0))
                end
                return upgraded, true
            end

            local function upgradeDamagePass(maxSuccess)
                local pending = {}
                for _, unit in ipairs(mansionPlacedUnits()) do
                    if not internalName(unit, "Leorio") and not internalName(unit, "Bulma")
                        and not isPriorityDamage(unit)
                        and not mansionTowerMaxed(unit.uuid) then
                        pending[#pending + 1] = unit
                    end
                end
                local successCount = mansionUpgradeBatch(shuffledCopy(pending), maxSuccess)
                if successCount > 0 then
                    damageUpgradeCount += successCount
                    setStatus(string.format(
                        "[Mansion] วางต่อเนื่อง + อัปดาเมจพร้อมกัน +%d | รวม %d ครั้ง",
                        successCount,
                        damageUpgradeCount
                    ))
                end
                return successCount
            end

            local function continuousUpgradeStep()
                local bulmaReady = namedReachedStage("Bulma", bulmaSlot and 1 or 0, 4)
                if not bulmaReady then
                    if upgradeOneNamed("Bulma", 4) then
                        bulmaUpgradeCount += 1
                        setStatus(string.format("[Mansion] วางต่อเนื่อง + อัป Bluma ถึง 4/6 | %d ครั้ง",
                            bulmaUpgradeCount))
                        return true
                    end
                    return false
                end

                local priorityUpgraded, priorityPending = upgradePriorityDamageStep()
                if priorityPending then return priorityUpgraded end
                return upgradeDamagePass(3) > 0
            end

            -- อัปหลายขั้นติดกันก่อนกลับไปหาจุดวางใหม่ เพราะการลองจุดวางหนึ่งครั้ง
            -- อาจบล็อก InvokeServer หลายวินาที โดยเฉพาะเมื่อสนามเริ่มเต็ม
            local function continuousUpgradeBurst(maxCycles)
                local completed = 0
                while stillRunning() and not mansionEnded() and completed < maxCycles do
                    if not continuousUpgradeStep() then break end
                    completed += 1
                    -- รอ Replica/UI เปลี่ยนขั้นก่อนอ่าน Upgrade x/y รอบถัดไป
                    -- ป้องกัน Bluma หรือ Priority ถูกยิง Remote เกินเป้าหมาย
                    task.wait(0.12)
                end
                return completed
            end

            local continuousRounds = 0
            local damageSlotIndex = 1
            dbg("[Mansion 6] เริ่มลูปต่อเนื่อง: Bluma 4/6 → Aneko/Vegita 8/10 → สุ่มอัปตัวอื่น")
            while stillRunning() and not mansionEnded() do
                continuousRounds += 1
                local didWork = false
                local moneyBlocked = false

                -- ให้งานอัปเกรดมาก่อนสูงสุด 5 ชุดต่อรอบ เมื่อยังอัปได้จะไม่เสียเวลา
                -- ไปลองจุดวางซึ่งช้ากว่า ทำให้ Bluma/ตัวแบก/ดาเมจทำงานต่อเนื่อง
                local upgradeCycles = continuousUpgradeBurst(5)
                if upgradeCycles > 0 then didWork = true end

                -- ค่อยวางเพิ่มเมื่อรอบนี้ไม่มีตัวที่อัปสำเร็จแล้ว
                if upgradeCycles == 0 and #damageSlots > 0 then
                    local slot = nil
                    for _, prioritySlot in ipairs(priorityDamageSlots) do
                        if (slotPlaced[prioritySlot] or 0) < 1 then
                            slot = prioritySlot
                            break
                        end
                    end
                    if not slot then
                        local shuffledSlots = shuffledCopy(damageSlots)
                        damageSlotIndex = damageSlotIndex % #shuffledSlots + 1
                        slot = shuffledSlots[damageSlotIndex]
                    end
                    local ok, result = placeDamageSlot(slot, "Mansion วางต่อเนื่อง")
                    if ok then
                        didWork = true
                        remainingDamage += 1
                    elseif result == -1 then
                        moneyBlocked = true
                    end
                end

                if didWork then
                    task.wait(0.08)
                elseif moneyBlocked then
                    task.wait(0.45)
                else
                    task.wait(math.min(2, 0.25 + continuousRounds * 0.02))
                end
            end
            dbg(string.format(
                "[Mansion 7] จบลูปต่อเนื่อง | วางเพิ่ม=%d อัป Bluma=%d อัปดาเมจ=%d",
                remainingDamage, bulmaUpgradeCount, damageUpgradeCount
            ))

            if myGeneration ~= smartGeneration then return end
            smartRunning = false
            allButton.Text = "SMART AUTO COMPLETE"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            status.Text = string.format("Mansion เสร็จ | Leo=%d/3 Bluma=%d/1 (4/6) | ดาเมจ 60-80%%",
                countPlacedInternal("Leorio"), countPlacedInternal("Bulma"))
            status.TextColor3 = Color3.fromRGB(124, 225, 151)
            placing = false
            dbg(string.format("========== MANSION COMPLETE | Leo=%d Bluma=%d | อัปเงิน=%d อัปดาเมจ=%d ==========" ,
                countPlacedInternal("Leorio"), countPlacedInternal("Bulma"),
                leoUpgradeCount + bulmaUpgradeCount, damageUpgradeCount))
            return
        end

        -- ตัวเงินใน hotbar ใช้ internal name จริง: Leorio / Bulma
        -- Gem: มีทั้งคู่เปิดด้วย Leo เท่านั้น; Bulma เก็บไปวางพร้อมชุดดาเมจภายหลัง
        local leoSlot = findSlotByUnitName("Leorio")
        local bulmaSlot = isGem and findSlotByUnitName("Bulma") or nil
        local moneySlot = leoSlot
        local initialMoneyName = leoSlot and "Leorio" or nil
        local initialMoneyPlacedName = leoSlot and "Leo" or nil
        local initialMoneyTarget = leoSlot and 3 or 0
        local deferredBulmaSlot = nil
        if isGem and not leoSlot and bulmaSlot then
            moneySlot = bulmaSlot
            initialMoneyName = "Bulma"
            initialMoneyPlacedName = "Bluma"
            initialMoneyTarget = 1
        elseif isGem and leoSlot and bulmaSlot then
            deferredBulmaSlot = bulmaSlot
        end
        local hasBothMoney = isGem and leoSlot ~= nil and bulmaSlot ~= nil

        dbg(string.format("[1] ตัวเงิน: Leorio=%s | Bulma=%s | เปิดด้วย=%s x%d",
            leoSlot and ("Tower" .. leoSlot) or "ไม่พบ",
            bulmaSlot and ("Tower" .. bulmaSlot) or "ไม่พบ",
            tostring(initialMoneyName or "ไม่มี"), initialMoneyTarget))

        if moneySlot and initialMoneyTarget > 0 then
            if initialMoneyName == "Leorio" then slotTypes[moneySlot] = "Ground" end
            local moneyQueued = 0
            local moneyStart = os.clock()
            local moneyPercents = {30, 33, 36, 39, 42, 45, 48, 27, 24}
            local moneyIdx = 1
            -- Legend ต้องยืนยัน Leo 3 ตัวก่อนเหมือน Mansion; Server อาจปฏิเสธจุดชั่วคราว
            -- จึงหมุน candidate ต่อ ไม่เลิกหลังวางสำเร็จเพียงตัวเดียว
            local moneyCap = isLegend and 30 or (isGem and 20 or 15)
            while stillRunning() and moneyQueued < initialMoneyTarget and os.clock() - moneyStart < moneyCap do
                local percent = moneyPercents[moneyIdx]
                moneyIdx = moneyIdx % #moneyPercents + 1
                local placementType = initialMoneyName == "Leorio" and "Ground" or "Auto"
                local placedMoney = queueOne(moneySlot, placementType, percent,
                    initialMoneyName .. " ตัวเงิน " .. (moneyQueued + 1) .. "/" .. initialMoneyTarget)
                if placedMoney then
                    moneyQueued += 1
                else
                    task.wait(isLegend and 0.25 or 0.6)
                end
            end
            dbg("[1] " .. initialMoneyName .. " จองได้ " .. moneyQueued .. "/" .. initialMoneyTarget
                .. " → ไปวางตัวดาเมจต่อ")
        else
            setStatus("ไม่พบตัวเงิน — วางตัวดาเมจแทน")
        end

        local damageSlots = {}
        for slot = 1, 6 do
            if slot ~= moneySlot and slot ~= deferredBulmaSlot and slotHasUnit(slot) then
                damageSlots[#damageSlots + 1] = slot
            end
        end
        dbg("[2] ตัวดาเมจ: " .. #damageSlots .. " ช่อง [Tower" .. table.concat(damageSlots, ",Tower") .. "]")

        if #damageSlots == 0 then
            dbg("❌ STOP: ไม่มีตัวดาเมจในช่องที่เหลือ")
            if myGeneration ~= smartGeneration then return end
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
            -- ⭐ อัพเกรดเอง (auto-upgrade เกมปิดแล้ว) — helpers ต้องนิยามก่อน เพื่ออัพเกรด "ขนาน" กับการวาง
            --    (เดิมอัพหลังวางเสร็จ 90 วิ → ด่านยาก ตัวไม่อัพ 90 วิ ตายก่อน/ด่านจบก่อน upgrade เริ่ม)
            local function umSF()
                local ok, sf = pcall(function()
                    return player.PlayerGui.GameUI.ManagementFrame.UnitManagerFrame.Main.CanvasGroup.ScrollingFrame
                end)
                return ok and sf or nil
            end
            local upgradeInFlight = {}
            local function upgradeOnce(uuid)
                if not placeRemote then return false end
                local ok, res = pcall(function() return placeRemote:InvokeServer("UpgradeTower", uuid) end)
                return ok and res == true
            end
            local function towerUpgradeLevel(uuid)
                local sf = umSF(); if not sf then return nil, nil end
                local card = sf:FindFirstChild(uuid); if not card then return nil, nil end
                for _, object in ipairs(card:GetDescendants()) do
                    if object:IsA("TextLabel") or object:IsA("TextButton") then
                        local current, maximum = tostring(object.Text):match("[Uu]pgrade%s*(%d+)%s*/%s*(%d+)")
                        if current and maximum then return tonumber(current), tonumber(maximum) end
                    end
                end
                return nil, nil
            end
            local function towerMaxed(uuid)
                local sf = umSF(); if not sf then return false end
                local c = sf:FindFirstChild(uuid); if not c then return false end
                local current, maximum = towerUpgradeLevel(uuid)
                if current and maximum then return current >= maximum end
                local maxed = false
                pcall(function()
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("TextLabel") and tostring(d.Text):upper() == "MAX"
                            and guiIsActuallyVisible(d) then
                            maxed = true
                            break
                        end
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
                            local internal = tostring(c:GetAttribute("TowerName") or ""):lower()
                            -- ใช้ชื่อภายใน Leorio ก่อน และ fallback ชื่อแสดงผล Leo แบบ exact
                            -- ไม่ใช้ find("leo") เพื่อไม่ให้ชื่อยูนิตอื่นถูกจัดเป็นตัวเงินโดยบังเอิญ
                            if internal == "leorio" or nm:lower():match("^%s*leo%s*$") then
                                moneyU[#moneyU + 1] = c.Name
                            else damageU[#damageU + 1] = c.Name end
                        end
                    end
                end
                return moneyU, damageU
            end
            -- InvokeServer ของเครื่องบอทใช้ 3-17 วิ/ครั้ง จึงต้องยิงเป็นชุดขนาน
            -- พร้อมล็อก UUID ที่กำลังรอ เพื่อไม่ให้รอบถัดไปยิงซ้ำตัวเดิม
            local upStat = { money = 0, dmg = 0 }
            local allowDamageUpgrade = false
            local function launchUpgradeBatch(uuids, kind, maxCount)
                local launched = 0
                for _, uuid in ipairs(uuids) do
                    if launched >= (maxCount or #uuids) then break end
                    if not towerMaxed(uuid) and not upgradeInFlight[uuid] then
                        upgradeInFlight[uuid] = true
                        launched += 1
                        task.spawn(function()
                            local success = upgradeOnce(uuid)
                            upgradeInFlight[uuid] = nil
                            if success then
                                if kind == "money" then upStat.money += 1 else upStat.dmg += 1 end
                            end
                        end)
                    end
                end
                return launched
            end

            -- อัพเกรด 1 รอบ: ตัวเงินให้ max ก่อน (รายได้) แล้วค่อยดาเมจ
            -- วาง Leo ได้เท่าใดก็อัปเท่านั้น ไม่บังคับว่าต้องครบ 3 ตัวก่อน
            local function upgradePass()
                local moneyU, damageU = readPlaced()
                -- Unit Manager อาจว่างชั่วคราวตอน UI กำลังรีเฟรช ห้ามตีความว่าอัปครบแล้ว
                if #moneyU == 0 and #damageU == 0 then
                    return moneyU, damageU, false, 0
                end
                local allMoneyMax = true
                local pendingMoney = {}
                for _, uuid in ipairs(moneyU) do
                    if not stillRunning() then return end
                    if not towerMaxed(uuid) then
                        allMoneyMax = false
                        pendingMoney[#pendingMoney + 1] = uuid
                    end
                end
                local launchedMoney = launchUpgradeBatch(pendingMoney, "money", 3)
                local launchedDamage = 0
                -- ระหว่างช่วงวาง ต้องเห็น Leo ครบเป้าหมายก่อนจึงใช้เงินกับดาเมจ
                -- หลังลองวางจนครบช่วงแล้ว allowDamageUpgrade จะเปิด fallback กรณีแผนที่เต็มจริง
                if allMoneyMax and (allowDamageUpgrade or #moneyU >= initialMoneyTarget) then
                    launchedDamage = launchUpgradeBatch(damageU, "damage", 8)
                end
                if launchedMoney > 0 or launchedDamage > 0 then
                    dbg(string.format("[Legend Upgrade] ส่งขนาน เงิน=%d ดาเมจ=%d | Leo บนสนาม=%d",
                        launchedMoney, launchedDamage, #moneyU))
                end
                return moneyU, damageU, allMoneyMax, launchedMoney + launchedDamage
            end

            dbg("[Legend] วางกระจุก 75-85% + เติม Leorio→3 + อัพเกรดขนาน (ตัวเงิน max ก่อน)")
            local legendPercents = {75, 78, 81, 84, 85, 82, 79, 76, 80, 83, 77}
            local leoFill = {30, 36, 42, 33, 45, 27}
            local lpIdx, leoFi, emptyRounds = 1, 1, 0
            local fillStart = os.clock()
            while stillRunning() and os.clock() - fillStart < 180 and emptyRounds < 10 do
                local placedThisRound, moneyBlocked = false, false
                local currentMoneyUnits = select(1, readPlaced())
                local actualMoneyCount = #currentMoneyUnits
                -- ใช้ Unit Manager ยืนยันจำนวนจริง ไม่ใช้เพียงจำนวน Remote ที่เคยตอบ table
                if moneySlot and actualMoneyCount < initialMoneyTarget then
                    local pc = leoFill[leoFi]; leoFi = leoFi % #leoFill + 1
                    local ok, res = queueOne(moneySlot, "Ground", pc,
                        "Leorio เติม " .. (actualMoneyCount + 1) .. "/" .. initialMoneyTarget)
                    if ok then placedThisRound = true elseif res == -1 then moneyBlocked = true end
                end
                for _, slot in ipairs(damageSlots) do
                    if not stillRunning() then break end
                    local percent = legendPercents[lpIdx]
                    lpIdx = lpIdx % #legendPercents + 1
                    local ok, res = queueOne(slot, "Auto", percent, "Legend กระจุก 75-85%")
                    if ok then placedThisRound = true
                    elseif res == -1 then moneyBlocked = true end
                end
                -- ⭐ อัพเกรดขนานทุกรอบ (ไม่รอวางเสร็จ)
                upgradePass()
                if placedThisRound then emptyRounds = 0
                elseif moneyBlocked then setStatus("[Legend] เงินไม่พอ — อัพเกรด+รอเงินแล้ววางต่อ"); task.wait(0.8)
                else emptyRounds = emptyRounds + 1; task.wait(0.3) end
            end
            allowDamageUpgrade = true
            local total = 0
            for slot = 1, 6 do total += slotPlaced[slot] end
            local finalMoneyUnits = select(1, readPlaced())
            dbg(string.format("========== วาง Legend เสร็จ | Leorioจริง=%d/%d | วางรวม %d | บนสนาม=%d ==========",
                #finalMoneyUnits, initialMoneyTarget, total, placementCount()))

            -- อัพเกรดต่อเนื่องจนทุกตัว MAX หรือ stage จบ ไม่ตัดที่ 240 วินาที
            while stillRunning() do
                local moneyU, damageU, allMoneyMax, launched = upgradePass()
                -- ต้องพบดาเมจจริงอย่างน้อย 1 ตัวก่อนจบลูป กัน Unit Manager โหลดมาเฉพาะ Leo
                local allMax = allMoneyMax and damageU and #damageU > 0
                if allMoneyMax and damageU then
                    for _, uuid in ipairs(damageU) do if not towerMaxed(uuid) then allMax = false; break end end
                end
                if allMax then break end
                task.wait((launched or 0) > 0 and 0.15 or 0.4)
            end
            dbg(("[Legend] อัพเกรดครบ/ด่านจบ (money=%d dmg=%d ครั้ง)"):format(upStat.money, upStat.dmg))

            if myGeneration ~= smartGeneration then return end
            smartRunning = false
            allButton.Text = "SMART AUTO COMPLETE"
            allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
            status.Text = string.format("Legend วางครบ | รวม %d ตำแหน่ง", total)
            status.TextColor3 = Color3.fromRGB(124, 225, 151)
            placing = false
            return
        end

        -- Gem ใช้ Unit Manager เป็นหลักฐานชื่อ/UUID/สถานะ MAX จริง
        -- ชื่อหลังวางที่ตรวจจากเกม: Leorio -> "Leo", Bulma -> "Bluma"
        local function gemUnitManager()
            local ok, sf = pcall(function()
                return player.PlayerGui.GameUI.ManagementFrame.UnitManagerFrame.Main.CanvasGroup.ScrollingFrame
            end)
            return ok and sf or nil
        end

        local function gemPlacedUnits()
            local units = {}
            local sf = gemUnitManager()
            if not sf then return units end
            for _, card in ipairs(sf:GetChildren()) do
                if card:IsA("GuiObject") and #card.Name >= 30 and card.Name:find("%-") then
                    local unitName = ""
                    pcall(function()
                        unitName = tostring(card.Main.TowerButton.ImageLabel.Info.NameLabel.Text)
                    end)
                    units[#units + 1] = { uuid = card.Name, name = unitName }
                end
            end
            return units
        end

        local function gemTowerMaxed(uuid)
            local sf = gemUnitManager()
            local card = sf and sf:FindFirstChild(uuid)
            if not card then return false end
            local maxed = false
            pcall(function()
                for _, object in ipairs(card:GetDescendants()) do
                    if object:IsA("TextLabel") and tostring(object.Text):upper() == "MAX" then
                        maxed = true
                        break
                    end
                end
            end)
            return maxed
        end

        local function gemUpgradeOnce(uuid)
            if not placeRemote then return false end
            local ok, result = pcall(function()
                return placeRemote:InvokeServer("UpgradeTower", uuid)
            end)
            return ok and result == true
        end

        local function exactPlacedName(actual, expected)
            return tostring(actual):lower() == tostring(expected):lower()
        end

        -- อัปตัวเงินชนิดเดียวที่ใช้เปิดเกมให้ครบ MAX ก่อนเข้าสู่ชุดวาง 5-10%
        local function gemMaxPrimaryMoney()
            if not isGem or not initialMoneyPlacedName or initialMoneyTarget <= 0 then return true end
            local started = os.clock()
            local refillPercents = {30, 36, 42, 33, 39, 45, 27, 48, 24}
            local refillIndex = 1
            while stillRunning() and os.clock() - started < 180 do
                local matches, allMax = {}, true
                for _, unit in ipairs(gemPlacedUnits()) do
                    if exactPlacedName(unit.name, initialMoneyPlacedName) then
                        matches[#matches + 1] = unit
                        if not gemTowerMaxed(unit.uuid) then allMax = false end
                    end
                end

                -- ต้นเกมอาจมีเงินไม่พอวางครบ: หลังมีตัวดาเมจช่วยหาเงินแล้วต้องเติมตัวเงินให้ครบก่อน
                if #matches < initialMoneyTarget then
                    local percent = refillPercents[refillIndex]
                    refillIndex = refillIndex % #refillPercents + 1
                    local placementType = initialMoneyName == "Leorio" and "Ground"
                        or slotTypes[moneySlot] or "Auto"
                    local ok = queueOne(
                        moneySlot,
                        placementType,
                        percent,
                        string.format("Gem เติม %s %d/%d", initialMoneyPlacedName, #matches + 1, initialMoneyTarget)
                    )
                    if ok then
                        task.wait(0.2)
                        continue
                    end
                end

                if #matches >= initialMoneyTarget and allMax then
                    dbg(string.format("[Gem Upgrade] %s MAX ครบ %d/%d",
                        initialMoneyPlacedName, #matches, initialMoneyTarget))
                    return true
                end
                local upgraded = false
                for _, unit in ipairs(shuffledCopy(matches)) do
                    if not stillRunning() then return false end
                    if not gemTowerMaxed(unit.uuid) and gemUpgradeOnce(unit.uuid) then
                        upgraded = true
                        setStatus(string.format("อัป %s ให้ MAX (%d/%d ตัว)",
                            initialMoneyPlacedName, #matches, initialMoneyTarget))
                        task.wait(0.12)
                    end
                end
                task.wait(upgraded and 0.2 or 0.7)
            end
            dbg("[Gem Upgrade] หมดเวลารอ " .. tostring(initialMoneyPlacedName) .. " MAX")
            return false
        end

        -- สุ่มอัปดาเมจเป็นรอบสั้น ๆ ใช้ได้ทั้ง "ระหว่างวาง" และช่วงเร่งอัปท้าย
        -- Leo ถูก MAX ไปก่อนแล้วจึงไม่รวม; Bluma รวมในคิวเฉพาะกรณีที่มี Leo+Bluma พร้อมกัน
        local gemDamageUpgradeCount = 0
        local function gemUpgradeDamagePass(maxAttempts)
            local units = gemPlacedUnits()
            local pool = {}
            for _, unit in ipairs(units) do
                local isLeo = exactPlacedName(unit.name, "Leo")
                local isSingleBluma = exactPlacedName(unit.name, "Bluma") and not hasBothMoney
                if not isLeo and not isSingleBluma and not gemTowerMaxed(unit.uuid) then
                    pool[#pool + 1] = unit
                end
            end

            local attempts, upgraded = 0, 0
            for _, unit in ipairs(shuffledCopy(pool)) do
                if not stillRunning() or attempts >= (maxAttempts or #pool) then break end
                attempts += 1
                if not gemTowerMaxed(unit.uuid) and gemUpgradeOnce(unit.uuid) then
                    upgraded += 1
                    gemDamageUpgradeCount += 1
                    setStatus(string.format("[Gem] สุ่มอัป %s | รวม %d ครั้ง", unit.name, gemDamageUpgradeCount))
                    task.wait(0.04)
                end
            end
            return #units, #pool, upgraded
        end

        local function gemUpgradeDamageAndDeferredBulma()
            if not isGem then return true end

            local started = os.clock()
            local sawPlacedUnits = false
            local missingSince = nil

            while stillRunning() and os.clock() - started < 240 do
                -- รอบท้ายยิงได้สูงสุด 24 ยูนิต/รอบ และลด delay เพื่อใช้เงินที่ค้างอยู่ให้ทันเวฟ
                local unitCount, pendingCount, upgradedThisPass = gemUpgradeDamagePass(24)
                if unitCount > 0 then
                    sawPlacedUnits = true
                    missingSince = nil
                elseif sawPlacedUnits then
                    missingSince = missingSince or os.clock()
                    if os.clock() - missingSince >= 3 then
                        dbg("[Gem Upgrade] Unit Manager ว่างหลังเคยพบยูนิต — ด่านน่าจะจบแล้ว")
                        return false
                    end
                end

                if unitCount > 0 and pendingCount == 0 then
                    dbg("[Gem Upgrade] ดาเมจ" .. (hasBothMoney and "+Bluma" or "") .. " MAX ครบทั้งหมด")
                    return true
                end

                task.wait(upgradedThisPass > 0 and 0.08 or 0.35)
            end

            dbg("[Gem Upgrade] หมดเวลาอัปดาเมจ | สำเร็จ " .. gemDamageUpgradeCount .. " ครั้ง")
            return false
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

        if isGem then
            -- Gem: สุ่มช่องแบบไม่ซ้ำในแต่ละรอบ วางดัก "หน้ามอน +20%" จำนวน 3-4 ตัว
            -- หลังตัวแรกสำเร็จ จะค้นประเภทที่ขาด (Ground/Hill) ก่อน แล้วค่อยเติมจำนวน
            local interceptPercent = math.clamp(monsterPercent + 20, 20, 95)
            local interceptOffsets = {-2, 2, 0, -4, 4, -6, 6}
            local offsetIndex = 1
            local interceptQueued = 0
            local hasGround, hasHill = false, false
            local interceptStart = os.clock()

            local function placeGemIntercept(slot, requestedType, label)
                local offset = interceptOffsets[offsetIndex]
                offsetIndex = offsetIndex % #interceptOffsets + 1
                local ok, result = queueOne(
                    slot,
                    requestedType or slotTypes[slot] or "Auto",
                    math.clamp(interceptPercent + offset, 5, 95),
                    label
                )
                if ok then
                    interceptQueued += 1
                    hasGround = hasGround or slotTypes[slot] == "Ground"
                    hasHill = hasHill or slotTypes[slot] == "Hill"
                end
                return ok, result
            end

            while stillRunning() and interceptQueued < 4 and os.clock() - interceptStart < 45 do
                local bag = shuffledCopy(damageSlots)
                local placedThisRound, moneyBlocked = false, false

                -- ตัวแรกสุ่ม Auto เพื่อเรียนรู้ประเภทจริงจากผลวาง
                if interceptQueued == 0 then
                    for _, slot in ipairs(bag) do
                        local ok, result = placeGemIntercept(slot, "Auto", "Gem ดักหน้ามอน +20% ตัวแรก")
                        if ok then placedThisRound = true; break end
                        if result == -1 then moneyBlocked = true end
                    end
                end

                -- มีประเภทหนึ่งแล้ว: ลองวางเฉพาะประเภทที่ขาดจากคิวสุ่ม
                if interceptQueued > 0 and not (hasGround and hasHill) then
                    local missingType = hasGround and "Hill" or "Ground"
                    for _, slot in ipairs(shuffledCopy(damageSlots)) do
                        if not stillRunning() then break end
                        local ok, result = placeGemIntercept(slot, missingType,
                            "Gem หา " .. missingType .. " ดักหน้ามอน +20%")
                        if ok then placedThisRound = true; break end
                        if result == -1 then moneyBlocked = true end
                    end
                end

                -- เติมให้ครบอย่างน้อย 3; ถ้ายังขาด Ground/Hill ให้ตัวที่ 4 เป็นโอกาสสุดท้าย
                local wanted = (hasGround and hasHill) and 3 or 4
                for _, slot in ipairs(shuffledCopy(damageSlots)) do
                    if not stillRunning() or interceptQueued >= wanted then break end
                    local ok, result = placeGemIntercept(slot, slotTypes[slot] or "Auto",
                        string.format("Gem ดักหน้ามอน +20%% (%d/%d)", interceptQueued + 1, wanted))
                    if ok then placedThisRound = true end
                    if result == -1 then moneyBlocked = true end
                end

                if interceptQueued >= 3 and (hasGround and hasHill or interceptQueued >= 4) then break end
                if not placedThisRound then
                    setStatus(moneyBlocked and "[Gem] เงินไม่พอ — รอแล้วดักหน้ามอนต่อ"
                        or "[Gem] ยังหาประเภท Ground/Hill ที่ขาด — สุ่มคิวใหม่")
                    task.wait(moneyBlocked and 0.7 or 0.25)
                end
            end
            dbg(string.format("[3-4 Gem] ดักหน้าได้ %d ตัว | Ground=%s Hill=%s | จุด %.1f%%",
                interceptQueued, tostring(hasGround), tostring(hasHill), interceptPercent))
        else
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
        end

        -- Gem: หลังมีตัวเคลียร์มอน 3-4 ตัวแล้ว จึงอัปตัวเงินหลักให้ MAX
        -- มีทั้ง Leo+Bluma จะ MAX เฉพาะ Leo; Bluma ไปวาง/อัปพร้อมดาเมจภายหลัง
        if isGem then gemMaxPrimaryMoney() end
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
        local fillSlots = {}
        for _, slot in ipairs(damageSlots) do fillSlots[#fillSlots + 1] = slot end
        if isGem and deferredBulmaSlot then
            dbg("[5 Gem] เตรียมวาง Bulma Tower" .. deferredBulmaSlot .. " พร้อมช่วงตัวดาเมจ (สูงสุด 1 ตัว)")
        end

        while stillRunning() and os.clock() - fillStart < 60 and emptyRounds < 3 do
            local placedThisRound = false
            local moneyBlockedThisRound = false

            -- ทั้ง Leo+Bluma: หลัง Leo MAX แล้วให้ Bluma ได้สิทธิ์ใช้เงินก่อน 1 ครั้งในช่วงวางดาเมจ
            -- ป้องกันคิวสุ่มดาเมจใช้เงินหมดทุกครั้งจน Bluma ไม่เคยถูกวาง
            if deferredBulmaSlot and slotPlaced[deferredBulmaSlot] < 1 then
                local bulmaPercent = earlyPercents[earlyIndex]
                earlyIndex = earlyIndex % #earlyPercents + 1
                local ok, res = queueOne(
                    deferredBulmaSlot,
                    slotTypes[deferredBulmaSlot] or "Auto",
                    bulmaPercent,
                    "Bluma วางพร้อมช่วงตัวดาเมจ"
                )
                if ok then
                    placedThisRound = true
                elseif res == -1 then
                    moneyBlockedThisRound = true
                end
            end

            local roundSlots = isGem and shuffledCopy(fillSlots) or fillSlots
            for _, slot in ipairs(roundSlots) do
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

            -- ไม่รอให้ fill loop จบ 60 วิ: หลังตัวเงินหลัก MAX แล้วให้อัปดาเมจแทรกทุกรอบ
            -- สูงสุด 12 ยูนิตต่อรอบเพื่อไม่ให้การอัปกินเวลาจนหยุดวางตัวใหม่
            if isGem then
                local _, pending, upgraded = gemUpgradeDamagePass(12)
                if upgraded > 0 then
                    dbg(string.format("[5 Gem] อัปแทรกระหว่างวาง %d ครั้ง | ยังรออัปก่อนรอบนี้ %d ตัว",
                        upgraded, pending))
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

        if isGem then
            dbg("[6 Gem] เริ่มสุ่มอัปดาเมจ" .. (hasBothMoney and "+Bluma" or "") .. " จน MAX")
            gemUpgradeDamageAndDeferredBulma()
        end

        if myGeneration ~= smartGeneration then return end
        smartRunning = false
        allButton.Text = "SMART AUTO COMPLETE"
        allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
        local total = 0
        for slot = 1, 6 do total += slotPlaced[slot] end
        dbg(string.format("========== จบ วางรวม %d ตำแหน่ง | ต่อช่อง T1=%d T2=%d T3=%d T4=%d T5=%d T6=%d | บนสนาม=%d ==========",
            total, slotPlaced[1], slotPlaced[2], slotPlaced[3], slotPlaced[4], slotPlaced[5], slotPlaced[6], placementCount()))
        status.Text = string.format("จองวางครบ | ตัวเงิน=%s | รวม %d ตำแหน่ง",
            initialMoneyName and (initialMoneyName .. " Tower" .. moneySlot) or "ไม่มี", total)
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
_G.AO_CONFIRM_START_GAME = clickStartGameConfirm
_G.AO_CORE_READY = true

-- เฝ้ากล่อง Start Game ตลอดทั้งรอบและหลัง Replay; กดซ้ำเฉพาะเมื่อกล่องเดิมยังค้าง
task.spawn(function()
    local lastAttempt = 0
    while PLACE_MODULE_GEN == _G.AO_PLACE_MODULE_GEN do
        if findStartGameConfirmButton() and os.clock() - lastAttempt >= 1 then
            lastAttempt = os.clock()
            local success, method = clickStartGameConfirm()
            print(string.format("[AO PLACE v%s] Start Game Confirm = %s via %s",
                TEST_VERSION, tostring(success), tostring(method)))
        end
        task.wait(0.25)
    end
end)

if not AO_HEADLESS then
    task.spawn(function()
        local speedLevel, speedMessage = setBestGameSpeed()
        print("[AO PLACE v" .. TEST_VERSION .. "] " .. speedMessage)
        if speedLevel then setStatus(speedMessage) end
    end)
end

local function cancelOldSmartRound(reason)
    if not smartRunning then return end
    smartRunning = false
    smartGeneration += 1
    placing = false
    allButton.Text = "START SMART AUTO"
    allButton.BackgroundColor3 = Color3.fromRGB(68, 151, 101)
    print(string.format("[AO PLACE v%s] cancel old generation: %s", TEST_VERSION, tostring(reason)))
end

local function scheduleSmartRoundRecovery(reason, replaceRunning)
    roundRecoveryToken += 1
    local token = roundRecoveryToken
    task.spawn(function()
        -- ให้ Towers/UnitNodes, hotbar และเงินเริ่มต้นของรอบใหม่รีเซ็ตก่อน
        task.wait(1.5)
        local started = os.clock()
        while gui.Parent and token == roundRecoveryToken and os.clock() - started < 12 do
            local wave = readCurrentWave()
            if not isActOverVisible() and wave and wave > 0 and placementCount() == 0 then
                if smartRunning and not replaceRunning then return end
                if replaceRunning then
                    cancelOldSmartRound("เริ่มรอบใหม่: " .. tostring(reason))
                end
                task.wait(0.35)
                if token == roundRecoveryToken and not smartRunning and placementCount() == 0 then
                    print(string.format(
                        "[AO PLACE v%s] new round Wave %d -> start fresh Smart Auto (%s)",
                        TEST_VERSION,
                        wave,
                        tostring(reason)
                    ))
                    pcall(_G.AO_SMART_START)
                end
                return
            end
            task.wait(0.35)
        end
    end)
end

task.spawn(function()
    while gui.Parent do
        -- ไม่ผูกกับ Wave 20: ตอนแพ้ก่อนถึงเป้าก็มีรูปไอเทมบัง Auto Replay
        if AO_HEADLESS or gemFarmEnabled then
            pcall(dismissRewardItem)
        end

        local wave = readCurrentWave()
        local actOverVisible = isActOverVisible()

        -- ใช้ lifecycle แบบ Mansion กับ Gem/Legend ด้วย: generation เก่าต้องจบทันที
        -- เมื่อรอบจบ และสร้าง generation ใหม่หลัง Wave รีเซ็ต/หน้าจบหายแล้วเท่านั้น
        if AO_HEADLESS and usesResilientPlacement() then
            if actOverVisible and not wasActOverVisible then
                cancelOldSmartRound("พบหน้าจบรอบ")
            elseif wasActOverVisible and not actOverVisible and wave and wave > 0 then
                scheduleSmartRoundRecovery("หน้าจบรอบปิด", true)
            end

            if wave and lastObservedWave and lastObservedWave >= 4 and wave <= 2 then
                cancelOldSmartRound(string.format("Wave %d -> %d", lastObservedWave, wave))
                scheduleSmartRoundRecovery(string.format("Wave %d -> %d", lastObservedWave, wave), true)
            end
        end
        wasActOverVisible = actOverVisible
        if wave then lastObservedWave = wave end

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
            scheduleSmartRoundRecovery("ตรวจพบสนามว่าง Wave " .. tostring(wave), false)
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
