-- GGX SAE standalone experiment v0.3.0 -- NOT the main GGX loader.
-- Collector derived from ojiasa/Steal-an-egg @ 0cb06f0c2453e519129fece24d3c988cbb6f8984.
-- Catalog rarity approach reviewed from ugphone33241-prog/Steal-an-egg (Oxide)
-- @ 86372cb86a014ab93fea5dadd2c7da7ed6dd6db4. Original collector comments retained.
-- Run alone in a fresh test session. No network loaders, server hop, pet cull or selling.
local env = getgenv and getgenv() or _G
local previous = env.GGX_SAE_TEST
if previous and previous.show then
    local ok, visible = pcall(previous.show)
    if ok and visible then return end
    if previous.destroy then pcall(previous.destroy) end
    env.GGX_SAE_TEST = nil
end
local player = game:GetService("Players").LocalPlayer
if not player then warn("GGX SAE: LocalPlayer not ready; run again after joining"); return end
local parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
assert(parent, "GGX SAE: PlayerGui not ready")
local oldBoot = parent:FindFirstChild("GGX_SAE_Loading")
if oldBoot then oldBoot:Destroy() end
local boot = Instance.new("ScreenGui")
boot.Name = "GGX_SAE_Loading"
boot.ResetOnSpawn = false
boot.DisplayOrder = 10000
boot.Parent = parent
local message = Instance.new("TextLabel")
message.Size = UDim2.new(0.8,0,0,150)
message.Position = UDim2.new(0.1,0,0.15,0)
message.BackgroundColor3 = Color3.fromRGB(14,20,30)
message.TextColor3 = Color3.new(1,1,1)
message.TextSize = 16
message.TextWrapped = true
message.Text = "GGX SAE 0.3.0: Loading collector..."
message.Parent = boot
if game.PlaceId ~= 107778070777162 then
    message.Text = "GGX SAE: Unsupported PlaceId " .. tostring(game.PlaceId) .. " (expected 107778070777162). Send this message for diagnosis."
    return
end
local bootDone = false
task.delay(15, function()
    if not bootDone and message.Parent then
        message.Text = "GGX SAE: Still loading game modules. If stuck, send this message and console errors."
    end
end)
local bootOK, bootError = xpcall(function()
local Filter = (function()
-- Pure selection policy: direct egg rarity, then asset catalog. Unknown is skipped.
local F = {}
F.rarities = {"Divine", "Eternal", "Secret", "Cosmic", "Mythic", "Legendary", "Epic", "Rare"}
function F.normalize(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end
function F.rarity(record, assets)
    local value = record.Rarity
    if value == nil then
        local directory = assets and (assets.Directory or assets)
        local asset = directory and directory[record.AssetCategory or record.Category or record.Name]
        value = asset and asset.Rarity
    end
    if type(value) == "table" then value = value.DisplayName or value._id or value.Name end
    for _, name in ipairs(F.rarities) do
        if F.normalize(value) == F.normalize(name) then return name end
    end
    return nil
end
function F.allowed(record, assets, areas, rarities, fallbackArea)
    if type(record) ~= "table" then return false end
    local rarity = F.rarity(record, assets)
    local area = record.AreaId or fallbackArea
    return rarity ~= nil and rarities[rarity] == true and areas[F.normalize(area)] == true
end
return F

end)()
local Collector = (function()
-- ═══════════════════════════════════════════════════════════════
-- STEAL MODULE v9.3-FIXED
-- Base: v9.2 + Fix boss Forest tele/replace + Fix drop egg về home
-- ═══════════════════════════════════════════════════════════════

local P                  = game:GetService("Players").LocalPlayer
local RS                 = game:GetService("ReplicatedStorage")
local W                  = workspace
local ProximityPromptSvc = game:GetService("ProximityPromptService")

local M = {}

local ALL_MAPS = {
    { name = "Forest",         pos = Vector3.new( 599.9, 67.6, -363.9) },
    { name = "Lake",           pos = Vector3.new( 722.5, 67.7, -363.9) },
    { name = "Desert",         pos = Vector3.new( 930.8, 67.5, -320.6) },
    { name = "Jungle",         pos = Vector3.new(1124.7, 67.5, -363.9) },
    { name = "Snow",           pos = Vector3.new(1405.1, 68.0, -363.8) },
    { name = "Volcano",        pos = Vector3.new(1863.1, 68.0, -399.5) },
    { name = "Abyss Ocean",    pos = Vector3.new(2166.1, 67.6, -363.9) },
    { name = "Prehistoric",    pos = Vector3.new(2634.4, 67.6, -363.9) },
    { name = "Cosmic",         pos = Vector3.new(3376.8, 68.4, -322.7) },
    { name = "Cherry Blossom", pos = Vector3.new(3928.0, 67.6, -363.8) },
    { name = "Titan Temple",   pos = Vector3.new(4698.0, 67.6, -363.8) },
    { name = "Light Dark",     pos = Vector3.new(5563.0, 67.6, -363.8) },
}

local config = {
    HOME_POS       = Vector3.new(465.2, 67.1, -364.1),
    FOREST_POS     = Vector3.new(599.9, 67.6, -363.9),
    TARGETS        = { { name = "Snow", pos = Vector3.new(1405.1, 68.0, -363.8) } },
    PREFER_FAR     = true,

    PRIORITY_INCOME    = false,
    PRIORITY_THRESHOLD = 1000000,

    BIG_EGG_MODE       = false,

    HOME_FLY_ABSOLUTE_Y = 100,
    FLY_HOME_SPEED      = 500,
    DROP_SPEED          = 250,
    RECOVERY_RADIUS     = 500,
    MAX_RECOVERY        = 3,
    RECOVERY_WAIT       = 0.3,

    FOREST_RADIUS       = 300,

    SPEED          = 1500,
    SPEED_CAP      = 500,
    MAP_RADIUS     = 800,
    ARRIVE_DIST    = 10,
    BAIT_TIMEOUT   = 15,
    KB_HEALTH_DROP = 0.1,      -- ⭐ v9.3: hạ từ 0.5 → 0.1
    MAX_FIRES      = 8,
    MAX_RETRY      = 3,
    STEAL_VERIFY_WAIT = 0.35,
    CHAT_WAIT      = 2.0,
    HOME_TIMEOUT   = 60,       -- ⭐ v9.3: tổng timeout về home
}

local isRunning = false
local filterAreas, filterRarities = {}, {}
local forestPreparation = false
local pendingFilters
local auditCallbacks = {}
local function audit(text) for _, cb in ipairs(auditCallbacks) do pcall(cb, text) end end
function M.onAudit(cb) table.insert(auditCallbacks, cb) end
local ownedConnections, ownedTasks = {}, setmetatable({}, {__mode = "k"})
local nativeTask = task
local task = setmetatable({}, {__index = nativeTask})
function task.spawn(fn, ...)
    local thread = nativeTask.spawn(fn, ...)
    ownedTasks[thread] = true
    return thread
end
local promptSet = {}
for _, obj in ipairs(W:GetDescendants()) do
    if obj:IsA("ProximityPrompt") then promptSet[obj] = true end
end
table.insert(ownedConnections, W.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then promptSet[obj] = true end
end))
table.insert(ownedConnections, W.DescendantRemoving:Connect(function(obj) promptSet[obj] = nil end))
local function promptList()
    local result = {}
    for prompt in pairs(promptSet) do
        if prompt.Parent then table.insert(result, prompt) end
    end
    return result
end
local stolenPrompts  = {}
local deliveryFailed = false
local logCallbacks   = {}
local lastEggCount   = -1
local lastTargetPos  = nil
local lastTargetMap  = nil

local function log(s)
    for _, cb in ipairs(logCallbacks) do pcall(cb, s) end
    print("[Steal] " .. tostring(s))
end

function M.onLog(cb) if type(cb) == "function" then table.insert(logCallbacks, cb) end end

-- ══════════ HELPERS ══════════
local function getHRP() local c = P.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = P.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local function dist(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function keepHealth()
    local h = getHum()
    if h then pcall(function()
        h.MaxHealth = 99999
        if h.Health < 50000 then h.Health = 99999 end
        h:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
    end) end
end

-- ⭐ v9.3: Force humanoid về Running nếu state xấu
local function forceRunningState()
    local hum = getHum()
    if hum then pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end) end
end

local function forceTeleHome()
    local r = getHRP()
    if r then pcall(function()
        r.CFrame = CFrame.new(config.HOME_POS)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end) end
end

local function getSlotSet()
    local set, count = {}, 0
    local folder = W:FindFirstChild("AreaEggSlotsClient")
    if folder then
        for _, d in ipairs(folder:GetChildren()) do
            set[d.Name] = true; count = count + 1
        end
    end
    return set, count
end

local function hasStolenSlot(beforeSet)
    if not beforeSet then return false, nil end
    local now = getSlotSet()
    for name in pairs(beforeSet) do
        if not now[name] then return true, name end
    end
    return false, nil
end

local function getEggRealMap(eggPos)
    local closestMap, closestDist = nil, 999999
    for _, m in ipairs(ALL_MAPS) do
        local d = dist(eggPos, m.pos)
        if d < closestDist then
            closestMap = m
            closestDist = d
        end
    end
    return closestMap
end

-- ⭐ v9.3: Check đang carry egg không
local AssetEarnings, EggState
local function isCarryingEgg()
    if not EggState then return false end
    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return false
    end
    for _, eggData in pairs(fd.Records) do
        local state = tostring(eggData.State or ""):lower()
        if state == "carried" or state == "carry" or state == "carrying" then
            return true
        end
    end
    return false
end

-- ══════════ INCOME MODULES ══════════
local incomeCache = {}

pcall(function()
    local s = RS:WaitForChild("Shared", 5)
    local u = s and s:FindFirstChild("Util", 5)
    local mod = u and u:FindFirstChild("AssetEarnings", 5)
    if mod then AssetEarnings = require(mod) end
end)

pcall(function()
    local c = RS:WaitForChild("Client", 5)
    if c then
        local mod = c:WaitForChild("EggState", 5)
        if mod then EggState = require(mod) end
    end
end)

local AssetsData
pcall(function() AssetsData = require(RS.Data.Assets) end)
local snapshotAt, records = -math.huge, {}
local function fieldRecords()
    if os.clock() - snapshotAt > 0.2 then
        snapshotAt = os.clock()
        records = {}
        if EggState then
            local ok, result = pcall(EggState.ReadFieldEggs)
            if ok and type(result) == "table" and type(result.Records) == "table" then
                records = result.Records
            end
        end
    end
    return records
end
local function promptPosition(prompt)
    local parent = prompt.Parent
    if parent and parent:IsA("Attachment") then return parent.WorldPosition end
    if parent and parent:IsA("BasePart") then return parent.Position end
    if parent and parent.Parent and parent.Parent:IsA("BasePart") then return parent.Parent.Position end
end
local lastAuditAt = -math.huge
local function checkRecord(record, map, method, force)
    local allowed = Filter.allowed(record, AssetsData, filterAreas, filterRarities, map and map.name)
    local rarity = Filter.rarity(record, AssetsData)
    local area = record.AreaId or (map and map.name) or "?"
    local reason = not rarity and "unknown rarity" or not filterAreas[Filter.normalize(area)] and "area not selected"
        or not filterRarities[rarity] and "rarity not selected" or "matches filters"
    if force or (not allowed and os.clock() - lastAuditAt > 2) then
        lastAuditAt = os.clock()
        local text = string.format("%s | %s | %s | %s | %s [%s]", force and (allowed and "PICK" or "BLOCK") or "SKIP",
            tostring(record.AssetCategory or record.Name or "Egg"), tostring(rarity or "UNKNOWN"), tostring(area), reason, method)
        audit(text)
        print("[GGX FILTER] " .. text)
    end
    return allowed
end
local function allowPrompt(prompt, force)
    local pos = promptPosition(prompt)
    if not pos then return false end
    local map = getEggRealMap(pos)
    -- ojiasa's Forest setup is required even when Forest is not a target area.
    if forestPreparation then
        if force then audit("PREP | Holding Forest egg before target collection (ojiasa)") end
        return map and map.name == "Forest"
    end
    local ids = {}
    local ancestor = prompt.Parent
    while ancestor and ancestor ~= W do
        ids[ancestor.Name] = true
        for _, key in ipairs({"Uid", "UID", "EggUid", "EggUID"}) do
            local id = ancestor:GetAttribute(key)
            if id ~= nil then ids[tostring(id)] = true end
        end
        ancestor = ancestor.Parent
    end
    local nearest, distance, secondDistance = nil, 12, math.huge
    for key, record in pairs(fieldRecords()) do
        if type(record) == "table" and record.BoundsCFrame then
            local id = record.Uid or record.UID or key
            if ids[tostring(id)] then
                return checkRecord(record, map, "UID", force)
            end
            local d = (record.BoundsCFrame.Position - pos).Magnitude
            if d < distance then
                secondDistance = distance
                nearest, distance = record, d
            elseif d < secondDistance then secondDistance = d end
        end
    end
    -- Do not guess between overlapping records, or infer rarity from the area.
    if not nearest or secondDistance - distance < 1 then
        if force or os.clock() - lastAuditAt > 2 then
            lastAuditAt = os.clock()
            audit("SKIP | Cannot match prompt to an egg record reliably")
        end
        return false
    end
    return checkRecord(nearest, map, "position", force)
end

local function getEggInfoAtPos(eggPos, radius)
    radius = radius or 30
    if not AssetEarnings or not EggState then return 0, 0, nil, nil end

    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        return 0, 0, nil, nil
    end

    local best, bestDist = nil, radius
    for uid, eggData in pairs(fd.Records) do
        local cf = eggData.BoundsCFrame
        if cf then
            local d = (cf.Position - eggPos).Magnitude
            if d < bestDist then
                best, bestDist = eggData, d
            end
        end
    end

    if not best then return 0, 0, nil, nil end

    local input = {
        Category = best.AssetCategory,
        Scale = best.AssetScale or 1,
        Mutations = best.Mutations or {},
    }
    local income = 0
    local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
    if ok2 and type(val) == "number" and val > 0 then income = val end
    if income == 0 then
        ok2, val = pcall(AssetEarnings.RatePerSecond, input)
        if ok2 and type(val) == "number" and val > 0 then income = val end
    end

    return income, best.AssetScale or 1, best.BaseMutation, best.Uid or best.UID
end

-- ⭐⭐⭐ Big egg với fallback scan prompt
local function findBiggestEgg()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end

    if not EggState then
        log("❌ EggState nil")
        return nil, nil, nil, nil
    end

    local candidates = {}

    local ok, fd = pcall(EggState.ReadFieldEggs)
    if ok and type(fd) == "table" and type(fd.Records) == "table" then
        for uid, eggData in pairs(fd.Records) do
            local cf = eggData.BoundsCFrame
            if cf then
                local pos = cf.Position
                if dist(pos, config.HOME_POS) > 150 then
                    local bs = eggData.BoundsSize
                    local avgSize = bs and ((bs.X + bs.Y + bs.Z) / 3) or (3.5 * (eggData.AssetScale or 1))
                    local scale = eggData.AssetScale or 1
                    local nearestMap, nearestDist = nil, 99999
                    for _, m in ipairs(ALL_MAPS) do
                        local d = dist(pos, m.pos)
                        if d < nearestDist then
                            nearestMap = m
                            nearestDist = d
                        end
                    end
                    if nearestMap then
                        table.insert(candidates, {
                            uid = uid, pos = pos, scale = scale,
                            avgSize = avgSize,
                            map = nearestMap,
                            category = eggData.AssetCategory,
                            mutation = eggData.BaseMutation,
                        })
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        log("⚠ Records trống → scan prompt workspace")
        for _, v in ipairs(promptList()) do
            if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                local isEgg = v.Name == "CarryAreaEgg"
                    or ((v.ObjectText or "") == "Egg"
                        and (v.ActionText or ""):lower():find("steal", 1, true))
                if isEgg and allowPrompt(v) then
                    local part = v.Parent
                    local ppos
                    if part and part:IsA("BasePart") then ppos = part.Position
                    elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                    elseif part and part.Parent and part.Parent:IsA("BasePart") then
                        ppos = part.Parent.Position end
                    if ppos and dist(ppos, config.HOME_POS) > 150 then
                        local nearestMap, nearestDist = nil, 99999
                        for _, m in ipairs(ALL_MAPS) do
                            local d = dist(ppos, m.pos)
                            if d < nearestDist then
                                nearestMap = m
                                nearestDist = d
                            end
                        end
                        if nearestMap then
                            table.insert(candidates, {
                                prompt = v,
                                pos = ppos,
                                scale = 0,
                                avgSize = 0,
                                map = nearestMap,
                                category = "Egg (dropped)",
                                mutation = nil,
                            })
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            log("⚠ Không có prompt egg nào trong workspace")
            return nil, nil, nil, nil
        end

        local myPos = hrp.Position
        table.sort(candidates, function(a, b)
            return dist(a.pos, myPos) < dist(b.pos, myPos)
        end)

        local best = candidates[1]
        log(string.format("🎯 CHỌN (fallback): prompt @ %s cách %.0f studs",
            best.map.name, dist(best.pos, myPos)))

        return best.prompt, best.pos, best.scale, best.map
    end

    table.sort(candidates, function(a, b)
        if a.avgSize ~= b.avgSize then return a.avgSize > b.avgSize end
        return a.scale > b.scale
    end)

    log("🥚 TOP egg size (bounds):")
    for i = 1, math.min(5, #candidates) do
        local c = candidates[i]
        local mut = c.mutation and (" [" .. c.mutation .. "]") or ""
        log(string.format("  [%d] %s%s @ %s = bounds %.2f (kg %.2f)",
            i, c.category, mut, c.map.name, c.avgSize, c.scale))
    end

    local best = candidates[1]

    local bestPrompt = nil
    local bestPromptDist = 20
    for _, v in ipairs(promptList()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg and allowPrompt(v) then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                if ppos then
                    local d = (ppos - best.pos).Magnitude
                    if d < bestPromptDist then
                        bestPrompt = v
                        bestPromptDist = d
                    end
                end
            end
        end
    end

    if not bestPrompt then
        log(string.format("⚠ Không tìm prompt cho %s → fallback scan", best.category))
        local fallbackPrompt, fallbackPos, fallbackDist = nil, nil, 500
        for _, v in ipairs(promptList()) do
            if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                local isEgg = v.Name == "CarryAreaEgg"
                    or ((v.ObjectText or "") == "Egg"
                        and (v.ActionText or ""):lower():find("steal", 1, true))
                if isEgg and allowPrompt(v) then
                    local part = v.Parent
                    local ppos
                    if part and part:IsA("BasePart") then ppos = part.Position
                    elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                    elseif part and part.Parent and part.Parent:IsA("BasePart") then
                        ppos = part.Parent.Position end
                    if ppos then
                        local d = (ppos - best.pos).Magnitude
                        if d < fallbackDist then
                            fallbackPrompt, fallbackPos, fallbackDist = v, ppos, d
                        end
                    end
                end
            end
        end

        if fallbackPrompt then
            log(string.format("✅ Fallback prompt cách %.0f studs", fallbackDist))
            return fallbackPrompt, fallbackPos, best.scale, best.map
        end

        return nil, nil, nil, nil
    end

    log(string.format("🎯 CHỌN BIG: %s @ %s = bounds %.2f (kg %.2f)",
        best.category, best.map.name, best.avgSize, best.scale))

    return bestPrompt, best.pos, best.scale, best.map
end

local function findHighestIncomeEgg()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end

    if not EggState or not AssetEarnings then
        log("❌ EggState/AssetEarnings nil")
        return nil, nil, nil, nil
    end

    local ok, fd = pcall(EggState.ReadFieldEggs)
    if not ok or type(fd) ~= "table" or type(fd.Records) ~= "table" then
        log("❌ ReadFieldEggs fail")
        return nil, nil, nil, nil
    end

    local candidates = {}
    local threshold = config.PRIORITY_THRESHOLD or 0

    for uid, eggData in pairs(fd.Records) do
        local cf = eggData.BoundsCFrame
        if cf then
            local pos = cf.Position
            if dist(pos, config.HOME_POS) > 150 then
                local input = {
                    Category = eggData.AssetCategory,
                    Scale = eggData.AssetScale or 1,
                    Mutations = eggData.Mutations or {},
                }
                local income = 0
                local ok2, val = pcall(AssetEarnings.LiveRatePerSecond, input)
                if ok2 and type(val) == "number" and val > 0 then income = val end
                if income == 0 then
                    ok2, val = pcall(AssetEarnings.RatePerSecond, input)
                    if ok2 and type(val) == "number" and val > 0 then income = val end
                end

                if income >= threshold then
                    local nearestMap, nearestDist = nil, 99999
                    for _, m in ipairs(ALL_MAPS) do
                        local d = dist(pos, m.pos)
                        if d < nearestDist then
                            nearestMap = m
                            nearestDist = d
                        end
                    end
                    if nearestMap then
                        table.insert(candidates, {
                            uid = uid, pos = pos, income = income,
                            map = nearestMap,
                            category = eggData.AssetCategory,
                            scale = eggData.AssetScale or 1,
                            mutation = eggData.BaseMutation,
                        })
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        log(string.format("⚠ Không có egg >= $%s/s", (threshold / 1e6) .. "M"))
        return nil, nil, nil, nil
    end

    table.sort(candidates, function(a, b)
        if a.income ~= b.income then return a.income > b.income end
        return a.scale > b.scale
    end)

    log("💰 TOP egg income:")
    for i = 1, math.min(5, #candidates) do
        local c = candidates[i]
        local mut = c.mutation and (" [" .. c.mutation .. "]") or ""
        log(string.format("  [%d] %s%s @ %s = $%.2f/s scale=%.2f",
            i, c.category, mut, c.map.name, c.income, c.scale))
    end

    local best = candidates[1]

    local bestPrompt = nil
    local bestPromptDist = 20
    for _, v in ipairs(promptList()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg and allowPrompt(v) then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                if ppos then
                    local d = (ppos - best.pos).Magnitude
                    if d < bestPromptDist then
                        bestPrompt = v
                        bestPromptDist = d
                    end
                end
            end
        end
    end

    if not bestPrompt then
        log(string.format("⚠ Không tìm prompt cho %s", best.category))
        return nil, nil, nil, nil
    end

    log(string.format("🎯 CHỌN: %s @ %s = $%.2f/s scale=%.2f",
        best.category, best.map.name, best.income, best.scale))

    return bestPrompt, best.pos, best.income, best.map
end

local function findForestEggOnly()
    local forestMap = nil
    for _, m in ipairs(ALL_MAPS) do
        if m.name == "Forest" then forestMap = m; break end
    end
    if not forestMap then return nil, nil end

    local best, bestPos, bestDist = nil, nil, config.FOREST_RADIUS

    for _, v in ipairs(promptList()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg and allowPrompt(v) then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                if ppos then
                    local dToForest = dist(ppos, forestMap.pos)
                    if dToForest < config.FOREST_RADIUS then
                        if dToForest < bestDist then
                            best, bestPos, bestDist = v, ppos, dToForest
                        end
                    end
                end
            end
        end
    end
    return best, bestPos
end

local function findEggInTargets()
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end

    local candidates = {}

    for _, v in ipairs(promptList()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg and allowPrompt(v) then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end

                if ppos then
                    local realMap = getEggRealMap(ppos)
                    if realMap then
                        for _, tgt in ipairs(config.TARGETS) do
                            if tgt.name == realMap.name then
                                table.insert(candidates, {
                                    prompt = v, pos = ppos, map = realMap,
                                    dFromPlayer = dist(ppos, hrp.Position),
                                    dFromHome = dist(realMap.pos, config.HOME_POS),
                                })
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then return nil, nil, nil, nil end

    if config.PRIORITY_INCOME or config.BIG_EGG_MODE then
        for _, c in ipairs(candidates) do
            local inc, sc = getEggInfoAtPos(c.pos)
            c.income = inc
            c.scale = sc
        end
        if config.BIG_EGG_MODE then
            table.sort(candidates, function(a, b)
                if a.scale ~= b.scale then return a.scale > b.scale end
                return a.income > b.income
            end)
        else
            table.sort(candidates, function(a, b)
                return a.income > b.income
            end)
        end
    elseif config.PREFER_FAR then
        table.sort(candidates, function(a, b) return a.dFromHome > b.dFromHome end)
    else
        table.sort(candidates, function(a, b) return a.dFromPlayer < b.dFromPlayer end)
    end

    local best = candidates[1]
    return best.prompt, best.pos, best.dFromPlayer, best.map
end

local function findPromptSteal(pos, radius)
    radius = radius or config.MAP_RADIUS
    local best, bestDist = nil, radius
    for _, v in ipairs(promptList()) do
        if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
            local isEgg = v.Name == "CarryAreaEgg"
                or ((v.ObjectText or "") == "Egg"
                    and (v.ActionText or ""):lower():find("steal", 1, true))
            if isEgg and allowPrompt(v) then
                local part = v.Parent
                local ppos
                if part and part:IsA("BasePart") then ppos = part.Position
                elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                elseif part and part.Parent and part.Parent:IsA("BasePart") then
                    ppos = part.Parent.Position end
                if ppos then
                    local d = dist(ppos, pos)
                    if d < bestDist then best, bestDist = v, d end
                end
            end
        end
    end
    return best, bestDist
end

-- ══════════ ANIMATION ══════════
local function restoreAnimations()
    local c = P.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
        local anim = hum:FindFirstChildOfClass("Animator")
        if not anim then anim = Instance.new("Animator"); anim.Parent = hum end
        task.wait(0.1)
        local ids = isR15 and {
            "rbxassetid://507766666","rbxassetid://507766951",
            "rbxassetid://507777826","rbxassetid://507767714",
            "rbxassetid://507765000","rbxassetid://507767968",
            "rbxassetid://507765644","rbxassetid://507784897",
            "rbxassetid://507785072",
        } or {
            "rbxassetid://180435571","rbxassetid://180435792",
            "rbxassetid://180426354","rbxassetid://125750702",
            "rbxassetid://180436148","rbxassetid://180436334",
            "rbxassetid://182393478",
        }
        for _, id in ipairs(ids) do
            pcall(function()
                local a = Instance.new("Animation")
                a.AnimationId = id
                anim:LoadAnimation(a)
            end)
        end
    end)
end

local function resetAnimateScript()
    local c = P.Character
    if not c then return end
    pcall(function()
        local old = c:FindFirstChild("Animate")
        if old then old:Destroy() end
        task.wait(0.1)
        local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
        if starter then
            local tpl = starter:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone()
                new.Parent = c
                new.Disabled = false
                return
            end
        end
        local ps = P:FindFirstChild("PlayerScripts")
        if ps then
            local tpl = ps:FindFirstChild("Animate")
            if tpl then
                local new = tpl:Clone()
                new.Parent = c
                new.Disabled = false
            end
        end
    end)
end

local function replaceHumanoidDirect()
    local c = P.Character
    if not c then return false end
    local old = c:FindFirstChildOfClass("Humanoid")
    if not old then return false end
    local savedHip = old.HipHeight or 2
    local savedJump = old.JumpPower or 50
    local savedMax = old.MaxHealth or 100
    local savedHP = old.Health or 100
    local savedRig = old.RigType or Enum.HumanoidRigType.R15
    local savedSlope = old.MaxSlopeAngle or 89
    pcall(function() old:Destroy() end)
    local new = Instance.new("Humanoid")
    new.Parent = c
    pcall(function()
        new.HipHeight = savedHip
        new.JumpPower = savedJump
        new.MaxHealth = savedMax
        new.Health = savedHP
        new.WalkSpeed = 60
        new.RigType = savedRig
        new.MaxSlopeAngle = savedSlope
        new.AutoRotate = true
        new:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
        new:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        new:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        new:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        new:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        new:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        new:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)
    pcall(function()
        if not c:FindFirstChildOfClass("Animator") then
            local a = Instance.new("Animator")
            a.Parent = new
        end
    end)
    task.spawn(restoreAnimations)
    task.spawn(function()
        task.wait(0.1)
        resetAnimateScript()
        task.wait(0.2)
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
    end)
    return true
end

-- ⭐ v9.3: Luôn replace humanoid (giống v9.2 gốc)
local function teleToMap(targetPos)
    local hrp = getHRP()
    if hrp then pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end) end
    replaceHumanoidDirect()
    for i = 1, 6 do
        local r2 = getHRP()
        if r2 then pcall(function()
            r2.CFrame = CFrame.new(targetPos)
            r2.AssemblyLinearVelocity = Vector3.zero
            r2.AssemblyAngularVelocity = Vector3.zero
        end) end
        task.wait(0.01)
    end
    -- ⭐ v9.3: force running state sau tele
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < 0.6 do
            forceRunningState()
            task.wait(0.03)
        end
    end)
end

local function firePromptOnce(prompt)
    if not isRunning or not prompt or not prompt.Parent or not allowPrompt(prompt, true) then return false end
    forceRunningState()  -- ⭐ v9.3: force trước khi fire
    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 999
        prompt.RequiresLineOfSight = false
    end)
    if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, prompt) end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.02)
        prompt:InputHoldEnd()
    end)
    pcall(function()
        prompt.PromptButtonHoldBegan:Fire()
        task.wait(0.02)
        prompt.PromptButtonHoldEnded:Fire()
        prompt.Triggered:Fire(P)
    end)
    return true
end

-- ══════════ MOVEMENT ══════════
local function velocityMoveTo(targetPos, timeout, manual)
    timeout = timeout or 20
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()
    local function shouldStop()
        if manual then return false end
        return not isRunning
    end
    local t0 = os.clock()
    local lastPos = hrp.Position
    local stuckTime = os.clock()
    while not shouldStop() and os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        forceRunningState()  -- ⭐ v9.3
        local d = dist(hrp.Position, targetPos)
        if d < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end
        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                local nrm = dir.Unit
                hrp.AssemblyLinearVelocity = nrm * math.min(config.SPEED / 2.5, config.SPEED_CAP)
                if d > 50 then
                    local nudge = math.min(d, 100) * 0.05
                    hrp.CFrame = CFrame.new(hrp.Position + nrm * nudge)
                end
            end
        end)
        local moved = dist(hrp.Position, lastPos)
        if moved < 0.3 then
            if os.clock() - stuckTime > 0.5 then
                pcall(function() hum.Jump = true end)
                stuckTime = os.clock()
            end
        else
            lastPos = hrp.Position
            stuckTime = os.clock()
        end
        task.wait(0.01)
    end
    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

local function velocityFlyTo(targetPos, timeout, speed)
    timeout = timeout or 20
    speed = speed or config.FLY_HOME_SPEED or 500
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    keepHealth()

    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        forceRunningState()  -- ⭐ v9.3

        local d = dist(hrp.Position, targetPos)
        if d < config.ARRIVE_DIST then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            return true
        end

        pcall(function()
            local dir = targetPos - hrp.Position
            if dir.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = dir.Unit * speed
            end
        end)
        task.wait(0.01)
    end

    pcall(function() local r = getHRP(); if r then r.AssemblyLinearVelocity = Vector3.zero end end)
    return false
end

-- ⭐⭐⭐ v9.3-FIXED: goHomeWithRecovery — FIX LỤM EGG KHÔNG VỀ HOME
local function goHomeWithRecovery()
    log("🏃 BAY VỀ HOME (Y=" .. (config.HOME_FLY_ABSOLUTE_Y or 100) .. ")")
    local startTime = os.clock()
    local lastHealth = nil
    local recoveryAttempts = 0
    local MAX_RECOVERY = config.MAX_RECOVERY or 3
    local flyY = config.HOME_FLY_ABSOLUTE_Y or 100
    local totalTimeout = config.HOME_TIMEOUT or 60

    while os.clock() - startTime < totalTimeout do
        if not isRunning then return false end

        local hum, r = getHum(), getHRP()
        if not hum or not r then break end
        keepHealth()
        forceRunningState()  -- ⭐ v9.3

        -- ⭐ FIX: Y quá thấp → force tele
        if r.Position.Y < 10 then
            log("🚨 Y < 10 → force tele home")
            forceTeleHome()
            break
        end

        local vel = r.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()
        local hpNow = hum.Health

        -- Detect knockback
        local gotHit = false
        if state == Enum.HumanoidStateType.Physics and speed > 30 then
            gotHit = true
        elseif state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            gotHit = true
        elseif lastHealth and math.abs(hpNow - lastHealth) > 0.3 then
            gotHit = true
        end
        lastHealth = hpNow

        if gotHit and recoveryAttempts < MAX_RECOVERY then
            recoveryAttempts = recoveryAttempts + 1
            log(string.format("💥 KNOCKBACK (attempt %d/%d)",
                recoveryAttempts, MAX_RECOVERY))
            task.wait(config.RECOVERY_WAIT or 0.3)

            local r2 = getHRP()
            if r2 then
                -- Tìm egg rớt gần nhất
                local nearestPrompt, nearestPos, nearestDist = nil, nil, config.RECOVERY_RADIUS or 500
                for _, v in ipairs(promptList()) do
                    if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                        local isEgg = v.Name == "CarryAreaEgg"
                            or ((v.ObjectText or "") == "Egg"
                                and (v.ActionText or ""):lower():find("steal", 1, true))
                        if isEgg and allowPrompt(v) then
                            local part = v.Parent
                            local ppos
                            if part and part:IsA("BasePart") then ppos = part.Position
                            elseif part and part:IsA("Attachment") then ppos = part.WorldPosition
                            elseif part and part.Parent and part.Parent:IsA("BasePart") then
                                ppos = part.Parent.Position end
                            if ppos then
                                local d = dist(ppos, r2.Position)
                                if d < nearestDist then
                                    nearestPrompt, nearestPos, nearestDist = v, ppos, d
                                end
                            end
                        end
                    end
                end

                if nearestPrompt and nearestPos then
                    log(string.format("🎯 Egg rớt cách %.0f studs → CHẠY LẠI", nearestDist))

                    -- Bay tới egg
                    if nearestDist > 200 then
                        velocityFlyTo(nearestPos, 15, config.SPEED_CAP)
                    else
                        velocityMoveTo(nearestPos, 12)
                    end
                    task.wait(0.15)

                    -- ⭐ Lụm egg và VERIFY
                    local slotsBefore = getSlotSet()
                    local pickedUp = false
                    for i = 1, config.MAX_FIRES do
                        if not isRunning then break end
                        forceRunningState()

                        local h3 = getHRP()
                        if h3 then
                            local p3 = findPromptSteal(h3.Position, 150)
                            if p3 then
                                firePromptOnce(p3)
                            end
                        end
                        task.wait(config.STEAL_VERIFY_WAIT)

                        -- Check slot mất
                        local stolen = hasStolenSlot(slotsBefore)
                        if stolen then
                            pickedUp = true
                            break
                        end
                        -- Check carry state
                        if isCarryingEgg() then
                            pickedUp = true
                            break
                        end
                    end

                    if pickedUp then
                        log("✅ Đã lượm lại egg → BAY VỀ HOME NGAY")
                        -- ⭐ FIX: Bay về home luôn, KHÔNG chờ while
                        velocityFlyTo(config.HOME_POS, 10, config.FLY_HOME_SPEED or 500)

                        -- Verify đã về home
                        local r3 = getHRP()
                        if r3 and dist(r3.Position, config.HOME_POS) > 50 then
                            log("⚠ Chưa về home → thử lại lần 2")
                            velocityFlyTo(config.HOME_POS, 8, config.FLY_HOME_SPEED or 500)
                        end

                        log("✅ Đã về home sau khi lụm egg")
                        local rEnd = getHRP()
                        if rEnd then pcall(function()
                            rEnd.AssemblyLinearVelocity = Vector3.zero
                            rEnd.AssemblyAngularVelocity = Vector3.zero
                        end) end
                        forceRunningState()
                        log(string.format("✅ Về home (%.2fs, recovery x%d)",
                            os.clock() - startTime, recoveryAttempts))
                        return true
                    else
                        log("⚠ Lụm không được → tiếp tục về home")
                    end
                else
                    log("⚠ Không tìm thấy egg rớt → tiếp tục về")
                end
            end
            -- ⭐ FIX: Reset lastHealth để không detect lại liên tục
            lastHealth = nil
        end

        -- Bay về home
        local dx = config.HOME_POS.X - r.Position.X
        local dz = config.HOME_POS.Z - r.Position.Z
        local hd = math.sqrt(dx*dx + dz*dz)

        if hd < 30 then
            log("📍 Đến home → rớt xuống")
            break
        end

        pcall(function()
            local targetAir = Vector3.new(config.HOME_POS.X, flyY, config.HOME_POS.Z)
            local dir = targetAir - r.Position
            if dir.Magnitude > 0 then
                r.AssemblyLinearVelocity = dir.Unit * (config.FLY_HOME_SPEED or 500)
            end
        end)
        task.wait(0.01)
    end

    -- Rớt xuống home
    log("⬇ Rớt xuống home")
    velocityFlyTo(config.HOME_POS, 5, config.DROP_SPEED or 250)

    local rEnd = getHRP()
    if rEnd then pcall(function()
        rEnd.AssemblyLinearVelocity = Vector3.zero
        rEnd.AssemblyAngularVelocity = Vector3.zero
    end) end
    forceRunningState()

    log(string.format("✅ Về home (%.2fs, recovery x%d)",
        os.clock() - startTime, recoveryAttempts))
    return true
end

-- ⭐⭐⭐ v9.3-FIXED: baitBoss nhạy hơn
local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss...")
    local t0 = os.clock()
    local hum0, hrp0 = getHum(), getHRP()
    local startHealth = hum0 and hum0.Health or 100
    local startPos = hrp0 and hrp0.Position or Vector3.zero
    local startCFrame = hrp0 and hrp0.CFrame or CFrame.new()

    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        keepHealth()
        local vel = hrp.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local state = hum:GetState()

        -- Physics + speed
        if state == Enum.HumanoidStateType.Physics and speed > 30 then
            log(string.format("💥 PHYSICS speed=%.1f", speed)); return true
        end
        -- Bay lên
        if speed > 60 and vel.Y > 10 then
            log(string.format("💥 VELOCITY speed=%.1f", speed)); return true
        end
        -- ⭐ FIX: state xấu
        if state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            log(string.format("💥 STATE xấu: %s", tostring(state))); return true
        end
        -- ⭐ FIX: Health drop nhạy hơn (0.1)
        if startHealth and hum.Health < startHealth - (config.KB_HEALTH_DROP or 0.1) then
            log(string.format("💥 HEALTH %.1f→%.1f", startHealth, hum.Health)); return true
        end
        -- ⭐ FIX: Dịch chuyển đột ngột
        if startPos then
            local pd = (hrp.Position - startPos).Magnitude
            if pd > 10 then
                log(string.format("💥 SHIFT %.1f", pd)); return true
            end
        end
        -- ⭐ FIX: Rotation
        if startCFrame then
            local dot = math.clamp(startCFrame.LookVector:Dot(hrp.CFrame.LookVector), -1, 1)
            local angleDiff = math.deg(math.acos(dot))
            if angleDiff > 45 then
                log(string.format("💥 ROTATE %.1f°", angleDiff)); return true
            end
        end

        pcall(function() hum:MoveTo(hrp.Position) end)
        task.wait(0.01)
    end
    log("⚠ Hết " .. timeout .. "s — không detect knockback")
    return false
end

local function stealAtPos(targetPos, label, expectedIncome)
    log("═══════")
    log("STEAL TẠI " .. label)
    task.wait(0.05)

    local hrp = getHRP()
    if not hrp then return false end

    local d = dist(hrp.Position, targetPos)
    if d > config.ARRIVE_DIST then
        if d > config.MAP_RADIUS then
            log(string.format("📍 Xa %.0f studs → TELE", d))
            teleToMap(targetPos)
            task.wait(0.1)

            local hrp2 = getHRP()
            if hrp2 then
                local d2 = dist(hrp2.Position, targetPos)
                if d2 > 50 then
                    log(string.format("⚠ Tele xong vẫn xa %.0f → VELOCITY", d2))
                    velocityMoveTo(targetPos, 15)
                else
                    log(string.format("✅ Tele OK (d=%.0f)", d2))
                end
            end
        else
            log(string.format("🏃 Cách %.0f studs → VELOCITY", d))
            velocityMoveTo(targetPos, 25)
        end
    end

    local prompt = findPromptSteal(targetPos, 150)
    if not prompt then log("⚠ Không có prompt"); return false end

    local slotsBefore, countBefore = getSlotSet()
    log("📊 Global slots trước: " .. countBefore)

    for i = 1, config.MAX_FIRES do
        if not isRunning then return false end
        forceRunningState()  -- ⭐ v9.3

        local h2 = getHRP()
        if h2 then
            local p2 = findPromptSteal(h2.Position, 150)
            if p2 then firePromptOnce(p2) end
        end
        task.wait(config.STEAL_VERIFY_WAIT)
        local _, countNow = getSlotSet()
        local stolen, slotName = hasStolenSlot(slotsBefore)
        if stolen then
            log("🎒 SLOT MẤT: " .. slotName)
            log(string.format("📊 Slots: %d → %d", countBefore, countNow))
            log("✅ ĐÃ STEAL")
            return true
        end
        -- ⭐ v9.3: Check carry state
        if isCarryingEgg() then
            log("✅ ĐÃ STEAL (carry check)")
            return true
        end
    end
    log("⚠ Fire " .. config.MAX_FIRES .. " lần không giảm slot")
    return false
end

local function checkEggReset()
    local _, count = getSlotSet()
    if lastEggCount >= 0 and count > lastEggCount + 10 then
        log("🔄 Phát hiện egg reset! Clear stolenPrompts")
        stolenPrompts = {}
        return true
    end
    lastEggCount = count
    return false
end

-- ⭐ v9.3: Watchdog phát hiện state xấu + đứng yên
local function startWatchdog()
    task.spawn(function()
        local lastMoveCheck = os.clock()
        local lastMovePos = nil
        local badStateCount = 0
        local tick = 0
        while isRunning do
            task.wait(0.5)
            if not isRunning then break end
            tick = tick + 1
            forceRunningState()

            -- ⭐ Check state xấu liên tục
            local hum = getHum()
            if hum then
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Physics
                    or st == Enum.HumanoidStateType.PlatformStanding
                    or st == Enum.HumanoidStateType.FallingDown
                    or st == Enum.HumanoidStateType.Ragdoll then
                    badStateCount = badStateCount + 1
                    if badStateCount >= 6 then  -- 3s liên tục
                        log("🚨 State xấu 3s → FORCE REPLACE")
                        replaceHumanoidDirect()
                        badStateCount = 0
                    end
                else
                    badStateCount = 0
                end
            end

            -- Check đứng yên
            if tick % 4 == 0 then
                local hrp = getHRP()
                if hrp then
                    if lastMovePos then
                        if dist(hrp.Position, lastMovePos) < 5 then
                            if os.clock() - lastMoveCheck > 15 then
                                log("🚨 Đứng yên >15s → TELE HOME")
                                forceTeleHome()
                                lastMoveCheck = os.clock()
                                lastMovePos = nil
                            end
                        else
                            lastMovePos = hrp.Position
                            lastMoveCheck = os.clock()
                        end
                    else
                        lastMovePos = hrp.Position
                        lastMoveCheck = os.clock()
                    end
                end
            end
        end
    end)
end

-- ══════════ MAIN LOOP ══════════
local function mainLoop()
    while isRunning do
        if pendingFilters then
            filterAreas, filterRarities = pendingFilters.areas, pendingFilters.rarities
            pendingFilters = nil
            config.TARGETS = {}
            for _, map in ipairs(ALL_MAPS) do
                if filterAreas[Filter.normalize(map.name)] then table.insert(config.TARGETS, map) end
            end
            audit("APPLIED | Updated filters for this cycle")
        end
        if not next(filterAreas) or not next(filterRarities) then
            audit("WAIT | Select at least one Area and Rarity")
            task.wait(0.5)
            continue
        end
        log("═══════════════════════")
        pcall(checkEggReset)

        forestPreparation = true
        log("PHASE 1: Bay tới Forest")

        if not velocityMoveTo(config.FOREST_POS, 30) then
            if not isRunning then break end
            log("❌ Không tới Forest")
            task.wait(0.5)
        else
            log("✅ Tới Forest")

            local prompt, ppos = findForestEggOnly()

            if prompt and ppos then
                log(string.format("🎯 Forest egg @ %.1f,%.1f,%.1f",
                    ppos.X, ppos.Y, ppos.Z))

                local hrp = getHRP()
                if hrp and dist(hrp.Position, ppos) > config.ARRIVE_DIST then
                    velocityMoveTo(ppos, 20)
                end

                local forestBefore, forestCount = getSlotSet()
                log("📊 Forest global slots: " .. forestCount)

                log("⚡ Steal Forest")
                for i = 1, 5 do
                    if not isRunning then break end
                    forceRunningState()
                    local h2 = getHRP()
                    if h2 then
                        local p2 = findPromptSteal(h2.Position, config.FOREST_RADIUS)
                        if p2 then firePromptOnce(p2) end
                    end
                    task.wait(0.3)
                    local stolen, slotName = hasStolenSlot(forestBefore)
                    if stolen then
                        log("🎒 Forest OK: " .. slotName)
                        break
                    end
                    if isCarryingEgg() then
                        log("🎒 Forest OK (carry check)")
                        break
                    end
                end
                stolenPrompts[prompt] = true
                task.wait(0.1)

                log("PHASE 3: Bait boss Forest")
                local gotKnockback = baitBoss(config.BAIT_TIMEOUT)

                -- ⭐ v9.3 FIX: Nếu không detect knockback → force tiếp tục
                if not gotKnockback then
                    log("⚠ Không detect knockback → ÉP TIẾP TỤC (force replace)")
                    replaceHumanoidDirect()
                    gotKnockback = true
                end

                forestPreparation = false
                if gotKnockback then
                    local eggPrompt, eggPos, eggDist, eggMap

                    if config.BIG_EGG_MODE then
                        log("🥚 Mode: BIG EGG")
                        eggPrompt, eggPos, eggDist, eggMap = findBiggestEgg()
                        if not eggPos then
                            log("⚠ Không có big egg → chuyển priority")
                        end
                    end

                    if not eggPos and config.PRIORITY_INCOME then
                        log("💰 Mode: ƯU TIÊN TIỀN CAO")
                        eggPrompt, eggPos, eggDist, eggMap = findHighestIncomeEgg()
                        if not eggPos then
                            log("⚠ Không có egg đạt ngưỡng → DỪNG")
                            isRunning = false
                            break
                        end
                    end

                    if not eggPos then
                        log("PHASE 4: Tìm egg trong " .. #config.TARGETS .. " map")
                        eggPrompt, eggPos, eggDist, eggMap = findEggInTargets()
                    end

                    if not eggPos then
                        log("⚠ Không tìm egg nào → quay lại Forest sau 1s")
                        task.wait(1)
                    else
                        log(string.format("🎯 Map: %s @ %.1f,%.1f,%.1f",
                            eggMap.name, eggPos.X, eggPos.Y, eggPos.Z))

                        lastTargetPos = eggPos
                        lastTargetMap = eggMap

                        local targetPos = eggPos + Vector3.new(0, 3, 0)
                        local success = false
                        for attempt = 1, config.MAX_RETRY do
                            if not isRunning then break end
                            log("═══════════════════════")
                            log(string.format("🔄 ATTEMPT %d/%d", attempt, config.MAX_RETRY))
                            deliveryFailed = false

                            local stealPos = eggPos
                            local stealMap = eggMap
                            local stealTarget = targetPos

                            if attempt > 1 and lastTargetPos then
                                local p, ppos, pd = nil, nil, 500
                                for _, v in ipairs(promptList()) do
                                    if v:IsA("ProximityPrompt") and v.Enabled and not stolenPrompts[v] then
                                        local isEgg = v.Name == "CarryAreaEgg"
                                            or ((v.ObjectText or "") == "Egg"
                                                and (v.ActionText or ""):lower():find("steal", 1, true))
                                        if isEgg and allowPrompt(v) then
                                            local part = v.Parent
                                            local pp
                                            if part and part:IsA("BasePart") then pp = part.Position
                                            elseif part and part:IsA("Attachment") then pp = part.WorldPosition
                                            elseif part and part.Parent and part.Parent:IsA("BasePart") then
                                                pp = part.Parent.Position end
                                            if pp then
                                                local d = (pp - lastTargetPos).Magnitude
                                                if d < pd then
                                                    p, ppos, pd = v, pp, d
                                                end
                                            end
                                        end
                                    end
                                end
                                if p and ppos then
                                    log(string.format("🔄 Retry: egg cũ cách %.0f studs → steal lại", pd))
                                    stealPos = ppos
                                    stealMap = getEggRealMap(ppos) or eggMap
                                    stealTarget = ppos + Vector3.new(0, 3, 0)
                                else
                                    log("⚠ Không tìm thấy egg cũ → steal egg mới")
                                    if config.BIG_EGG_MODE then
                                        local np, npos, nd, nm = findBiggestEgg()
                                        if npos then
                                            stealPos, stealMap = npos, nm
                                            stealTarget = npos + Vector3.new(0, 3, 0)
                                        end
                                    end
                                end
                            end

                            teleToMap(stealTarget)
                            task.wait(0.05)

                            local stolen = stealAtPos(stealPos, stealMap.name)
                            if stolen then
                                goHomeWithRecovery()
                                task.wait(config.CHAT_WAIT)
                                if deliveryFailed then
                                    log("❌ Chat báo fail — RETRY")
                                    task.wait(0.2)
                                else
                                    log("🎉 THÀNH CÔNG")
                                    success = true
                                    lastTargetPos = nil
                                    lastTargetMap = nil
                                    break
                                end
                            else
                                log("⚠ Steal fail — retry")
                                task.wait(0.2)
                            end
                        end

                        if success then
                            deliveryFailed = false
                            log("🎉 HOÀN THÀNH")
                        else
                            log("❌ Hết " .. config.MAX_RETRY .. " lần retry")
                            lastTargetPos = nil
                            lastTargetMap = nil
                        end
                    end
                end
            else
                log("⚠ Không có Forest egg (trong bán kính " .. config.FOREST_RADIUS .. ")")
            end
        end

        if not isRunning then break end
        task.wait(0.5)
    end
end

-- ══════════ BYPASS ══════════
local function installBypass() end

task.spawn(function()
    pcall(function()
        local chatEvents = RS:WaitForChild("DefaultChatSystemChatEvents", 5)
        if not chatEvents then return end
        local onMsg = chatEvents:WaitForChild("OnMessageDoneFiltering", 5)
        if not onMsg then return end
        table.insert(ownedConnections, onMsg.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local msg = string.lower(tostring(data.Message or ""))
            if msg:find("delivery failed", 1, true)
                or msg:find("returned to its nest", 1, true)
                or msg:find("egg was returned", 1, true)
            then
                deliveryFailed = true
                log("❌ Chat: Delivery failed")
            end
        end))
    end)
end)

-- ══════════ API ══════════
function M.start()
    if isRunning then return end
    assert(EggState and type(EggState.ReadFieldEggs) == "function", "EggState not ready; reload the game and test script")
    if not next(filterAreas) or not next(filterRarities) then error("Select Area and Rarity first") end
    config.BIG_EGG_MODE = false
    config.PRIORITY_INCOME = false
    installBypass()
    stolenPrompts = {}
    deliveryFailed = false
    incomeCache = {}
    lastEggCount = -1
    lastTargetPos = nil
    lastTargetMap = nil
    isRunning = true
    log("▶ START v9.3-FIXED — " .. #config.TARGETS .. " map(s)")
    startWatchdog()
    task.spawn(function()
        local ok, err = pcall(mainLoop)
        if not ok then log("Collector error: " .. tostring(err)) end
        M.stop()
    end)
end

function M.stop()
    isRunning = false
    forestPreparation = false
    for thread in pairs(ownedTasks) do
        if thread ~= coroutine.running() then pcall(nativeTask.cancel, thread) end
    end
    table.clear(ownedTasks)
    local hrp = getHRP()
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero end
    log("STOPPED")
end
function M.setFilters(areas, rarities)
    local nextAreas, nextRarities = table.clone(areas), table.clone(rarities)
    if isRunning then
        pendingFilters = {areas = nextAreas, rarities = nextRarities}
        return "pending"
    end
    filterAreas, filterRarities = nextAreas, nextRarities
    pendingFilters = nil
    return "applied"
end
function M.destroy()
    M.stop()
    for _, connection in ipairs(ownedConnections) do connection:Disconnect() end
    table.clear(ownedConnections)
end
function M.isRunning() return isRunning end

function M.setTargets(targetList)
    if type(targetList) ~= "table" then return end
    config.TARGETS = targetList
    local names = {}
    for _, t in ipairs(targetList) do table.insert(names, t.name) end
    log("🎯 Targets: " .. table.concat(names, ", "))
end

function M.setTarget(name, pos)
    config.TARGETS = { { name = name, pos = pos } }
    log("🎯 Target: " .. name)
end

function M.setPriorityIncome(enabled)
    config.PRIORITY_INCOME = enabled and true or false
    log("💰 Ưu tiên tiền cao: " .. (enabled and "BẬT" or "TẮT"))
    return config.PRIORITY_INCOME
end

function M.isPriorityIncome() return config.PRIORITY_INCOME end
function M.togglePriorityIncome() return M.setPriorityIncome(not config.PRIORITY_INCOME) end

function M.setPriorityThreshold(amount)
    config.PRIORITY_THRESHOLD = amount or 1000000
    log("💰 Ngưỡng: $" .. (config.PRIORITY_THRESHOLD / 1e6) .. "M/s")
end

function M.getPriorityThreshold() return config.PRIORITY_THRESHOLD end
function M.clearIncomeCache() incomeCache = {}; log("🔄 Cache cleared") end

function M.setBigEggMode(enabled)
    config.BIG_EGG_MODE = enabled and true or false
    log("🥚 Big egg mode: " .. (enabled and "BẬT" or "TẮT"))
    return config.BIG_EGG_MODE
end

function M.isBigEggMode() return config.BIG_EGG_MODE end
function M.toggleBigEggMode() return M.setBigEggMode(not config.BIG_EGG_MODE) end

function M.setHomeFlyY(n)
    config.HOME_FLY_ABSOLUTE_Y = n or 100
    log("📏 Home fly Y: " .. config.HOME_FLY_ABSOLUTE_Y)
end

function M.setForestRadius(n)
    config.FOREST_RADIUS = n or 300
    log("🌳 Forest radius: " .. config.FOREST_RADIUS)
end

function M.setFlyHomeSpeed(n)
    config.FLY_HOME_SPEED = n or 500
    log("🏃 Fly home speed: " .. config.FLY_HOME_SPEED)
end

function M.setRecoveryRadius(n)
    config.RECOVERY_RADIUS = n or 500
    log("📍 Recovery radius: " .. config.RECOVERY_RADIUS)
end

function M.setMaxRecovery(n)
    config.MAX_RECOVERY = n or 3
    log("📍 Max recovery: " .. config.MAX_RECOVERY)
end

function M.setHomeTimeout(n)
    config.HOME_TIMEOUT = n or 60
    log("⏱ Home timeout: " .. config.HOME_TIMEOUT .. "s")
end

function M.getAllMaps() return ALL_MAPS end
function M.setHome(p) if p then config.HOME_POS = p; log("📍 Home") end end
function M.setForest(p) if p then config.FOREST_POS = p; log("📍 Forest") end end
function M.getConfig() return config end

return M

end)()
local player = game:GetService("Players").LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GGX_SAE_StandaloneTest"
gui.ResetOnSpawn = false
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn); table.insert(connections, c); return c
end
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local bg, tile, accent = Color3.fromRGB(14,20,30), Color3.fromRGB(30,41,57), Color3.fromRGB(18,122,111)
local panel = make("Frame", {Size=UDim2.fromOffset(470,490), Position=UDim2.new(0.5,-235,0.5,-245), BackgroundColor3=bg, BorderSizePixel=0}, gui)
make("UICorner", {CornerRadius=UDim.new(0,12)}, panel)
local scale = make("UIScale", {Scale=1}, panel)
local function fit()
    local camera = workspace.CurrentCamera
    if camera then scale.Scale = math.min(1, (camera.ViewportSize.X-24)/470, (camera.ViewportSize.Y-24)/490) end
end
fit()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit) end
local function label(text, x,y,w,h,size)
    return make("TextLabel", {Text=text, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h), BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(226,236,247), Font=Enum.Font.Gotham, TextSize=size or 13,
        TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left}, panel)
end
local title = label("GGX / EGG COLLECTOR · TEST 0.3.0",16,10,390,28,16)
local function button(text,x,y,w,h,fn)
    local b = make("TextButton", {Text=text, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        BackgroundColor3=tile, TextColor3=Color3.fromRGB(240,246,255), BorderSizePixel=0,
        Font=Enum.Font.Gotham, TextSize=12, AutoButtonColor=true}, panel)
    make("UICorner", {CornerRadius=UDim.new(0,6)}, b)
    connect(b.Activated, fn)
    return b
end
local status = label("ใช้จุดกลับเดิมของ ojiasa • เริ่มอัตโนมัติ",16,43,438,35,13)
local function report(text)
    status.Text = tostring(text)
    print("[GGX SAE TEST] " .. tostring(text))
end
local chosenAreas, chosenRarities = {}, {}
local options = env.GGX_SAE_TEST_CONFIG or {}
for _, map in ipairs(Collector.getAllMaps()) do
    if options.areas == nil or table.find(options.areas, map.name) then
        chosenAreas[Filter.normalize(map.name)] = true
    end
end
for _, rarity in ipairs(Filter.rarities) do
    if options.rarities == nil or table.find(options.rarities, rarity) then chosenRarities[rarity] = true end
end
local function updateFilters()
    local result = Collector.setFilters(chosenAreas, chosenRarities)
    report(result == "pending" and "บันทึกแล้ว • ใช้รอบถัดไป ไข่ที่ถืออยู่ส่งต่อให้จบ" or "อัปเดตตัวกรองแล้ว")
end
local auditView = label("FILTER • รออ่านข้อมูลไข่",16,383,438,44,11)
auditView.TextColor3 = Color3.fromRGB(111,232,195)
Collector.onAudit(function(text) auditView.Text = text end)
local logLines = {}
local logView = label("",16,432,438,43,11)
logView.TextYAlignment = Enum.TextYAlignment.Top
Collector.onLog(function(text)
    if text == "STOPPED" then status.Text = "หยุดแล้ว • ดูผลล่าสุดด้านล่าง" end
    table.insert(logLines, tostring(text))
    while #logLines > 2 do table.remove(logLines,1) end
    logView.Text = table.concat(logLines,"\n")
end)
label("AREA • เลือกได้หลายด่าน",16,82,438,20,12)
for i, map in ipairs(Collector.getAllMaps()) do
    local key = Filter.normalize(map.name)
    local b
    b = button((chosenAreas[key] and "✓ " or "□ ")..map.name,16+((i-1)%3)*148,108+math.floor((i-1)/3)*29,140,25,function()
        chosenAreas[key] = not chosenAreas[key] or nil
        b.Text = (chosenAreas[key] and "✓ " or "□ ")..map.name
        b.BackgroundColor3 = chosenAreas[key] and accent or tile
        updateFilters()
    end)
    b.BackgroundColor3 = chosenAreas[key] and accent or tile
end
label("RARITY • ไม่เลือกระดับ = ไม่เริ่มเก็บ",16,228,438,20,12)
for i, rarity in ipairs(Filter.rarities) do
    local b
    b = button((chosenRarities[rarity] and "✓ " or "□ ")..rarity,16+((i-1)%4)*111,253+math.floor((i-1)/4)*29,103,25,function()
        chosenRarities[rarity] = not chosenRarities[rarity] or nil
        b.Text = (chosenRarities[rarity] and "✓ " or "□ ")..rarity
        b.BackgroundColor3 = chosenRarities[rarity] and accent or tile
        updateFilters()
    end)
    b.BackgroundColor3 = chosenRarities[rarity] and accent or tile
end
label("ถือไข่ Forest เตรียมก่อน → เก็บไข่เป้าหมาย → กลับจุดเดิม",16,314,438,22,11)
local function start()
    if Collector.isRunning() then return end
    if not next(chosenAreas) or not next(chosenRarities) then report("เลือก Area และระดับไข่อย่างน้อยอย่างละ 1"); return end
    local targets = {}
    for _, map in ipairs(Collector.getAllMaps()) do
        if chosenAreas[Filter.normalize(map.name)] then table.insert(targets,map) end
    end
    Collector.setTargets(targets)
    Collector.setFilters(chosenAreas, chosenRarities)
    local ok, err = pcall(Collector.start)
    report(ok and "กำลังทำงาน • ดูขั้นตอนล่าสุดด้านล่าง" or tostring(err))
end
button("START",16,347,214,32,start)
button("STOP",238,347,214,32,function()
    Collector.stop()
    report("หยุดการเก็บและการเคลื่อนที่แล้ว")
end)
-- Minimize keeps STOP reachable via the compact reopen button.
local reopen = make("TextButton", {Text="GGX • เปิดแผง",Size=UDim2.fromOffset(135,32),Position=UDim2.fromOffset(12,80),
    BackgroundColor3=accent,TextColor3=Color3.new(1,1,1),Visible=false,TextSize=13},gui)
button("—",420,10,32,28,function() panel.Visible=false; reopen.Visible=true end)
connect(reopen.Activated,function() panel.Visible=true; reopen.Visible=false end)
env.GGX_SAE_TEST = {
    stop = function() Collector.stop(); report("หยุดแล้ว") end,
    show = function()
        if not gui.Parent then return false end
        gui.Enabled=true; panel.Visible=true; reopen.Visible=false
        return true
    end,
    destroy = function()
        Collector.destroy()
        for _, c in ipairs(connections) do c:Disconnect() end
        gui:Destroy()
        env.GGX_SAE_TEST = nil
    end,
}

if options.autoStart ~= false then start() end

end, function(err) return debug.traceback(tostring(err), 2) end)
bootDone = true
if bootOK then boot:Destroy() else
    message.Text = "GGX SAE 0.3.0 initialization failed:\n" .. tostring(bootError)
    warn(message.Text)
end
