-- ============================================================
-- ANIME ORIGINS GEM BALANCE MONITOR v0.1
-- Run before a Wave-20 restart. Clipboard updates on every change.
-- ============================================================

local VERSION = "0.1"
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local running = true
local lines = {}
local lastValues = {}

local function copyLog()
    local blob = table.concat(lines, "\n")
    for _, copyFunction in ipairs({setclipboard, toclipboard, writeclipboard}) do
        if type(copyFunction) == "function" and pcall(copyFunction, blob) then return true end
    end
    return false
end

local function push(message)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), tostring(message))
    lines[#lines + 1] = line
    print("[AO GEM] " .. line)
    copyLog()
end

local function fullName(object)
    local ok, value = pcall(function() return object:GetFullName() end)
    return ok and value or tostring(object)
end

local function keywordMatch(text)
    local lower = string.lower(tostring(text or ""))
    return lower:find("gem", 1, true) or
        lower:find("diamond", 1, true) or
        lower:find("crystal", 1, true) or
        lower:find("currency", 1, true) or
        lower:find("resource", 1, true)
end

local function looksNumeric(text)
    text = tostring(text or ""):gsub(",", ""):gsub("%s", "")
    return text:match("^%d+[%+xX]?$"), tonumber(text:match("%d+"))
end

local function visibleOnScreen(object)
    if not object:IsA("GuiObject") or not object.Visible then return false end
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    return size.X > 0 and size.Y > 0 and
        position.X + size.X >= 0 and position.Y + size.Y >= 0 and
        position.X <= viewport.X and position.Y <= viewport.Y
end

local function collect()
    local found = {}
    local playerGui = player:FindFirstChildOfClass("PlayerGui")

    if playerGui then
        for _, object in ipairs(playerGui:GetDescendants()) do
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                local path = fullName(object)
                local numeric = looksNumeric(object.Text)
                local bottomNumeric = numeric and visibleOnScreen(object) and
                    object.AbsolutePosition.Y >= (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080) * 0.70

                if keywordMatch(path) or keywordMatch(object.Text) or bottomNumeric then
                    found["UI|" .. path] = tostring(object.Text)
                end
            end
        end
    end

    for _, root in ipairs({player, playerGui}) do
        if root then
            for _, object in ipairs(root:GetDescendants()) do
                if keywordMatch(object.Name) then
                    if object:IsA("IntValue") or object:IsA("NumberValue") or object:IsA("StringValue") then
                        found["VALUE|" .. fullName(object)] = tostring(object.Value)
                    end

                    for key, value in pairs(object:GetAttributes()) do
                        found["ATTR|" .. fullName(object) .. "." .. tostring(key)] = tostring(value)
                    end
                else
                    for key, value in pairs(object:GetAttributes()) do
                        if keywordMatch(key) then
                            found["ATTR|" .. fullName(object) .. "." .. tostring(key)] = tostring(value)
                        end
                    end
                end
            end
        end
    end

    for key, value in pairs(player:GetAttributes()) do
        if keywordMatch(key) then found["PLAYER_ATTR|" .. tostring(key)] = tostring(value) end
    end

    return found
end

push("===== ANIME ORIGINS GEM MONITOR v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId) .. " Player=" .. player.Name)

local initial = collect()
local initialCount = 0
for key, value in pairs(initial) do
    lastValues[key] = value
    initialCount += 1
end

local sortedKeys = {}
for key in pairs(initial) do sortedKeys[#sortedKeys + 1] = key end
table.sort(sortedKeys)
for _, key in ipairs(sortedKeys) do push("INITIAL " .. key .. " = " .. initial[key]) end
push("InitialCandidates=" .. tostring(initialCount))
push("MONITORING — Restart at Wave 20, then wait until Wave 1")

_G.AO_GEM_MONITOR_STOP = function()
    running = false
    push("STOP requested")
    return table.concat(lines, "\n")
end

task.spawn(function()
    while running do
        local current = collect()

        for key, value in pairs(current) do
            local previous = lastValues[key]
            if previous == nil then
                push("NEW " .. key .. " = " .. value)
            elseif previous ~= value then
                push("CHANGE " .. key .. " : " .. previous .. " -> " .. value)
            end
            lastValues[key] = value
        end

        task.wait(0.25)
    end
end)
