-- ============================================================
-- ANIME ORIGINS GAME + PLACE RECON v0.2
-- Run in game, manually place one unit, then AO_GAME_RECON_STOP()
-- ============================================================

local RECON_VERSION = "0.2"
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local output = {}
local remoteCount = 0

_G.AO_GAME_RECON_ACTIVE = false

local function save()
    local text = table.concat(output, "\n")
    for _, fn in ipairs({setclipboard, toclipboard, writeclipboard}) do
        if type(fn) == "function" and pcall(fn, text) then
            break
        end
    end
    if type(writefile) == "function" then
        pcall(writefile, "ao_game_place_recon.txt", text)
    end
end

local function add(text)
    text = tostring(text)
    output[#output + 1] = text
    print("[AO GAME] " .. text)
end

local function attrs(object)
    local values = {}
    for key, value in pairs(object:GetAttributes()) do
        values[#values + 1] = tostring(key) .. "=" .. tostring(value)
    end
    table.sort(values)
    return #values > 0 and table.concat(values, ", ") or "-"
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    local kind = typeof(value)

    if kind == "string" then
        return string.format("%q", value)
    elseif kind == "Instance" then
        return value:GetFullName()
    elseif kind == "CFrame" then
        return "CFrame.new(" .. tostring(value) .. ")"
    elseif kind == "Vector3" then
        return "Vector3.new(" .. tostring(value) .. ")"
    elseif kind ~= "table" then
        return kind .. ":" .. tostring(value)
    end

    if seen[value] then return "{recursive}" end
    if depth >= 4 then return "{depth-limit}" end
    seen[value] = true

    local parts, count = {}, 0
    for key, item in pairs(value) do
        count += 1
        if count > 50 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = "[" .. serialize(key, depth + 1, seen) .. "]=" .. serialize(item, depth + 1, seen)
    end

    seen[value] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

add("===== ANIME ORIGINS GAME RECON v" .. RECON_VERSION .. " =====")
add("PlaceId=" .. tostring(game.PlaceId))
add("GameId=" .. tostring(game.GameId))

local keywords = {"path", "waypoint", "node", "route", "road", "start", "goal", "spawn", "enemy", "end"}
local function keywordMatch(name)
    local lower = string.lower(tostring(name))
    for _, keyword in ipairs(keywords) do
        if string.find(lower, keyword, 1, true) then return true end
    end
    return false
end

add("\n===== PATH-RELATED INSTANCES =====")
local related = 0
for _, object in ipairs(workspace:GetDescendants()) do
    if keywordMatch(object.Name) then
        related += 1
        if related <= 250 then
            local position, size = "-", "-"
            if object:IsA("BasePart") then
                position, size = tostring(object.Position), tostring(object.Size)
            elseif object:IsA("Attachment") then
                position = tostring(object.WorldPosition)
            elseif object:IsA("Model") then
                local ok, boxCF, boxSize = pcall(function() return object:GetBoundingBox() end)
                if ok then position, size = tostring(boxCF.Position), tostring(boxSize) end
            end
            add(object.ClassName .. " '" .. object:GetFullName() .. "' | Pos=" .. position .. " | Size=" .. size .. " | Attr=" .. attrs(object))
        end
    end
end
add("PathRelatedCount=" .. tostring(related))

add("\n===== NUMERIC WAYPOINT CANDIDATES =====")
local candidateCount = 0
for _, container in ipairs(workspace:GetDescendants()) do
    if container:IsA("Folder") or container:IsA("Model") then
        local points = {}
        for _, child in ipairs(container:GetChildren()) do
            local index = tonumber(child.Name)
            if index and (child:IsA("BasePart") or child:IsA("Attachment")) then
                points[#points + 1] = {Index = index, Object = child}
            end
        end
        if #points >= 2 then
            candidateCount += 1
            table.sort(points, function(a, b) return a.Index < b.Index end)
            add("\nCANDIDATE " .. candidateCount .. " Path=" .. container:GetFullName() .. " Points=" .. #points)
            for _, point in ipairs(points) do
                local pos = point.Object:IsA("Attachment") and point.Object.WorldPosition or point.Object.Position
                add(tostring(point.Index) .. "=" .. tostring(pos) .. " | " .. point.Object.ClassName .. " | Attr=" .. attrs(point.Object))
            end
        end
    end
end
add("NumericCandidateCount=" .. tostring(candidateCount))

add("\n===== MAP VALUES =====")
local map = workspace:FindFirstChild("Map")
if map then
    add("Map=" .. map:GetFullName() .. " | " .. map.ClassName .. " | Attr=" .. attrs(map))
    for _, object in ipairs(map:GetDescendants()) do
        if object:IsA("ValueBase") then
            add(object:GetFullName() .. " | " .. object.ClassName .. "=" .. tostring(object.Value))
        end
    end
else
    add("NO Workspace.Map")
end

add("\n===== ENEMIES =====")
local enemies = workspace:FindFirstChild("Enemies")
if enemies then
    add("Children=" .. #enemies:GetChildren() .. " | Attr=" .. attrs(enemies))
    for index, enemy in ipairs(enemies:GetChildren()) do
        if index > 5 then break end
        add("\nENEMY " .. index .. "=" .. enemy:GetFullName() .. " | " .. enemy.ClassName .. " | Attr=" .. attrs(enemy))
        for _, object in ipairs(enemy:GetDescendants()) do
            if object:IsA("ValueBase") then
                add(" VALUE " .. object:GetFullName() .. "=" .. tostring(object.Value))
            elseif object:IsA("BasePart") and (
                object.Name == "HumanoidRootPart" or
                object.Name == "RootPart" or
                (enemy:IsA("Model") and enemy.PrimaryPart == object)
            ) then
                add(" ROOT " .. object:GetFullName() .. " Pos=" .. tostring(object.Position))
            end
        end
    end
else
    add("NO Workspace.Enemies")
end

add("\n===== TOWERS =====")
local towers = workspace:FindFirstChild("Towers")
add(towers and (towers:GetFullName() .. " | Children=" .. #towers:GetChildren() .. " | Attr=" .. attrs(towers)) or "NO Workspace.Towers")

add("\n===== REMOTE CANDIDATES =====")
for _, object in ipairs(RS:GetDescendants()) do
    if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
        local lower = string.lower(object.Name)
        if string.find(lower, "place", 1, true) or string.find(lower, "tower", 1, true) or string.find(lower, "unit", 1, true) then
            add(object.ClassName .. " '" .. object:GetFullName() .. "'")
        end
    end
end

save()

if not hookmetamethod or not getnamecallmethod then
    add("ERROR: executor has no hookmetamethod/getnamecallmethod")
    save()
    return
end

_G.AO_GAME_RECON_ACTIVE = true
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if _G.AO_GAME_RECON_ACTIVE and (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
        remoteCount += 1
        if remoteCount <= 120 then
            local args, rendered = {...}, {}
            for index = 1, #args do rendered[index] = "[" .. index .. "]=" .. serialize(args[index]) end
            add("\n===== REMOTE CALL " .. remoteCount .. " =====\nPath=" .. self:GetFullName() .. "\nMethod=" .. method .. "\nArgs=" .. table.concat(rendered, " | "))
            save()
        end
    end
    return oldNamecall(self, ...)
end)

_G.AO_GAME_RECON_STOP = function()
    _G.AO_GAME_RECON_ACTIVE = false
    add("\n===== RECON STOPPED =====")
    add("CapturedRemoteCalls=" .. tostring(remoteCount))
    save()
    print("[AO GAME] copied")
end

add("\nHOOK ARMED: manually place one unit, then run _G.AO_GAME_RECON_STOP()")
save()
