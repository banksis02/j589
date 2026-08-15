-- ============================================================
-- ANIME ORIGINS HILL SURFACE RECON v0.1
-- Run inside a match. Scans elevated surfaces near PathFolder.
-- ============================================================

local VERSION = "0.1"
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local pathFolder = workspace:FindFirstChild("PathFolder")

if not pathFolder then
    warn("[AO HILL RECON] PathFolder not found")
    return
end

local waypoints = {}
for _, object in ipairs(pathFolder:GetChildren()) do
    if object:IsA("BasePart") and tonumber(object.Name) then
        waypoints[#waypoints + 1] = object
    end
end
table.sort(waypoints, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)

if #waypoints < 2 then
    warn("[AO HILL RECON] Not enough waypoints")
    return
end

local points, cumulative = {}, {0}
for index, waypoint in ipairs(waypoints) do
    points[index] = waypoint.Position
    if index > 1 then
        cumulative[index] = cumulative[index - 1] + (points[index] - points[index - 1]).Magnitude
    end
end
local total = cumulative[#cumulative]

local function pointAt(percent)
    local wanted = math.clamp(percent, 0, 100) / 100 * total
    for index = 2, #points do
        if cumulative[index] >= wanted then
            local a, b = points[index - 1], points[index]
            local segmentLength = cumulative[index] - cumulative[index - 1]
            local alpha = segmentLength > 0 and (wanted - cumulative[index - 1]) / segmentLength or 0
            local direction = b - a
            return a:Lerp(b, alpha), direction.Magnitude > 0 and direction.Unit or Vector3.zAxis
        end
    end
    return points[#points], (points[#points] - points[#points - 1]).Unit
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local excluded = {pathFolder}
for _, name in ipairs({"Enemies", "Towers", "UnitNodes", "AO_Path_Debug", "AO_Hill_Recon"}) do
    local object = workspace:FindFirstChild(name)
    if object then excluded[#excluded + 1] = object end
end
if player.Character then excluded[#excluded + 1] = player.Character end
params.FilterDescendantsInstances = excluded

local hits, seen = {}, {}
for percent = 0, 100, 5 do
    local base, direction = pointAt(percent)
    local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit

    for side = -40, 40, 2 do
        if side ~= 0 then
            for _, along in ipairs({-6, 0, 6}) do
                local sample = base + perpendicular * side + direction * along
                local hit = workspace:Raycast(sample + Vector3.new(0, 120, 0), Vector3.new(0, -180, 0), params)
                if hit and hit.Normal.Y >= 0.65 and hit.Position.Y >= base.Y + 2.5 then
                    local horizontal = Vector3.new(hit.Position.X - base.X, 0, hit.Position.Z - base.Z).Magnitude
                    local key = string.format("%s|%.0f|%.0f|%.0f", hit.Instance:GetFullName(), hit.Position.X, hit.Position.Y, hit.Position.Z)
                    if not seen[key] then
                        seen[key] = true
                        hits[#hits + 1] = {
                            Percent = percent,
                            Side = side,
                            Along = along,
                            Distance = horizontal,
                            Height = hit.Position.Y - base.Y,
                            Position = hit.Position,
                            Instance = hit.Instance,
                        }
                    end
                end
            end
        end
    end
end

table.sort(hits, function(a, b)
    if math.abs(a.Distance - b.Distance) > 0.01 then return a.Distance < b.Distance end
    return a.Percent < b.Percent
end)

local old = workspace:FindFirstChild("AO_Hill_Recon")
if old then old:Destroy() end
local markers = Instance.new("Folder")
markers.Name = "AO_Hill_Recon"
markers.Parent = workspace

local out = {
    "===== ANIME ORIGINS HILL SURFACE RECON v" .. VERSION .. " =====",
    "PlaceId=" .. tostring(game.PlaceId),
    "PathPoints=" .. tostring(#points),
    "ElevatedHits=" .. tostring(#hits),
}

local shown = math.min(80, #hits)
for index = 1, shown do
    local item = hits[index]
    out[#out + 1] = string.format(
        "#%02d pct=%d side=%d along=%d dist=%.2f height=%.2f pos=(%.2f, %.2f, %.2f) part=%s",
        index,
        item.Percent,
        item.Side,
        item.Along,
        item.Distance,
        item.Height,
        item.Position.X,
        item.Position.Y,
        item.Position.Z,
        item.Instance:GetFullName()
    )

    if index <= 30 then
        local marker = Instance.new("Part")
        marker.Name = "Hill_" .. index
        marker.Shape = Enum.PartType.Ball
        marker.Size = Vector3.new(1.1, 1.1, 1.1)
        marker.Position = item.Position + Vector3.new(0, 0.7, 0)
        marker.Color = Color3.fromRGB(0, 255, 255)
        marker.Material = Enum.Material.Neon
        marker.Anchored = true
        marker.CanCollide = false
        marker.CanTouch = false
        marker.CanQuery = false
        marker.Parent = markers
    end
end

local blob = table.concat(out, "\n")
print(blob)

local copied = false
for _, copyFunction in ipairs({setclipboard, toclipboard, writeclipboard}) do
    if type(copyFunction) == "function" and pcall(copyFunction, blob) then
        copied = true
        break
    end
end

local saved = false
if type(writefile) == "function" then
    saved = pcall(writefile, "anime_origins_hill_recon.txt", blob)
end

print(string.format("[AO HILL RECON] copy=%s file=%s shown=%d/%d", tostring(copied), tostring(saved), shown, #hits))
