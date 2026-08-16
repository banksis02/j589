-- ============================================================
-- ANIME ORIGINS BATTLEPASS RECON v0.1
-- Run inside an Anime Origins match (PlaceId 116173040971120).
-- Searches replicated/client state without changing game data.
-- ============================================================

local VERSION = "0.1"
local AO_GAME_PLACE_ID = 116173040971120
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

local output = {}
local MAX_LINES = 900
local counters = {
    gui = 0,
    attributes = 0,
    values = 0,
    instances = 0,
    modules = 0,
    tables = 0,
}

local function push(text)
    if #output >= MAX_LINES then return end
    text = tostring(text)
    output[#output + 1] = text
    print("[AO BP] " .. text)
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local keywords = {
    "battlepass", "battle pass", "seasonpass", "season pass",
    "passxp", "pass xp", "passlevel", "pass level", "tier",
    "battle_pass", "battle-pass", "seasonxp", "season xp",
    "แบทเทิลพาส", "แบทเทิล", "ซีซันพาส", "ซีซัน",
}

local function relevant(value)
    local text = lower(value)
    for _, keyword in ipairs(keywords) do
        if string.find(text, keyword, 1, true) then return true end
    end
    return false
end

local function safeFullName(instance)
    local ok, result = pcall(function() return instance:GetFullName() end)
    return ok and result or tostring(instance)
end

local function isOnScreen(instance)
    local current = instance
    while current and current ~= game do
        if current:IsA("GuiObject") and current.Visible == false then return false end
        if current:IsA("LayerCollector") and current.Enabled == false then return false end
        current = current.Parent
    end
    return true
end

local function shortValue(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    local kind = typeof(value)
    if kind ~= "table" then
        local text = tostring(value)
        return #text > 240 and (string.sub(text, 1, 240) .. "...") or text
    end
    if seen[value] then return "{cycle}" end
    if depth >= 2 then return "{table}" end
    seen[value] = true
    local parts = {}
    local count = 0
    for key, child in pairs(value) do
        count += 1
        if count > 20 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = tostring(key) .. "=" .. shortValue(child, depth + 1, seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function scanAttributes(instance, section)
    local ok, attributes = pcall(function() return instance:GetAttributes() end)
    if not ok then return end
    for key, value in pairs(attributes) do
        if relevant(key) or relevant(value) or relevant(safeFullName(instance)) then
            counters.attributes += 1
            push(("ATTR [%s] %s.%s = %s")
                :format(section, safeFullName(instance), tostring(key), shortValue(value)))
        end
    end
end

push("===== ANIME ORIGINS BATTLEPASS RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId) .. " | Expected=" .. tostring(AO_GAME_PLACE_ID))
push("Player=" .. tostring(player and player.Name or "nil"))
if game.PlaceId ~= AO_GAME_PLACE_ID then
    push("WARNING: ไม่ได้อยู่ PlaceId ในด่าน Anime Origins")
end

push("\n===== [1] PLAYER / GUI =====")
if player then
    scanAttributes(player, "Player")
    for _, instance in ipairs(player:GetDescendants()) do
        scanAttributes(instance, "Player")
        local path = safeFullName(instance)
        if instance:IsA("ValueBase") then
            local ok, value = pcall(function() return instance.Value end)
            if ok and (relevant(instance.Name) or relevant(path) or relevant(value)) then
                counters.values += 1
                push(("VALUE %s %s = %s"):format(instance.ClassName, path, shortValue(value)))
            end
        end
    end
end

if playerGui then
    for _, instance in ipairs(playerGui:GetDescendants()) do
        if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
            local ok, text = pcall(function() return instance.Text end)
            if ok and (relevant(text) or relevant(instance.Name) or relevant(safeFullName(instance))) then
                counters.gui += 1
                push(("GUI visible=%s | %s | Text=%q")
                    :format(tostring(isOnScreen(instance)), safeFullName(instance), tostring(text)))
            end
        elseif relevant(instance.Name) or relevant(safeFullName(instance)) then
            counters.instances += 1
            push(("GUI INSTANCE %s '%s'"):format(instance.ClassName, safeFullName(instance)))
        end
    end
end

push("\n===== [2] REPLICATEDSTORAGE CANDIDATES =====")
for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do
    local path = safeFullName(instance)
    scanAttributes(instance, "RS")
    if relevant(instance.Name) or relevant(path) then
        counters.instances += 1
        push(("RS %s '%s'"):format(instance.ClassName, path))
        if instance:IsA("ValueBase") then
            local ok, value = pcall(function() return instance.Value end)
            if ok then
                counters.values += 1
                push("  Value=" .. shortValue(value))
            end
        end
    end
end

local tableSeen = {}
local tableNodes = 0
local function scanTable(label, value, path, depth)
    if type(value) ~= "table" or tableSeen[value] or depth > 5 or tableNodes > 50000 then return end
    tableSeen[value] = true
    for key, child in pairs(value) do
        tableNodes += 1
        if tableNodes > 50000 or #output >= MAX_LINES then break end
        local childPath = path .. "." .. tostring(key)
        if relevant(key) or (type(child) == "string" and relevant(child)) then
            counters.tables += 1
            push(("TABLE [%s] %s = %s"):format(label, childPath, shortValue(child)))
        end
        if type(child) == "table" then scanTable(label, child, childPath, depth + 1) end
    end
end

push("\n===== [3] LOADED MODULE TABLES =====")
if type(getloadedmodules) == "function" then
    local ok, modules = pcall(getloadedmodules)
    if ok and type(modules) == "table" then
        for _, module in ipairs(modules) do
            local path = safeFullName(module)
            if relevant(module.Name) or relevant(path) then
                counters.modules += 1
                push("MODULE " .. path)
                local required, value = pcall(require, module)
                if required and type(value) == "table" then
                    scanTable(path, value, path, 0)
                else
                    push("  require=" .. (required and typeof(value) or ("ERROR " .. tostring(value))))
                end
            end
        end
    else
        push("getloadedmodules ใช้งานไม่ได้: " .. tostring(modules))
    end
else
    push("executor ไม่มี getloadedmodules")
end

push("\n===== [4] GLOBAL / MEMORY TABLES =====")
local environments = { _G = _G, shared = shared }
if type(getgenv) == "function" then
    local ok, environment = pcall(getgenv)
    if ok then environments.genv = environment end
end
for name, environment in pairs(environments) do
    if type(environment) == "table" then scanTable(name, environment, name, 0) end
end

if type(getgc) == "function" then
    local ok, objects = pcall(getgc, true)
    local scanned = 0
    if ok and type(objects) == "table" then
        for index, object in ipairs(objects) do
            if type(object) == "table" then
                scanned += 1
                -- Inspect top-level keys first; recurse only after a relevant key is found.
                local matched = false
                for key, child in pairs(object) do
                    if relevant(key) or (type(child) == "string" and relevant(child)) then
                        matched = true
                        counters.tables += 1
                        push(("GC[%d].%s = %s"):format(index, tostring(key), shortValue(child)))
                    end
                end
                if matched then scanTable("GC" .. tostring(index), object, "GC" .. tostring(index), 0) end
            end
            if #output >= MAX_LINES then break end
        end
        push("getgc tables scanned=" .. tostring(scanned))
    else
        push("getgc ใช้งานไม่ได้: " .. tostring(objects))
    end
else
    push("executor ไม่มี getgc")
end

push("\n===== SUMMARY =====")
push(("GUI=%d | ATTR=%d | VALUE=%d | INSTANCE=%d | MODULE=%d | TABLE=%d")
    :format(counters.gui, counters.attributes, counters.values, counters.instances, counters.modules, counters.tables))

local blob = table.concat(output, "\n")
local copied = false
for _, copyFunction in ipairs({ setclipboard, toclipboard, writeclipboard }) do
    if type(copyFunction) == "function" and pcall(copyFunction, blob) then
        copied = true
        break
    end
end

local saved = false
if type(writefile) == "function" then
    saved = pcall(writefile, "anime_origins_battlepass_recon.txt", blob)
end

print(("[AO BP] DONE | copied=%s | saved=%s | lines=%d")
    :format(tostring(copied), tostring(saved), #output))
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "AO Battlepass Recon v" .. VERSION,
        Text = copied and "คัดลอกผลแล้ว" or (saved and "บันทึกไฟล์แล้ว" or "ดูผลใน F9"),
        Duration = 8,
    })
end)

return blob
