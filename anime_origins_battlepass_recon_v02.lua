-- ============================================================
-- ANIME ORIGINS BATTLEPASS RECON v0.2
-- Run inside a match (PlaceId 116173040971120).
-- Read-only: checks exact Battlepass config and live client state.
-- ============================================================

local VERSION = "0.2"
local AO_GAME_PLACE_ID = 116173040971120
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

local lines = {}
local MAX_LINES = 650
local function push(value)
    if #lines >= MAX_LINES then return end
    value = tostring(value)
    lines[#lines + 1] = value
    print("[AO BP2] " .. value)
end

local function fullName(instance)
    local ok, value = pcall(function() return instance:GetFullName() end)
    return ok and value or tostring(instance)
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

-- Excludes broad "tier" because it matched artifact UI in v0.1.
local exactWords = {
    "battlepass", "battle pass", "battle_pass", "battle-pass",
    "seasonpass", "season pass", "season_pass", "season-pass",
    "passxp", "pass xp", "passlevel", "pass level",
    "seasonxp", "season xp", "แบทเทิลพาส", "ซีซันพาส",
}

local function isRelevant(value)
    local text = lower(value)
    for _, word in ipairs(exactWords) do
        if string.find(text, word, 1, true) then return true end
    end
    return false
end

local function compact(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if type(value) ~= "table" then
        local text = tostring(value)
        if #text > 220 then text = string.sub(text, 1, 220) .. "..." end
        return text
    end
    if seen[value] then return "{cycle}" end
    if depth >= 3 then return "{table}" end
    seen[value] = true
    local parts, count = {}, 0
    for key, child in pairs(value) do
        count += 1
        if count > 24 then parts[#parts + 1] = "..." break end
        parts[#parts + 1] = tostring(key) .. "=" .. compact(child, depth + 1, seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function finish()
    local blob = table.concat(lines, "\n")
    local copied = false
    for _, copyFunction in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(copyFunction) == "function" and pcall(copyFunction, blob) then copied = true break end
    end
    local saved = false
    if type(writefile) == "function" then
        saved = pcall(writefile, "anime_origins_battlepass_recon_v02.txt", blob)
    end
    print(("[AO BP2] DONE | copied=%s | saved=%s | lines=%d")
        :format(tostring(copied), tostring(saved), #lines))
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AO Battlepass Recon v" .. VERSION,
            Text = copied and "คัดลอกผลแล้ว" or (saved and "บันทึกไฟล์ v02 แล้ว" or "ดูผลใน F9"),
            Duration = 8,
        })
    end)
    return blob
end

push("===== ANIME ORIGINS BATTLEPASS RECON v" .. VERSION .. " =====")
push("PlaceId=" .. tostring(game.PlaceId) .. " | Expected=" .. tostring(AO_GAME_PLACE_ID))
push("Player=" .. tostring(player and player.Name or "nil"))
if game.PlaceId ~= AO_GAME_PLACE_ID then push("WARNING: ต้องรันตอนอยู่ในด่าน Anime Origins") end

push("\n===== [1] EXACT INSTANCES / REMOTES =====")
local exactInstanceCount = 0
for _, root in ipairs({ player, ReplicatedStorage }) do
    if root then
        local all = { root }
        for _, instance in ipairs(root:GetDescendants()) do all[#all + 1] = instance end
        for _, instance in ipairs(all) do
            local path = fullName(instance)
            if isRelevant(instance.Name) or isRelevant(path) then
                exactInstanceCount += 1
                push(("%s '%s'"):format(instance.ClassName, path))
                if instance:IsA("ValueBase") then
                    local ok, value = pcall(function() return instance.Value end)
                    if ok then push("  Value=" .. compact(value)) end
                end
                local ok, attributes = pcall(function() return instance:GetAttributes() end)
                if ok then
                    for key, value in pairs(attributes) do
                        push(("  Attr.%s=%s"):format(tostring(key), compact(value)))
                    end
                end
            end
        end
    end
end
push("ExactInstanceCount=" .. tostring(exactInstanceCount))

push("\n===== [2] BattlepassInfo REQUIRE =====")
local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
local battlepassModule = modulesFolder and modulesFolder:FindFirstChild("BattlepassInfo")
local battlepassInfo
if battlepassModule and battlepassModule:IsA("ModuleScript") then
    local ok, value = pcall(require, battlepassModule)
    if ok then
        battlepassInfo = value
        push("require=OK type=" .. typeof(value))
        push("FULL=" .. compact(value, 0, {}))
        if type(value) == "table" then
            local keys = {}
            for key in pairs(value) do keys[#keys + 1] = tostring(key) end
            table.sort(keys)
            push("TopKeys=" .. table.concat(keys, ", "))
            for key, child in pairs(value) do
                if type(child) == "function" then
                    push("FUNCTION " .. tostring(key))
                    if debug and type(debug.getupvalues) == "function" then
                        local upOK, upvalues = pcall(debug.getupvalues, child)
                        if upOK and type(upvalues) == "table" then
                            for upKey, upValue in pairs(upvalues) do
                                if type(upValue) == "table" or isRelevant(upKey) or isRelevant(upValue) then
                                    push(("  UPVALUE %s=%s"):format(tostring(upKey), compact(upValue)))
                                end
                            end
                        end
                    end
                    if debug and type(debug.getconstants) == "function" then
                        local constantsOK, constants = pcall(debug.getconstants, child)
                        if constantsOK and type(constants) == "table" then
                            local selected = {}
                            for _, constant in pairs(constants) do
                                local text = lower(constant)
                                if type(constant) == "string" and (isRelevant(constant)
                                    or text:find("level", 1, true) or text:find("exp", 1, true)
                                    or text:find("season", 1, true)) then
                                    selected[#selected + 1] = constant
                                end
                            end
                            if #selected > 0 then push("  CONSTANTS=" .. table.concat(selected, " | ")) end
                        end
                    end
                end
            end
        end
    else
        push("require=ERROR " .. tostring(value))
    end
else
    push("BattlepassInfo ModuleScript NOT FOUND")
end

push("\n===== [3] LIKELY CLIENT-DATA MODULE NAMES =====")
local candidateCount = 0
local candidateWords = { "data", "profile", "replica", "store", "cache", "state", "player", "save" }
for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do
    if instance:IsA("ModuleScript") then
        local name, path = lower(instance.Name), lower(fullName(instance))
        local matched = false
        for _, word in ipairs(candidateWords) do
            if name == word or name:find(word, 1, true) or path:find("." .. word, 1, true) then
                matched = true break
            end
        end
        if matched then
            candidateCount += 1
            if candidateCount <= 160 then push("CANDIDATE " .. fullName(instance)) end
        end
    end
end
push("CandidateModuleCount=" .. tostring(candidateCount))

push("\n===== [4] LIVE TABLE SEARCH =====")
local seen = {}
local found, visited = 0, 0
local function scanTable(label, value, depth)
    if type(value) ~= "table" or seen[value] or depth > 6 or visited > 180000 then return end
    seen[value] = true
    for key, child in pairs(value) do
        visited += 1
        if visited > 180000 or #lines >= MAX_LINES then break end
        if isRelevant(key) or (type(child) == "string" and isRelevant(child)) then
            found += 1
            push(("LIVE [%s] %s=%s"):format(label, tostring(key), compact(child)))
        end
        if type(child) == "table" then scanTable(label .. "." .. tostring(key), child, depth + 1) end
    end
end

local roots = { _G = _G, shared = shared }
if type(getgenv) == "function" then local ok, value = pcall(getgenv); if ok then roots.genv = value end end
if type(getreg) == "function" then
    local ok, value = pcall(getreg); if ok then roots.getreg = value end
elseif debug and type(debug.getregistry) == "function" then
    local ok, value = pcall(debug.getregistry); if ok then roots.registry = value end
end
for label, root in pairs(roots) do scanTable(label, root, 0) end

if type(getgc) == "function" then
    local ok, objects = pcall(getgc, true)
    local objectCount = 0
    if ok and type(objects) == "table" then
        for _, object in pairs(objects) do
            objectCount += 1
            if type(object) == "table" then scanTable("getgc#" .. tostring(objectCount), object, 0) end
            if #lines >= MAX_LINES or visited > 180000 then break end
        end
        push("getgc objects=" .. tostring(objectCount))
    else
        push("getgc unavailable/error=" .. tostring(objects))
    end
end
push(("LiveMatches=%d | VisitedNodes=%d"):format(found, visited))

push("\n===== [5] LOADED MODULES WITH EXACT NAME =====")
local loadedCount = 0
if type(getloadedmodules) == "function" then
    local ok, modules = pcall(getloadedmodules)
    if ok and type(modules) == "table" then
        for _, module in pairs(modules) do
            if typeof(module) == "Instance" and (isRelevant(module.Name) or isRelevant(fullName(module))) then
                loadedCount += 1
                push("LOADED " .. fullName(module))
            end
        end
    else
        push("getloadedmodules error=" .. tostring(modules))
    end
else
    push("executor ไม่มี getloadedmodules")
end
push("LoadedExactCount=" .. tostring(loadedCount))

push("\n===== VERDICT INPUT =====")
push("BattlepassInfoFound=" .. tostring(battlepassModule ~= nil))
push("BattlepassInfoRequired=" .. tostring(battlepassInfo ~= nil))
push("LiveBattlepassMatches=" .. tostring(found))
push("ส่งผลชุดนี้กลับมา โดยเฉพาะ [2], [3], [4], VERDICT INPUT")

return finish()
