-- ============================================================
-- ANIME ORIGINS WAVE RECON v0.1
-- Run inside a match while the current wave is visible.
-- ============================================================

local VERSION = "0.1"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local out = {}

local function push(text)
    out[#out + 1] = tostring(text)
    print("[AO WAVE] " .. tostring(text))
end

local function fullName(object)
    local ok, value = pcall(function() return object:GetFullName() end)
    return ok and value or tostring(object)
end

local function isVisible(object)
    local current = object
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("LayerCollector") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local function attributes(object)
    local parts = {}
    for key, value in pairs(object:GetAttributes()) do
        parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ",") or "-"
end

push("===== ANIME ORIGINS WAVE RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId))

push("===== VISIBLE WAVE/ROUND TEXT =====")
local textMatches = 0
if playerGui then
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            local text = tostring(object.Text or "")
            local lower = string.lower(text)
            local nameLower = string.lower(object.Name)
            local looksNumeric = text:match("^%s*%d+%s*/%s*%d+%s*$") or text:match("^%s*%d+%s*$")
            local looksWave = lower:find("wave", 1, true) or lower:find("round", 1, true) or
                nameLower:find("wave", 1, true) or nameLower:find("round", 1, true)

            if isVisible(object) and (looksNumeric or looksWave) then
                textMatches += 1
                local position, size = object.AbsolutePosition, object.AbsoluteSize
                push(string.format(
                    "TEXT #%d path=%s | Text=%q | Pos=%d,%d | Size=%d,%d | Attr=%s",
                    textMatches,
                    fullName(object),
                    text,
                    position.X, position.Y,
                    size.X, size.Y,
                    attributes(object)
                ))
            end
        end
    end
end
push("TextMatches=" .. tostring(textMatches))

push("===== WAVE/ROUND VALUE INSTANCES =====")
local valueMatches = 0
for _, root in ipairs({playerGui, RS, workspace}) do
    if root then
        for _, object in ipairs(root:GetDescendants()) do
            local lower = string.lower(object.Name)
            if lower:find("wave", 1, true) or lower:find("round", 1, true) then
                local value = ""
                if object:IsA("IntValue") or object:IsA("NumberValue") or object:IsA("StringValue") or object:IsA("BoolValue") then
                    value = tostring(object.Value)
                end
                valueMatches += 1
                if valueMatches <= 150 then
                    push(string.format(
                        "VALUE #%d %s %q value=%q Attr=%s",
                        valueMatches,
                        object.ClassName,
                        fullName(object),
                        value,
                        attributes(object)
                    ))
                end
            end
        end
    end
end
push("ValueMatches=" .. tostring(valueMatches))

push("===== WAVE/REPLAY/RESTART REMOTES =====")
local remoteMatches = 0
for _, object in ipairs(RS:GetDescendants()) do
    if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
        local lower = string.lower(object.Name)
        if lower:find("wave", 1, true) or lower:find("round", 1, true) or
            lower:find("replay", 1, true) or lower:find("restart", 1, true) or
            lower:find("retry", 1, true) then
            remoteMatches += 1
            push(string.format("REMOTE #%d %s %q", remoteMatches, object.ClassName, fullName(object)))
        end
    end
end
push("RemoteMatches=" .. tostring(remoteMatches))

local blob = table.concat(out, "\n")
local copied = false
for _, copyFunction in ipairs({setclipboard, toclipboard, writeclipboard}) do
    if type(copyFunction) == "function" and pcall(copyFunction, blob) then
        copied = true
        break
    end
end

local saved = false
if type(writefile) == "function" then
    saved = pcall(writefile, "anime_origins_wave_recon.txt", blob)
end

print(string.format("[AO WAVE] DONE copy=%s file=%s lines=%d", tostring(copied), tostring(saved), #out))
