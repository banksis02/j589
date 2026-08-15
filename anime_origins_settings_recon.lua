-- ============================================================
-- ANIME ORIGINS SETTINGS RECON v0.3
-- Open Settings > Gameplay before running.
-- ============================================================

local VERSION = "0.3"
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

local function normalize(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

push("===== ANIME ORIGINS SETTINGS RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId))

local scanOK, scanError = pcall(function()
    local searchRoot = settings or playerGui
    if not searchRoot then
        push("ERROR: PlayerGui not found")
        return
    end

    push("SearchRoot=" .. fullName(searchRoot))
    local wanted = {
        "AutoSkipWave",
        "AutoSkipWaves",
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
        "ShowMaxRange",
        "PhantomPlacement",
        "ShowUnitStatsOnHover",
        "AutoUpgradeOnPlacement",
        "AutoUpgradeDropdownMenu",
        "SellFarmUnitsOnLastWave",
        "GraphicsQualityLobby",
        "GraphicsQualityGame",
        "HideAllVFX",
        "HideOthersVFX",
        "WindowFocusTracking",
        "HideOthersPetsLobby",
        "SkipRiftAnimationLobby",
        "MovementStyle",
        "HideEnemyTags",
        "HideDamageIndicators",
        "HideBossEntrance",
        "DeathAnimations",
    }

    local detectedScreen = nil

    for _, wantedName in ipairs(wanted) do
        push("===== OPTION " .. wantedName .. " =====")
        local matches = {}
        local target = normalize(wantedName)
        for _, object in ipairs(searchRoot:GetDescendants()) do
            local nameMatch = normalize(object.Name)
            local textMatch = ""
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                textMatch = normalize(object.Text)
            end

            if nameMatch == target or textMatch == target or
                nameMatch == target .. "s" or target == nameMatch .. "s" or
                textMatch == target .. "s" or target == textMatch .. "s" then
                matches[#matches + 1] = object
            end
        end

        if #matches == 0 then
            push("NOT FOUND")
        else
            for _, match in ipairs(matches) do
                detectedScreen = detectedScreen or match:FindFirstAncestorOfClass("ScreenGui")
                push(details(match))
                for _, object in ipairs(match:GetDescendants()) do
                    if object:IsA("GuiObject") or object:IsA("ValueBase") then
                        push("  " .. details(object))
                    end
                end

                local parent = match.Parent
                for level = 1, 3 do
                    if not parent then break end
                    push(string.format("  ANCESTOR%d %s", level, details(parent)))
                    for _, child in ipairs(parent:GetChildren()) do
                        if child:IsA("GuiObject") or child:IsA("ValueBase") then
                            push("    CHILD " .. details(child))
                        end
                    end
                    parent = parent.Parent
                end
            end
        end
    end

    push("===== SETTINGS GUI BUTTONS =====")
    local buttonRoot = settings or detectedScreen or searchRoot
    push("ButtonRoot=" .. fullName(buttonRoot))
    for _, object in ipairs(buttonRoot:GetDescendants()) do
        if object:IsA("GuiButton") then push(details(object)) end
    end
end)

if not scanOK then
    push("SCAN ERROR: " .. tostring(scanError))
end

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
    saved = pcall(writefile, "anime_origins_settings_recon.txt", blob)
end

print(string.format("[AO SETTINGS] DONE copy=%s file=%s lines=%d", tostring(copied), tostring(saved), #out))
