-- ============================================================
-- ANIME ORIGINS WAVE + SPEED UI RECON v0.1
-- Run inside a match while wave and speed controls are visible.
-- ============================================================

local VERSION = "0.1"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local gameUI = playerGui and playerGui:FindFirstChild("GameUI")
local topUI = gameUI and gameUI:FindFirstChild("TopUI")
local out = {}

local function push(value)
    out[#out + 1] = tostring(value)
    print("[AO WS] " .. tostring(value))
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

local function guiDetails(object)
    local details = {
        object.ClassName .. " " .. string.format("%q", object.Name),
        "path=" .. fullName(object),
        "attr=" .. attrs(object),
    }

    if object:IsA("GuiObject") then
        details[#details + 1] = string.format(
            "visible=%s active=%s pos=%d,%d size=%d,%d z=%d",
            tostring(object.Visible),
            tostring(object.Active),
            object.AbsolutePosition.X,
            object.AbsolutePosition.Y,
            object.AbsoluteSize.X,
            object.AbsoluteSize.Y,
            object.ZIndex
        )
    end

    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        details[#details + 1] = "text=" .. string.format("%q", tostring(object.Text))
    end

    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        details[#details + 1] = "image=" .. string.format("%q", tostring(object.Image))
        details[#details + 1] = "color=" .. tostring(object.ImageColor3)
    end

    if object:IsA("GuiButton") then
        local activated, click, down = -1, -1, -1
        if type(getconnections) == "function" then
            pcall(function() activated = #getconnections(object.Activated) end)
            pcall(function() click = #getconnections(object.MouseButton1Click) end)
            pcall(function() down = #getconnections(object.MouseButton1Down) end)
        end
        details[#details + 1] = string.format("connections=Activated:%d Click:%d Down:%d", activated, click, down)
    end

    return table.concat(details, " | ")
end

local function dumpTree(title, root)
    push("===== " .. title .. " =====")
    if not root then
        push("NOT FOUND")
        return
    end

    push(guiDetails(root))
    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("GuiObject") or object:IsA("ValueBase") then
            local line = guiDetails(object)
            if object:IsA("ValueBase") then line = line .. " | value=" .. tostring(object.Value) end
            push(line)
        end
    end
end

push("===== ANIME ORIGINS WAVE + SPEED RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId))

local info = topUI and topUI:FindFirstChild("Info")
local wave = info and info:FindFirstChild("Wave")
local timer = topUI and topUI:FindFirstChild("Timer")

dumpTree("TOPUI.INFO.WAVE", wave)
dumpTree("TOPUI.TIMER", timer)

push("===== ALL TOPUI TEXT + BUTTONS =====")
if topUI then
    for _, object in ipairs(topUI:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("GuiButton") then
            push(guiDetails(object))
        end
    end
else
    push("TopUI NOT FOUND")
end

push("===== SPEED/WAVE/SKIP NAMED INSTANCES =====")
local named = 0
for _, root in ipairs({playerGui, RS, workspace}) do
    if root then
        for _, object in ipairs(root:GetDescendants()) do
            local lower = string.lower(object.Name)
            if lower:find("speed", 1, true) or lower:find("wave", 1, true) or
                lower:find("skip", 1, true) or lower:find("timescale", 1, true) then
                named += 1
                if named <= 250 then
                    local line = guiDetails(object)
                    if object:IsA("ValueBase") then line = line .. " | value=" .. tostring(object.Value) end
                    push(line)
                end
            end
        end
    end
end
push("NamedMatches=" .. tostring(named))

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
    saved = pcall(writefile, "anime_origins_wave_speed_recon.txt", blob)
end

print(string.format("[AO WS] DONE copy=%s file=%s lines=%d", tostring(copied), tostring(saved), #out))
