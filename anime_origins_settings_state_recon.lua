-- ============================================================
-- ANIME ORIGINS SETTINGS STATE RECON v0.1
-- Lobby only. Keep Settings open while running.
-- ============================================================

local VERSION = "0.1"
local LOBBY_PLACE_ID = 129932912185311
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
local out = {}

local function push(value)
    out[#out + 1] = tostring(value)
    print("[AO STATE] " .. tostring(value))
end

local function fullName(object)
    local ok, value = pcall(function() return object:GetFullName() end)
    return ok and value or tostring(object)
end

local function colorSequence(value)
    local parts = {}
    for _, point in ipairs(value.Keypoints) do
        parts[#parts + 1] = string.format("%.3f:%s", point.Time, tostring(point.Value))
    end
    return table.concat(parts, ";")
end

local function numberSequence(value)
    local parts = {}
    for _, point in ipairs(value.Keypoints) do
        parts[#parts + 1] = string.format("%.3f:%.3f", point.Time, point.Value)
    end
    return table.concat(parts, ";")
end

local function describe(object)
    local values = {
        object.ClassName .. " " .. string.format("%q", object.Name),
        "path=" .. fullName(object),
    }

    local attributes = {}
    for key, value in pairs(object:GetAttributes()) do
        attributes[#attributes + 1] = tostring(key) .. "=" .. tostring(value)
    end
    table.sort(attributes)
    values[#values + 1] = "attr=" .. (#attributes > 0 and table.concat(attributes, ",") or "-")

    if object:IsA("GuiObject") then
        values[#values + 1] = string.format(
            "visible=%s active=%s pos=%d,%d size=%d,%d bg=%s bgT=%.3f z=%d",
            tostring(object.Visible), tostring(object.Active),
            object.AbsolutePosition.X, object.AbsolutePosition.Y,
            object.AbsoluteSize.X, object.AbsoluteSize.Y,
            tostring(object.BackgroundColor3), object.BackgroundTransparency,
            object.ZIndex
        )
    end
    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        values[#values + 1] = string.format(
            "image=%q imageColor=%s imageT=%.3f",
            tostring(object.Image), tostring(object.ImageColor3), object.ImageTransparency
        )
    end
    if object:IsA("TextLabel") or object:IsA("TextButton") then
        values[#values + 1] = string.format(
            "text=%q textColor=%s textT=%.3f",
            tostring(object.Text), tostring(object.TextColor3), object.TextTransparency
        )
    end
    if object:IsA("UIGradient") then
        values[#values + 1] = "enabled=" .. tostring(object.Enabled)
        values[#values + 1] = "color=" .. colorSequence(object.Color)
        values[#values + 1] = "transparency=" .. numberSequence(object.Transparency)
        values[#values + 1] = "rotation=" .. tostring(object.Rotation)
    end
    if object:IsA("UIStroke") then
        values[#values + 1] = string.format(
            "strokeColor=%s strokeT=%.3f thickness=%.3f enabled=%s",
            tostring(object.Color), object.Transparency, object.Thickness, tostring(object.Enabled)
        )
    end
    if object:IsA("ValueBase") then
        values[#values + 1] = "value=" .. tostring(object.Value)
    end
    return table.concat(values, " | ")
end

push("===== ANIME ORIGINS SETTINGS STATE RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId))

local ok, scanError = pcall(function()
    if game.PlaceId ~= LOBBY_PLACE_ID then
        error("run in lobby PlaceId " .. tostring(LOBBY_PLACE_ID))
    end
    if not playerGui then error("PlayerGui not found") end

    local settings = playerGui:FindFirstChild("SettingsFrame", true)
    if not settings then error("SettingsFrame not found; open Settings first") end

    local targets = {
        "AutoSkipWave",       -- confirmed ON in screenshot
        "AutoNextGame",       -- confirmed OFF in screenshot
        "GraphicsQuality",    -- confirmed Low in screenshot
        "GraphicsQualityGame",-- confirmed Low in screenshot
        "EnemyMovement",      -- confirmed Low in screenshot
    }

    for _, targetName in ipairs(targets) do
        push("===== " .. targetName .. " =====")
        local target = settings:FindFirstChild(targetName, true)
        if not target then
            push("NOT FOUND")
        else
            push(describe(target))
            for _, object in ipairs(target:GetDescendants()) do
                if object:IsA("GuiObject") or object:IsA("UIGradient") or
                    object:IsA("UIStroke") or object:IsA("ValueBase") then
                    push("  " .. describe(object))
                end
            end
        end
    end
end)

if not ok then push("SCAN ERROR: " .. tostring(scanError)) end

local blob = table.concat(out, "\n")
local copied = false
for _, copyName in ipairs({"setclipboard", "toclipboard", "writeclipboard"}) do
    local copyFunction = getgenv and getgenv()[copyName] or _G[copyName]
    if type(copyFunction) == "function" and pcall(copyFunction, blob) then
        copied = true
        break
    end
end

local saved = false
if type(writefile) == "function" then
    saved = pcall(writefile, "anime_origins_settings_state_v01.txt", blob)
end

print(string.format("[AO STATE] DONE copy=%s file=%s lines=%d", tostring(copied), tostring(saved), #out))
