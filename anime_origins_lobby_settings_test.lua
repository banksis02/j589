-- ============================================================
-- ANIME ORIGINS LOBBY SETTINGS TEST v0.2
-- Applies settings only in the Anime Origins lobby.
-- ============================================================

local VERSION = "0.4"
local LOBBY_PLACE_ID = 129932912185311
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

print("[AO SETTINGS v" .. VERSION .. "] loaded PlaceId=" .. tostring(game.PlaceId))

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AO Settings v" .. VERSION,
            Text = tostring(text),
            Duration = 7,
        })
    end)
end

local function normalize(value)
    return string.lower(tostring(value or "")):gsub("[%s%p]", "")
end

local function waitForSettings(timeout)
    local deadline = os.clock() + (timeout or 30)
    repeat
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        local settings = playerGui and playerGui:FindFirstChild("SettingsFrame", true)
        if settings then return settings end
        task.wait(0.5)
    until os.clock() >= deadline
    return nil
end

local function fireButton(button)
    if not button or not button:IsA("GuiButton") then return false, "button missing" end

    local signalFunction = getgenv and getgenv().firesignal or _G.firesignal
    if type(signalFunction) == "function" then
        local ok = pcall(signalFunction, button.MouseButton1Click)
        if ok then return true, "firesignal" end
    end

    local connectionFunction = getgenv and getgenv().getconnections or _G.getconnections
    if type(connectionFunction) == "function" then
        local ok, connections = pcall(connectionFunction, button.MouseButton1Click)
        if ok then
            for _, connection in ipairs(connections) do
                local fired = false
                if type(connection.Fire) == "function" then
                    fired = pcall(function() connection:Fire() end)
                elseif type(connection.Function) == "function" then
                    fired = pcall(connection.Function)
                end
                if fired then return true, "connection" end
            end
        end
    end

    if button.Visible and button.AbsoluteSize.X > 0 and button.AbsoluteSize.Y > 0 then
        local x = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
        local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2
        local ok = pcall(function()
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
            task.wait(0.08)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        if ok then return true, "mouse" end
    end

    return false, "no supported click method"
end

local function findOption(settings, candidateNames)
    for _, name in ipairs(candidateNames) do
        local object = settings:FindFirstChild(name, true)
        if object and object:IsA("Frame") then return object, name end
    end
    return nil, table.concat(candidateNames, "/")
end

local function toggleState(option)
    local main = option and option:FindFirstChild("Main")
    local toggle = main and main:FindFirstChild("Toggle")
    local button = toggle and toggle:FindFirstChild("Button")
    if not button or not button:IsA("GuiButton") then return nil, nil end

    local onIcon = button:FindFirstChild("On")
    local offIcon = button:FindFirstChild("Off")
    if onIcon and onIcon:IsA("GuiObject") and offIcon and offIcon:IsA("GuiObject") then
        if onIcon.Visible ~= offIcon.Visible then return onIcon.Visible, button end
    end

    local design = button:FindFirstChild("DesignStuff")
    local mainColor = design and design:FindFirstChild("MainColor")
    local onGradient = mainColor and mainColor:FindFirstChild("On")
    local offGradient = mainColor and mainColor:FindFirstChild("Off")
    if onGradient and onGradient:IsA("UIGradient") and
        offGradient and offGradient:IsA("UIGradient") and
        onGradient.Enabled ~= offGradient.Enabled then
        return onGradient.Enabled, button
    end

    return nil, button
end

local function setToggle(settings, names, desired)
    local option, label = findOption(settings, names)
    if not option then
        print("[AO SETTINGS] NOT FOUND " .. label)
        return false
    end

    for attempt = 1, 6 do
        local current, button = toggleState(option)
        if current == desired then
            print(string.format("[AO SETTINGS] OK %-30s = %s", option.Name, desired and "ON" or "OFF"))
            return true
        end
        if current == nil then
            -- toggle ยังไม่พร้อม (เพิ่ง teleport เข้า lobby / SettingsFrame ยังโหลด icon ไม่ครบ)
            -- → รอแล้วลองใหม่ แทนที่จะเลิกทันที (เดิมเลิก = บางไอดี AutoStart ไม่เปิด)
            print(string.format("[AO SETTINGS] WAIT %-28s state ยังไม่พร้อม (รอบ %d)", option.Name, attempt))
            task.wait(0.45)
        else
            local clicked, method = fireButton(button)
            print(string.format("[AO SETTINGS] SET %-29s %s via %s", option.Name, desired and "ON" or "OFF", method))
            if not clicked then return false end
            task.wait(0.35)
        end
    end

    local current = toggleState(option)
    local success = current == desired
    print("[AO SETTINGS] VERIFY " .. option.Name .. " = " .. tostring(success))
    return success
end

local function selectorText(option)
    local main = option and option:FindFirstChild("Main")
    local toggle = main and main:FindFirstChild("Toggle")
    local label = toggle and toggle:FindFirstChild("TextLabel")
    if label and label:IsA("TextLabel") then return tostring(label.Text), toggle end
    return nil, toggle
end

local function isLow(text)
    local value = normalize(text)
    return value == "low" or value == "ต่ำ"
end

local function setLow(settings, names)
    local option, label = findOption(settings, names)
    if not option then
        print("[AO SETTINGS] NOT FOUND " .. label)
        return false
    end

    for _ = 1, 6 do
        local text, toggle = selectorText(option)
        if text and isLow(text) then
            print(string.format("[AO SETTINGS] OK %-30s = %s", option.Name, text))
            return true
        end

        local previous = toggle and toggle:FindFirstChild("Previous")
        local clicked, method = fireButton(previous)
        print(string.format("[AO SETTINGS] LOW %-29s current=%s via %s", option.Name, tostring(text), method))
        if not clicked then return false end
        task.wait(0.35)
    end

    local text = selectorText(option)
    local success = text and isLow(text) or false
    print("[AO SETTINGS] VERIFY " .. option.Name .. " = " .. tostring(text))
    return success
end

local TARGET_TOGGLES = {
    {{"AutoSkipWave"}, true},
    {{"AutoStartGame"}, true},
    {{"AutoNextGame"}, false},
    {{"AutoReplayGame"}, true},
    {{"SkipSummonCutscene"}, true},
    {{"SummonMax"}, true},
    {{"SkipGameCutscene"}, false},
    {{"HidePathMarkers"}, false},
    {{"ShowGuide"}, true},

    {{"ShowMaxRange"}, true},
    {{"SelectUnitOnPlacement"}, true},
    {{"PhantomPlacement"}, true},
    {{"UnitHover"}, true},
    {{"AutoUpgradeOnPlacement"}, true},
    {{"AutoUpgradeDropDown"}, false},
    {{"SellFarms"}, false},

    {{"HideVFX"}, true},
    {{"HideOtherVFX"}, true},
    {{"WindowFocusTracking"}, false},
    {{"HideOtherPets"}, true},
    {{"SkipRiftCutscene"}, false},

    {{"HideEnemyTag"}, true},
    {{"HideDamageIndicator"}, true},
    {{"SkipBossEntrance"}, false},
    {{"EnemyDeath"}, true},
}

local TARGET_LOW = {
    {"GraphicsQuality"},
    {"GraphicsQualityGame"},
    {"EnemyMovement"},
}

local function applyLobbySettings()
    if game.PlaceId ~= LOBBY_PLACE_ID then
        print("[AO SETTINGS v" .. VERSION .. "] SKIP: not lobby")
        return false, "not lobby"
    end

    local settings = waitForSettings(30)
    if not settings then
        notify("ไม่พบ SettingsFrame")
        warn("[AO SETTINGS v" .. VERSION .. "] SettingsFrame not found")
        return false, "SettingsFrame not found"
    end

    -- ⭐ Legend: ปิด AutoUpgradeOnPlacement ของเกม (module วางตัวจัดการอัพเกรดเอง —
    --    ตัวเงินจน max ก่อน แล้วค่อยดาเมจ). โหมดอื่น (gem/battlepass) เปิดปกติ.
    local legendMode = tostring(_G.AO_PLACE_MODE) == "ao_legend"

    local successCount = 0
    local total = #TARGET_TOGGLES + #TARGET_LOW
    for _, entry in ipairs(TARGET_TOGGLES) do
        local want = entry[2]
        if entry[1][1] == "AutoUpgradeOnPlacement" and legendMode then
            want = false
        end
        if setToggle(settings, entry[1], want) then successCount += 1 end
        task.wait(0.08)
    end
    for _, names in ipairs(TARGET_LOW) do
        if setLow(settings, names) then successCount += 1 end
        task.wait(0.08)
    end

    local message = string.format("ตั้งค่า Lobby สำเร็จ %d/%d", successCount, total)
    print("[AO SETTINGS v" .. VERSION .. "] " .. message)
    notify(message)
    return successCount == total, message
end

_G.AO_APPLY_LOBBY_SETTINGS = applyLobbySettings

if game.PlaceId == LOBBY_PLACE_ID and _G.AO_SETTINGS_MANUAL ~= true then
    task.spawn(applyLobbySettings)
else
    print("[AO SETTINGS v" .. VERSION .. "] game map detected; settings untouched")
end
