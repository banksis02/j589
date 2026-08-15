-- ANIME ORIGINS HOTBAR RECON v0.1
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:FindFirstChildOfClass("PlayerGui")
local output = {}

local function add(text)
    text = tostring(text)
    output[#output + 1] = text
    print("[AO HOTBAR] " .. text)
end

local function attrs(object)
    local values = {}
    for key, value in pairs(object:GetAttributes()) do
        values[#values + 1] = tostring(key) .. "=" .. tostring(value)
    end
    table.sort(values)
    return #values > 0 and table.concat(values, ", ") or "-"
end

add("===== ANIME ORIGINS HOTBAR RECON v0.1 =====")

local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
local hud = mainUI and mainUI:FindFirstChild("HUD")
local bottomUI = hud and hud:FindFirstChild("BottomUI")
local toolbar = bottomUI and bottomUI:FindFirstChild("TowersToolbar")

if not toolbar then
    add("ERROR: TowersToolbar not found")
else
    add("Toolbar=" .. toolbar:GetFullName())

    for slot = 1, 6 do
        local button = toolbar:FindFirstChild("Tower" .. tostring(slot))
        add("\n===== TOWER" .. slot .. " =====")

        if not button then
            add("NOT FOUND")
        else
            add("Path=" .. button:GetFullName())
            add("Class=" .. button.ClassName .. " | Attributes=" .. attrs(button))

            for _, object in ipairs(button:GetDescendants()) do
                local information = nil

                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    if tostring(object.Text) ~= "" then
                        information = "Text=" .. string.format("%q", tostring(object.Text))
                    end
                elseif object:IsA("StringValue") or object:IsA("ObjectValue") or object:IsA("NumberValue") or object:IsA("BoolValue") then
                    information = "Value=" .. tostring(object.Value)
                end

                local objectAttrs = attrs(object)
                local lowerName = string.lower(object.Name)
                if information or objectAttrs ~= "-" or lowerName:find("unit") or lowerName:find("tower") or lowerName:find("leorio") then
                    add(object.ClassName .. " '" .. object:GetFullName() .. "' | " .. tostring(information or "") .. " | Attr=" .. objectAttrs)
                end
            end
        end
    end
end

add("\n===== LEORIO / TYPE MATCHES IN PLAYERGUI =====")
if playerGui then
    local count = 0
    for _, object in ipairs(playerGui:GetDescendants()) do
        local matched = string.lower(object.Name):find("leorio", 1, true) ~= nil
        local text = ""

        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            text = tostring(object.Text)
            local lower = string.lower(text)
            if lower:find("leorio", 1, true) or lower == "grnd" or lower == "ground" or lower == "hill" then
                matched = true
            end
        end

        local objectAttrs = attrs(object)
        if objectAttrs:lower():find("leorio", 1, true) or objectAttrs:lower():find("ground", 1, true) or objectAttrs:lower():find("hill", 1, true) then
            matched = true
        end

        if matched then
            count += 1
            add(object.ClassName .. " '" .. object:GetFullName() .. "' | Text=" .. string.format("%q", text) .. " | Attr=" .. objectAttrs)
        end
    end
    add("Matched=" .. tostring(count))
end

add("\n===== LEORIO INSTANCES IN REPLICATEDSTORAGE =====")
local RS = game:GetService("ReplicatedStorage")
local rsCount = 0
for _, object in ipairs(RS:GetDescendants()) do
    if string.lower(object.Name):find("leorio", 1, true) then
        rsCount += 1
        add(object.ClassName .. " '" .. object:GetFullName() .. "' | Attr=" .. attrs(object))
    end
end
add("Matched=" .. tostring(rsCount))

local result = table.concat(output, "\n")
local copied = false
for _, fn in ipairs({setclipboard, toclipboard, writeclipboard}) do
    if type(fn) == "function" and pcall(fn, result) then
        copied = true
        break
    end
end
if type(writefile) == "function" then
    pcall(writefile, "ao_hotbar_recon.txt", result)
end
print("[AO HOTBAR] DONE | Clipboard=" .. tostring(copied))
