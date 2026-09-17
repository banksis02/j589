-- GGX SAE runtime 1.0: managed job settings, eggs first then Rift. No UI/vendor loader.
if game.PlaceId ~= 107778070777162 then return end
local env = getgenv and getgenv() or _G
if env.GGX_SAE_RUNTIME then return end
local Filter=(function()
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
function F.rank(rarity)
    for index, name in ipairs(F.rarities) do
        if rarity == name then return #F.rarities - index + 1 end
    end
    return 0
end
function F.prefer(a, b)
    local ar, br = F.rank(a.rarity), F.rank(b.rarity)
    if ar ~= br then return ar > br end
    return a.dFromPlayer < b.dFromPlayer
end
return F

end)()
local Collector=(function()
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
    FLY_HOME_SPEED      = 600,
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
local waitingForWork = false
local idleHandler
local beforeEgg
local arenaCheck
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
        if (state == "carried" or state == "carry" or state == "carrying") and tonumber(eggData.CarrierUserId)==game:GetService("Players").LocalPlayer.UserId then
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
local snapshotHealthy = false
local snapshotAt, records = -math.huge, {}
local function fieldRecords()
    if os.clock() - snapshotAt > 0.2 then
        snapshotAt = os.clock()
        records = {}
        snapshotHealthy = false
        if EggState then
            local ok, result = pcall(EggState.ReadFieldEggs)
            if ok and type(result) == "table" and type(result.Records) == "table" then
                records = result.Records
                snapshotHealthy = true
            end
        end
    end
    return records
end
local lastScanLog = -math.huge
local emptySince=nil
local function hasSelectedFieldEgg()
    local total, slotted, matched, unknown = 0, 0, 0, 0
    for _, record in pairs(fieldRecords()) do
        if type(record)=="table" then
            total += 1
            local eggStatus=tostring(record.State or ""):lower()
            if eggStatus=="slot" or eggStatus=="dropped" or eggStatus=="guardcarried" then
                slotted += 1
                local map=record.BoundsCFrame and getEggRealMap(record.BoundsCFrame.Position)
                if not Filter.rarity(record, AssetsData) then unknown += 1 end
                if Filter.allowed(record, AssetsData, filterAreas, filterRarities, map and map.name) then matched += 1 end
            end
        end
    end
    if os.clock()-lastScanLog>=15 then
        lastScanLog=os.clock()
        log(string.format("[SCAN] records=%d slot=%d selected=%d unknownRarity=%d ready=%s",total,slotted,matched,unknown,tostring(snapshotHealthy)))
    end
    return matched>0
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
    return allowed, rarity
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
                                    rarity = select(2, allowPrompt(v)),
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

    table.sort(candidates, Filter.prefer)
    local best = candidates[1]
    audit("TARGET | " .. tostring(best.rarity) .. " | " .. best.map.name .. " | highest selected rarity first")
    return best.prompt, best.pos, best.dFromPlayer, best.map
end

local function findPromptSteal(pos, radius)
    radius = radius or config.MAP_RADIUS
    local best, bestDist, bestRank = nil, radius, -1
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
                    local rank = Filter.rank(select(2, allowPrompt(v)))
                    if d < radius and (rank > bestRank or (rank == bestRank and d < bestDist)) then
                        best, bestDist, bestRank = v, d, rank
                    end
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

local eggFullUntil=0
local fullPauseLogged=false
table.insert(ownedConnections,game:GetService("LogService").MessageOut:Connect(function(message)
    local text=tostring(message):lower()
    if text:find("your egg inventory is full",1,true) or text:find("egg inventory full!",1,true) then
        eggFullUntil=os.clock()+60
    end
end))
local function firePromptOnce(prompt)
    if os.clock()<eggFullUntil then return false end

    if not isRunning or not prompt or not prompt.Parent or not allowPrompt(prompt, true) then return false end
    forceRunningState()  -- ⭐ v9.3: force trước khi fire
    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 999
        prompt.RequiresLineOfSight = false
    end)
    if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, prompt) end
    if isCarryingEgg() then return true end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.02)
        prompt:InputHoldEnd()
    end)
    if isCarryingEgg() then return true end
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
    speed = speed or config.FLY_HOME_SPEED or 600
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
    local start = os.clock()
    local initialRoot = getHRP()
    local initialHum = getHum()
    local function stop(reason, result)
        local r = getHRP()
        if r then
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
        log('[DELIVERY] ' .. reason)
        return result
    end
    if not initialRoot or not initialHum or not isCarryingEgg() then
        return stop('No local egg; retry collection', false)
    end
    local arrived = false
    while isRunning and os.clock()-start < (config.HOME_TIMEOUT or 60) do
        local r, hum = getHRP(), getHum()
        if r ~= initialRoot or hum ~= initialHum or not hum or hum.Health <= 0 then
            return stop('Character changed; retry collection', false)
        end
        if deliveryFailed then return stop('Delivery rejected; retry collection', false) end
        -- Only disappearance inside the delivery zone can count as delivery.
        -- A drop anywhere else cancels movement before another home command.
        local nearHome = dist(r.Position, config.HOME_POS) <= 12
        if not isCarryingEgg() then
            if nearHome and arrived then return stop('Released at home', true) end
            return stop('Egg lost; retry collection', false)
        end
        forceRunningState()
        if nearHome then
            arrived = true
            r.AssemblyLinearVelocity = Vector3.zero
        else
            local delta = config.HOME_POS-r.Position
            local horizontal = Vector3.new(delta.X,0,delta.Z).Magnitude
            local target = horizontal > 25
                and Vector3.new(config.HOME_POS.X,config.HOME_FLY_ABSOLUTE_Y or 100,config.HOME_POS.Z)
                or config.HOME_POS
            local direction = target-r.Position
            local speed = math.min(config.FLY_HOME_SPEED or 600,direction.Magnitude/0.05)
            r.AssemblyLinearVelocity = direction.Magnitude > 0 and direction.Unit*speed or Vector3.zero
        end
        task.wait(0.05)
    end
    return stop('Stopped or timed out; delivery not confirmed', false)
end

local function baitBoss(timeout)
    timeout = timeout or config.BAIT_TIMEOUT
    log("🎯 Bait boss...")
    local carriedAtStart=isCarryingEgg()
    local t0 = os.clock()
    local hum0, hrp0 = getHum(), getHRP()
    local startHealth = hum0 and hum0.Health or 100
    local startPos = hrp0 and hrp0.Position or Vector3.zero
    local startCFrame = hrp0 and hrp0.CFrame or CFrame.new()

    while isRunning and os.clock() - t0 < timeout do
        local hum, hrp = getHum(), getHRP()
        if not hum or not hrp then break end
        if carriedAtStart and os.clock()-t0>0.5 and not isCarryingEgg() then
            log("[PREP] Forest egg released; proceed to selected eggs")
            return true
        end
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

    if isCarryingEgg() then return true end
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
        local verifyUntil=os.clock()+(config.STEAL_VERIFY_WAIT or 0.35)
        repeat
            if not isRunning then return false end
            if isCarryingEgg() then return true end
            task.wait(0.03)
        until os.clock()>=verifyUntil
        local _, countNow = getSlotSet()
        local stolen, slotName = hasStolenSlot(slotsBefore)
        if stolen and isCarryingEgg() then
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
        lastEggCount = count
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
            if waitingForWork then lastMoveCheck=os.clock(); lastMovePos=nil; continue end
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
                                log("[WATCHDOG] Collection stalled; home teleport suppressed")
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
local function approachForest(target,timeout)
    local h,r=getHum(),getHRP()
    if not h or not r or h.Health<=0 then return false end
    local function finish(ok)
        if r.Parent then
            r.AssemblyLinearVelocity=Vector3.zero
            r.AssemblyAngularVelocity=Vector3.zero
        end
        return ok
    end
    -- Use the delivery flight profile for both Forest staging and nest approach.
    local landing=target+Vector3.new(0,3,0)
    local began=os.clock()
    local best=math.huge
    local progress=os.clock()
    log('[FOREST FLIGHT] Approaching at up to '..tostring(config.FLY_HOME_SPEED or 600))
    while isRunning and os.clock()-began<(timeout or 30) do
        if getHRP()~=r or getHum()~=h or h.Health<=0 then return finish(false) end
        local delta=landing-r.Position
        local horizontal=Vector3.new(delta.X,0,delta.Z).Magnitude
        if delta.Magnitude<8 then return finish(true) end
        local waypoint=horizontal>25
            and Vector3.new(landing.X,config.HOME_FLY_ABSOLUTE_Y or 100,landing.Z)
            or landing
        local direction=waypoint-r.Position
        local remaining=delta.Magnitude
        if remaining<best-1 then best=remaining;progress=os.clock() end
        if os.clock()-progress>5 then
            log(string.format('[FOREST FLIGHT] No progress; distance=%.1f',remaining))
            return finish(false)
        end
        forceRunningState()
        local speed=math.min(config.FLY_HOME_SPEED or 600,direction.Magnitude/0.05)
        r.AssemblyLinearVelocity=direction.Magnitude>0 and direction.Unit*speed or Vector3.zero
        task.wait(0.05)
    end
    log('[FOREST FLIGHT] Stopped or timed out')
    return finish(false)
end

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
        if os.clock()<eggFullUntil then
            waitingForWork=true
            if not fullPauseLogged then
                fullPauseLogged=true
                local r=getHRP()
                if r then r.AssemblyLinearVelocity=Vector3.zero end
                log("[BAG BLOCKED] Pickup denied; pause collection for 60s before retry")
            end
            task.wait(0.25)
            continue
        end
        waitingForWork=false
        fullPauseLogged=false
        forestPreparation = false
        pcall(checkEggReset)
        if arenaCheck and arenaCheck() then
            waitingForWork = true
            if idleHandler then idleHandler() end
            task.wait(1)
            waitingForWork = false
            continue
        end
        fieldRecords()
        local candidate = hasSelectedFieldEgg()
        if not candidate and not snapshotHealthy then
            waitingForWork = true
            emptySince=nil
            fieldRecords()
            task.wait(2)
            waitingForWork = false
            continue
        end
        if candidate then emptySince=nil end
        if not candidate then
            waitingForWork = true
            emptySince=emptySince or os.clock()
            if os.clock()-emptySince>=3 and snapshotHealthy and idleHandler then idleHandler() end
            task.wait(0.05)
            waitingForWork = false
            continue
        end
        if beforeEgg then
            waitingForWork=true
            local ready=beforeEgg()
            if not ready then task.wait(2) end
            waitingForWork=false
            if not ready then continue end
        end
        log("═══════════════════════")
        pcall(checkEggReset)

        forestPreparation = true
        log("PHASE 1: Bay tới Forest")

        if not approachForest(config.FOREST_POS, 30) then
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
                    if not approachForest(ppos,20) then forestPreparation=false;continue end
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
                    if stolen and isCarryingEgg() then
                        log("🎒 Forest OK: " .. slotName)
                        break
                    end
                    if isCarryingEgg() then
                        log("🎒 Forest OK (carry check)")
                        break
                    end
                end
                if not isCarryingEgg() then
                    forestPreparation=false
                    log("[PREP] No local egg confirmed; skip guard wait")
                    task.wait(1)
                    continue
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
                        for attempt = 1, 1 do
                            if not isRunning then break end
                            log("═══════════════════════")
                            log(string.format("🔄 ATTEMPT %d/%d", attempt, config.MAX_RETRY))
                            deliveryFailed = false

                            local stealPos = eggPos
                            local stealMap = eggMap
                            local stealTarget = targetPos

                            teleToMap(stealTarget)
                            task.wait(0.05)

                            local stolen = stealAtPos(stealPos, stealMap.name)
                            if stolen then
                                local delivered=goHomeWithRecovery()
                                if not delivered then deliveryFailed=true end
                                if delivered then task.wait(config.CHAT_WAIT) end
                                if deliveryFailed then
                                    lastTargetPos=nil
                                    lastTargetMap=nil
                                    log("[COLLECTION] Delivery lost; rescan current eggs and continue scheduler")
                                    break
                                else
                                    log("🎉 THÀNH CÔNG")
                                    success = true
                                    lastTargetPos = nil
                                    lastTargetMap = nil
                                    break
                                end
                            else
                                log("[COLLECTION] Pickup failed; no immediate retry")
                                task.wait(0.2)
                            end
                        end

                        if success then
                            deliveryFailed = false
                            log("🎉 HOÀN THÀNH")
                        else
                            log("[COLLECTION] Attempt ended")
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
    config.FLY_HOME_SPEED = n or 600
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

function M.setBeforeEgg(fn) beforeEgg=fn end
function M.setIdleHandler(fn, check) idleHandler = fn; arenaCheck=check end
return M

end)()
local Rift=(function()
-- GGX Rift test 0.3. Entry remote retained from the user's steal_an_egg_boss.lua.
-- Separate egg collector. Phase signals derived from three user arena snapshots.
local moveSpeed = 150
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local running, worker, tween, movePart, goal = false, nil, nil, nil, nil
local enteredAt, entryAt, lastSwing, deadBoss = 0, -math.huge, 0, nil
local state, detail = "STOPPED", "กด START เพื่อรอประตู Rift"
local function root() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function humanoid() return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end
local function arena() return workspace:FindFirstChild("BossArena") end
local function boss() local a=arena(); return a and a:FindFirstChild("Boss") end
-- Same location check as the user's working entry script; shown in diagnostics.
local function inside() local r=root(); return r and r.Position.X < -1000 end
local function part(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    return (obj:IsA("Model") and obj.PrimaryPart) or obj:FindFirstChildWhichIsA("BasePart",true)
end
local function hp(obj)
    if not obj then return nil end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local a,b=d.Text:match("([%d,]+)%s*/%s*([%d,]+)")
            if a then return tonumber((a:gsub(",",""))),tonumber((b:gsub(",",""))) end
        end
    end
end
local function bossHealth()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local ui=pg and pg:FindFirstChild("BossFightUI")
    local amount=ui and ui:FindFirstChild("HealthAmount",true)
    if amount and amount:IsA("TextLabel") then
        local a,b=amount.Text:match("([%d,]+)%s*/%s*([%d,]+)")
        if a then return tonumber((a:gsub(",",""))),tonumber((b:gsub(",",""))) end
    end
    return hp(boss())
end
local function show(s,d)
    if state~=s or detail~=d then print("[GGX RIFT] "..s.." | "..d) end
    state,detail=s,d
end
local function cancelMove()
    if tween then tween:Cancel(); tween=nil end
    movePart,goal=nil,nil
end
local function stop()
    running=false
    cancelMove()
    if worker and worker~=coroutine.running() then pcall(task.cancel,worker) end
    worker=nil
    show("STOPPED","หยุดแล้ว")
end
local function isWeapon(tool)
    if not tool:IsA("Tool") or tool:GetAttribute("ItemType")~="Gear" then return false end
    if tool:GetAttribute("IsBat")==true then return true end
    local words={}
    for word in tostring(tool:GetAttribute("GearName") or tool.Name):lower():gmatch("%a+") do words[word]=true end
    if words.trap then return false end
    return words.katana or words.sword or words.blade or words.axe or words.battleaxe or false
end
local function weapon()
    local holders={}
    if player.Character then table.insert(holders,player.Character) end
    local backpack=player:FindFirstChild("Backpack")
    if backpack then table.insert(holders,backpack) end
    for _,holder in ipairs(holders) do
        for _,tool in ipairs(holder:GetChildren()) do
            if isWeapon(tool) then return tool end
        end
    end
end
local function targetPosition(target)
    if target:IsA("Bone") then return target.TransformedWorldCFrame.Position end
    if target:IsA("Attachment") then return target.WorldPosition end
    if target:IsA("BasePart") then return target.Position end
end
local function closestPosition(target, position)
    if not target:IsA("BasePart") then return targetPosition(target) end
    local localPoint=target.CFrame:PointToObjectSpace(position)
    local half=target.Size/2
    return target.CFrame:PointToWorldSpace(Vector3.new(
        math.clamp(localPoint.X,-half.X,half.X),math.clamp(localPoint.Y,-half.Y,half.Y),math.clamp(localPoint.Z,-half.Z,half.Z)))
end
local lastEquip=-math.huge
local trackedTarget,lastTargetHealth,healthAt=nil,nil,0
local swingAttempts=0
local lastCharacter,lastHumanoid,selectedStone=nil,nil,nil
local function resetWeapon(tool,h)
    local ok,err=pcall(function()
        tool:Deactivate()
        h:UnequipTools()
        h:EquipTool(tool)
    end)
    lastEquip=os.clock()
    if not ok then warn("[GGX RIFT] Equip failed: "..tostring(err)) end
end
local function continuousAttack()
    local h=humanoid()
    if not h or h.Health<=0 then return end
    local tool=weapon()
    if not tool then show("NO_WEAPON","รออาวุธ Gear/IsBat โหลด");return end
    if tool.Parent~=player.Character then
        if os.clock()-lastEquip>=1 then resetWeapon(tool,h) end
        return
    end
    if os.clock()-lastEquip<0.3 then return end
    if not tool.Enabled or tool:GetAttribute("CooldownActive")==true then return end
    if os.clock()-lastSwing>=0.35 then
        local ok,err=pcall(function() tool:Deactivate(); tool:Activate() end)
        if ok then swingAttempts+=1 end
        lastSwing=os.clock()
        if not ok then warn("[GGX RIFT] Attack failed: "..tostring(err)) end
    end
end
local function approachAndHit(target)
    local r,h=root(),humanoid()
    if not r or not h or h.Health<=0 or not target.Parent then cancelMove(); return end
    -- Equip while approaching as well as while in attack range.
    local tool=weapon()
    local equipped=tool and tool.Parent==player.Character
    if tool and not equipped and os.clock()-lastEquip>=1 then
        resetWeapon(tool,h)
    elseif not tool then
        show("NO_WEAPON","ไม่พบอาวุธ Gear; รออาวุธโหลด ไม่เลือกสัตว์แทน")
    end
    local center=targetPosition(target)
    if not center then cancelMove(); return end
    local closest=closestPosition(target,r.Position)
    local contactRange=target:IsA("BasePart") and 1 or 3
    if (closest-r.Position).Magnitude>contactRange then
        local away=Vector3.new(r.Position.X-center.X,0,r.Position.Z-center.Z)
        if away.Magnitude<0.1 then away=Vector3.new(1,0,0) end
        local destination=Vector3.new(closest.X,r.Position.Y,closest.Z)+away.Unit*(target:IsA("BasePart") and 0.25 or 1.5)
        if movePart~=target or not goal or (goal-destination).Magnitude>3 or not tween or tween.PlaybackState~=Enum.PlaybackState.Playing then
            cancelMove(); goal=destination; movePart=target
            tween=TweenService:Create(r,TweenInfo.new(math.max(0.1,(destination-r.Position).Magnitude/moveSpeed),Enum.EasingStyle.Linear),{CFrame=CFrame.new(destination)})
            tween:Play()
        end
        return
    end
    cancelMove()
    local flat=Vector3.new(center.X,r.Position.Y,center.Z)
    if (flat-r.Position).Magnitude>0.1 then r.CFrame=CFrame.lookAt(r.Position,flat) end
    if not tool or tool.Parent~=player.Character or not isWeapon(tool) then return end
    if os.clock()-lastEquip<0.3 then return end
    local targetHealth=target:IsA("BasePart") and target:GetAttribute("Health") or bossHealth()
    if trackedTarget~=target or targetHealth~=lastTargetHealth then
        trackedTarget=target;lastTargetHealth=targetHealth;healthAt=os.clock();swingAttempts=0
    elseif type(targetHealth)=="number" and targetHealth>0 and swingAttempts>=6 and os.clock()-healthAt>=4 then
        warn("[GGX RIFT] HP unchanged; re-equip "..tool.Name.." and approach again")
        resetWeapon(tool,h)
        healthAt=os.clock();swingAttempts=0
        local offset=Vector3.new(r.Position.X-center.X,0,r.Position.Z-center.Z)
        if offset.Magnitude>0.1 then
            local destination=Vector3.new(closest.X,r.Position.Y,closest.Z)+offset.Unit*0.5
            cancelMove();goal=destination;movePart=target
            tween=TweenService:Create(r,TweenInfo.new(0.2,Enum.EasingStyle.Linear),{CFrame=CFrame.lookAt(destination,Vector3.new(center.X,destination.Y,center.Z))})
            tween:Play()
        end
        return
    end

end
local function stones()
    local a=arena(); local folder=a and a:FindFirstChild("CrystalTowers")
    local result,unknown={},0
    if folder then for _, obj in ipairs(folder:GetChildren()) do
        local p=obj:FindFirstChild("Hitbox")
        local health=p and p:GetAttribute("Health")
        if type(health)~="number" then health=nil end
        if p then
            if health==nil then unknown+=1 elseif health>0 then table.insert(result,{part=p,health=health}) end
        end
    end end
    local r=root()
    if r then table.sort(result,function(a,b) return (a.part.Position-r.Position).Magnitude<(b.part.Position-r.Position).Magnitude end) end
    return result,unknown
end
local function exposedHand()
    local b=boss()
    if not b or b:GetAttribute("Attacking")~=true then return nil end
    local hand=b:FindFirstChild("UpperHand1.R",true)
    if not hand or not (hand:IsA("Bone") or hand:IsA("Attachment") or hand:IsA("BasePart")) then return nil end
    local health=hand:FindFirstChild("Health")
    if not health or not health:IsA("BillboardGui") or not health.Enabled then return nil end
    local label=health:FindFirstChildWhichIsA("TextLabel",true)
    if not label or not label.Visible then return nil end
    local current=hp(hand)
    if not current or current<=0 then return nil end
    return hand
end
local function tick()
    local char,h=player.Character,humanoid()
    if char~=lastCharacter or h~=lastHumanoid then
        cancelMove()
        lastCharacter,lastHumanoid=char,h
        trackedTarget,lastTargetHealth,selectedStone=nil,nil,nil
        healthAt=os.clock();swingAttempts=0;lastEquip=-math.huge;lastSwing=0
    end
    if not h or h.Health<=0 or not root() then
        cancelMove();selectedStone=nil
        show("WAIT_RESPAWN","รอเกิดใหม่ แล้วตรวจอาวุธอีกครั้ง");return
    end
    if not inside() then
        cancelMove()
        if not workspace:FindFirstChild("BossArenaTeleport") then
            show("WAIT_RIFT","รอประตูเกิดจริง • รอบ :00 / :30"); return
        end
        show("ENTERING","ใช้ AskEnter • รอยืนยันว่าเข้าห้องแล้ว")
        if os.clock()-entryAt<5 then return end
        entryAt=os.clock()
        local packages=RS:FindFirstChild("Packages")
        local net=packages and packages:FindFirstChild("Networking")
        local remote=net and net:FindFirstChild("RF/BossEvent/AskEnter")
        if not remote or not remote:IsA("RemoteFunction") then show("NO_REMOTE","ไม่พบ RF/BossEvent/AskEnter"); return end
        remote:InvokeServer() -- A successful call alone does not mean entry succeeded.
        return
    end
    if enteredAt==0 then enteredAt=os.clock() end
    local b=boss()
    if not b then cancelMove(); show("WAIT_ARENA","รอ BossArena.Boss โหลด • ไม่ถือว่าชนะเพียงเพราะโมเดลหาย"); return end
    local current,maximum=bossHealth()
    if current==0 or deadBoss==b then
        deadBoss=b; cancelMove(); show("COMPLETE","บอส HP 0 • หยุดโจมตี รอออกจากห้อง"); return
    end
    continuousAttack() -- Independent of distance, crystal HP maximum, or hand exposure.
    local targets,unknown=stones()
    if #targets>0 then
        local chosen=targets[1]
        for _,candidate in ipairs(targets) do if candidate.part==selectedStone then chosen=candidate;break end end
        selectedStone=chosen.part
        show("CRYSTALS","หินเหลือ "..#targets.." • เป้า "..chosen.part.Name.." HP "..chosen.health)
        approachAndHit(chosen.part); return
    end
    selectedStone=nil
    if unknown>0 then cancelMove(); show("NEED_DATA","อ่าน HP หินไม่ได้ "..unknown.." ก้อน • กด COPY DATA"); return end
    local hand=exposedHand()
    if hand then
        show("HAND_OPEN",hand.Name.." • HP "..tostring(current).."/"..tostring(maximum).." • Attacking + ป้ายเลือดมือ")
        approachAndHit(hand)
    else cancelMove(); show("WAIT_HAND","รอมือลดลง • ถืออาวุธและตีต่อเนื่อง") end
end
local M = {}
function M.inside() return inside() end
function M.available()
    local currentBoss=boss()
    if deadBoss and currentBoss==deadBoss then
        local health=bossHealth()
        if health and health>0 then deadBoss=nil else return false end
    end
    return workspace:FindFirstChild("BossArenaTeleport") ~= nil
end
function M.run(allowed)
    local sawInside=inside()
    local began=os.clock()
    entryAt=-math.huge
    while allowed() do
        if inside() then sawInside=true end
        if sawInside and not inside() then break end
        if not sawInside and (not M.available() or os.clock()-began>20) then break end
        tick()
        task.wait(0.25)
    end
    cancelMove()
end
function M.stop() cancelMove() end
return M

end)()
local Treadmill=(function()
local M={}
local player=game:GetService('Players').LocalPlayer
local oldSpeed,applied,humanoid
local entered=false
local function character()
 local c=player.Character
 return c and c:FindFirstChildOfClass('Humanoid'),c and c:FindFirstChild('HumanoidRootPart')
end
local function owner(plot)
 local sign=plot:FindFirstChild('PlotSign')
 local gui=sign and sign:FindFirstChild('PlayerPlotSign')
 local frame=gui and gui:FindFirstChild('Frame')
 local icon=frame and frame:FindFirstChild('PlayerIcon')
 return icon and tonumber(icon.Image:match('[?&]id=(%d+)'))
end
local function ownBelt()
 local plots=workspace:FindFirstChild('Plots');local found
 if not plots then return end
 for _,plot in ipairs(plots:GetChildren()) do
  if owner(plot)==player.UserId then
   if found then return end
   found=plot
  end
 end
 local belt=found and found:FindFirstChild('TreadmillBottom')
 if belt and belt:IsA('BasePart') then return belt end
end
function M.stop()
 if humanoid and humanoid.Parent then
  humanoid:Move(Vector3.zero,false)
  local _,r=character();if r then humanoid:MoveTo(r.Position) end
  if applied and humanoid.WalkSpeed==applied then humanoid.WalkSpeed=oldSpeed end
 end
 humanoid=nil;applied=nil;oldSpeed=nil
end
function M.step()
 local h,r=character();local belt=ownBelt()
 if not h or not r or h.Health<=0 or not belt then M.stop();return false end
 if humanoid~=h then M.stop();humanoid=h;oldSpeed=h.WalkSpeed end
 local target=belt.Position+belt.CFrame.UpVector*(belt.Size.Y/2)
 local d=Vector3.new(target.X-r.Position.X,0,target.Z-r.Position.Z).Magnitude
 if d<=1.2 then
  h:Move(Vector3.zero,false);h:MoveTo(r.Position)
  if applied and h.WalkSpeed==applied then h.WalkSpeed=oldSpeed end
  applied=nil;entered=true
 else
  applied=math.min(oldSpeed,math.clamp(d*2,4,32));h.WalkSpeed=applied;h:MoveTo(target)
 end
 return true
end
local function nearBelt(root,belt)
 local point=belt.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=belt.Size.X/2+3
  and math.abs(point.Z)<=belt.Size.Z/2+3 and math.abs(point.Y)<=12
end
function M.leave()
 M.stop()
 local h,r=character()
 if not h or not r or h.Health<=0 then return false end
 local belt=ownBelt()
 -- Already away from the treadmill: no jump confirmation is needed.
 if not belt or not nearBelt(r,belt) then entered=false;return true end
 if not h:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
  warn('[GGX TREADMILL] Jump unavailable; retry later');return false
 end
 h:Move(Vector3.zero,false);h:MoveTo(r.Position);h.Jump=true
 task.wait(0.3)
 if not r.Parent or h.Health<=0 or player.Character~=h.Parent then return false end
 -- The treadmill can release without an observable airborne frame.
 -- Move to the approved safe-zone point, then check that it does not pull us back.
 local destination=Vector3.new(534.4960327148438,69.64423370361328,-367.4530334472656)
 r.CFrame=CFrame.new(destination);r.AssemblyLinearVelocity=Vector3.zero
 local began=os.clock()
 repeat
  task.wait(0.1)
  if not r.Parent or h.Health<=0 or player.Character~=h.Parent then return false end
  if nearBelt(r,belt) or (r.Position-destination).Magnitude>8 then
   warn('[GGX TREADMILL] Returned to belt; travel held');return false
  end
 until os.clock()-began>=1
 entered=false
 print('[GGX TREADMILL] Left belt; safe-zone position confirmed')
 return true
end
return M

end)()

local http=game:GetService("HttpService")
local player=game:GetService("Players").LocalPlayer
local active=true
local job=nil
local lastGood=0
local signature=nil
local recoveryThread=nil
local hopping=false
local function configured()
    return active and not hopping and job and job.status=="active" and os.clock()-lastGood<45
        and (job.mode=="sae_egg" or job.mode=="sae_egg_boss" or job.mode=="sae_bundle" or job.mode=="sae_treadmill")
end
local function bossAllowed() return configured() and (job.mode=="sae_egg_boss" or job.mode=="sae_bundle") end
local function fetchJob()
    local url="https://ggx-automation-backend-production.up.railway.app/api/public/runtime-jobs/"
        ..http:UrlEncode(player.Name).."?game=steal_an_egg"
    local requestFn=env.request or env.http_request or request or http_request or (syn and syn.request)
    if requestFn then
        local response=requestFn({Url=url,Method="GET"})
        assert(response and tonumber(response.StatusCode)==200,"job API unavailable")
        return http:JSONDecode(response.Body)
    end
    return http:JSONDecode(game:HttpGet(url))
end
local function split(value)
    if type(value)=="table" then return value end
    local out={}
    for item in tostring(value or ""):gmatch("[^,]+") do table.insert(out,item:match("^%s*(.-)%s*$")) end
    return out
end
local function settings(j)
    local areas,rarities,targets={},{},{}
    for _,name in ipairs(split(j.eggAreas)) do areas[Filter.normalize(name)]=true end
    for _,name in ipairs(split(j.eggRarity)) do if Filter.rank(name)>0 then rarities[name]=true end end
    for _,map in ipairs(Collector.getAllMaps()) do
        if #split(j.eggAreas)==0 then areas[Filter.normalize(map.name)]=true end
        if areas[Filter.normalize(map.name)] then table.insert(targets,map) end
    end
    return areas,rarities,targets
end
Collector.setIdleHandler(function()
    if bossAllowed() and (Rift.available() or Rift.inside()) then
        if not Rift.inside() and not Treadmill.leave() then return end
        print("[GGX SAE] No selected eggs remain; entering Rift")
        Rift.run(bossAllowed)
        print("[GGX SAE] Rift finished or job stopped; rescan eggs")
    elseif configured() and job.mode=="sae_bundle" then
        local untilAt=os.clock()+1
        repeat Treadmill.step(); task.wait(0.05) until os.clock()>=untilAt or not configured()
    end
end, Rift.inside)
-- SAFE ZONE measured by the user in-game.
local SAFE_ZONE=Vector3.new(534.4960327148438,69.64423370361328,-367.4530334472656)
local initialDeparture=true
Collector.setBeforeEgg(function()
 if not configured() or not SAFE_ZONE then return false end
 if not Treadmill.leave() then return false end
 if not configured() then return false end
 if not initialDeparture then return true end
 local char=player.Character
 local root=char and char:FindFirstChild('HumanoidRootPart')
 if not root then return false end
 root.CFrame=CFrame.new(SAFE_ZONE)
 root.AssemblyLinearVelocity=Vector3.zero
 task.wait(0.3)
 local arrived=configured() and (root.Position-SAFE_ZONE).Magnitude<6
 if arrived then initialDeparture=false end
 return arrived
end)

env.GGX_SAE_RUNTIME={manualHopVersion=1,stop=function()
    active=false; Treadmill.stop(); Rift.stop(); Collector.destroy(); env.GGX_SAE_RUNTIME=nil
end}
-- Manual customer command, scoped to the original server; never repeats after teleport.
env.GGX_SAE_HOP_SEEN=env.GGX_SAE_HOP_SEEN or {}
local seenCommands=env.GGX_SAE_HOP_SEEN
local function manualHop(command)
    if type(command)~="table" or type(command.requestId)~="string" or command.sourceServerId~=game.JobId
        or seenCommands[command.requestId] then return end
    local valid,expires=pcall(function() return DateTime.fromIsoDate(command.expiresAt).UnixTimestamp end)
    if not valid or expires<os.time() then return end
    seenCommands[command.requestId]=true
    hopping=true
    Treadmill.stop(); Collector.stop(); Rift.stop(); signature=nil
    local service=game:GetService("TeleportService")
    local failure=nil
    local connection=service.TeleportInitFailed:Connect(function(who,_,message)
        if who==player then failure=tostring(message) end
    end)
    local ok,err=pcall(function()
        local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100"
        local rooms=http:JSONDecode(game:HttpGet(url)).data
        assert(type(rooms)=="table","server list unavailable")
        local attempts=0
        for _,room in ipairs(rooms) do
            if not active then return end
            if type(room.id)=="string" and room.id~=game.JobId and tonumber(room.playing) and tonumber(room.maxPlayers)
                and room.playing<room.maxPlayers then
                attempts+=1; failure=nil
                print("[GGX MANUAL HOP] customer requested new server: "..room.id)
                local sent,message=pcall(function() service:TeleportToPlaceInstance(game.PlaceId,room.id,player) end)
                if not sent then failure=tostring(message) end
                local began=os.clock()
                while active and not failure and os.clock()-began<30 do task.wait(0.5) end
                if not failure then return end -- Unknown outcome: do not send competing teleports.
                if attempts>=3 then error(failure) end
                task.wait(2)
            end
        end
        error("no available server")
    end)
    connection:Disconnect()
    hopping=false
    if not ok then warn("[GGX MANUAL HOP] failed: "..tostring(err)) end
end

-- Network polling cannot delay treadmill braking near the destination.
task.spawn(function()
    while active do
        local ok,result=pcall(fetchJob)
        if ok and type(result)=="table" then job=result; lastGood=os.clock() end
        task.wait(10)
    end
end)
task.spawn(function()
    while active do
        if env.GGX_SAE_MANUAL_HOP then manualHop(env.GGX_SAE_MANUAL_HOP) end
        if not configured() then
            if Collector.isRunning() then Collector.stop(); Rift.stop() end
            Treadmill.stop()
            signature=nil
        elseif job.mode=="sae_treadmill" then
            if Collector.isRunning() then Collector.stop(); Rift.stop() end
            signature=nil
            if not Rift.inside() then Treadmill.step() end
        else
            local areas,rarities,targets=settings(job)
            local key=tostring(job.id).."|"..tostring(job.mode).."|"..table.concat(split(job.eggAreas),",").."|"..table.concat(split(job.eggRarity),",")
            if #targets==0 or not next(rarities) then
                Collector.stop(); Rift.stop(); Treadmill.stop()
                task.wait(2)
                warn("[GGX SAE] Waiting for valid Area and Rarity settings from CONTROL/Discord")
            elseif key~=signature then
                Collector.setFilters(areas,rarities)
                if not Collector.isRunning() then Collector.setTargets(targets) end
                signature=key
                print("[GGX SAE CONFIG] "..key)
            end
            if #targets>0 and next(rarities) and not Collector.isRunning() then
                if Rift.inside() then
                    -- Never start the Forest sequence while still in the arena.
                    if bossAllowed() and not recoveryThread then
                        recoveryThread=task.spawn(function()
                            local okRift,err=pcall(Rift.run,bossAllowed)
                            if not okRift then warn(err); Rift.stop() end
                            recoveryThread=nil
                        end)
                    end
                elseif not recoveryThread then Collector.start() end
            end
        end
        task.wait(0.1)
    end
end)
