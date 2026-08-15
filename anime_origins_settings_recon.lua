-- ============================================================
-- ANIME ORIGINS SETTINGS RECON v0.1
-- Open Settings > Gameplay before running.
-- ============================================================

local VERSION = "0.1"
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
local settings = mainUI and mainUI:FindFirstChild("SettingsFrame")
local out = {}

local function push(value)
    out[#out + 1] = tostring(value)
    print("[AO SETTINGS] " .. tostring(value))
end

local function fullName(object)
    local ok, value = pcall(function() return object:GetFullName() end)
    return ok and value or tostring(object)
end

local function attrs(object)
    local values = {}
    for key, value in pairs(object:GetAttributes()) do
        values[#values + 1] = tostring(key) .. "=" .. tostring(value)
    end
    table.sort(values)
    return #values > 0 and table.concat(values, ",") or "-"
end

local function details(object)
    local values = {
        object.ClassName .. " " .. string.format("%q", object.Name),
        "path=" .. fullName(object),
        "attr=" .. attrs(object),
    }

    if object:IsA("GuiObject") then
        values[#values + 1] = string.format(
            "visible=%s active=%s pos=%d,%d size=%d,%d bg=%s",
            tostring(object.Visible), tostring(object.Active),
            object.AbsolutePosition.X, object.AbsolutePosition.Y,
            object.AbsoluteSize.X, object.AbsoluteSize.Y,
            tostring(object.BackgroundColor3)
        )
    end

    if object:IsA("TextLabel") or object:IsA("TextButton") then
        values[#values + 1] = "text=" .. string.format("%q", tostring(object.Text))
        values[#values + 1] = "textColor=" .. tostring(object.TextColor3)
    end

    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        values[#values + 1] = "image=" .. string.format("%q", tostring(object.Image))
        values[#values + 1] = "imageColor=" .. tostring(object.ImageColor3)
    end

    if object:IsA("GuiButton") then
        local activated, click, down = -1, -1, -1
        if type(getconnections) == "function" then
            pcall(function() activated = #getconnections(object.Activated) end)
            pcall(function() click = #getconnections(object.MouseButton1Click) end)
            pcall(function() down = #getconnections(object.MouseButton1Down) end)
        end
        values[#values + 1] = string.format("connections=A:%d C:%d D:%d", activated, click, down)
    end

    if object:IsA("ValueBase") then values[#values + 1] = "value=" .. tostring(object.Value) end
    return table.concat(values, " | ")
end

push("===== ANIME ORIGINS SETTINGS RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId))

if not settings then
    push("ERROR: MainUI.SettingsFrame not found")
else
    local wanted = {
        "AutoSkipWave",
        "AutoStartGame",
        "AutoNextGame",
        "AutoReplayGame",
        "SkipSummonCutscene",
        "SkipSummonAnimation",
        "SkipGameCutscene",
        "SkipGameCutscenes",
        "HidePathMarkers",
        "InGameGuide",
        "SelectUnitOnPlacement",
    }

    for _, wantedName in ipairs(wanted) do
        push("===== OPTION " .. wantedName .. " =====")
        local matches = {}
        for _, object in ipairs(settings:GetDescendants()) do
            if string.lower(object.Name) == string.lower(wantedName) then
                matches[#matches + 1] = object
            end
        end

        if #matches == 0 then
            push("NOT FOUND")
        else
            for _, match in ipairs(matches) do
                push(details(match))
                for _, object in ipairs(match:GetDescendants()) do
                    if object:IsA("GuiObject") or object:IsA("ValueBase") then
                        push("  " .. details(object))
                    end
                end
            end
        end
    end

    push("===== SETTINGS GUI BUTTONS =====")
    for _, object in ipairs(settings:GetDescendants()) do
        if object:IsA("GuiButton") then push(details(object)) end
    end
end

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
    saved = pcall(writefile, "anime_origins_settings_recon.txt", blob)
end

print(string.format("[AO SETTINGS] DONE copy=%s file=%s lines=%d", tostring(copied), tostring(saved), #out))
