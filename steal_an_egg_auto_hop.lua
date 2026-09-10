-- Automatic, once-per-server population check. No UI and no farming hooks.
-- Return a starter so the controller can also be tested with fake services.
return function(context)
    local ctx = context or {}
    local host = ctx.game or game
    if host.PlaceId ~= 107778070777162 then return end
    local env = ctx.env or (getgenv and getgenv() or _G)
    local previous = env.SAE_AUTO_HOP
    if previous and previous.jobId == host.JobId and previous.version == 2 then return previous end
    if previous and previous.stop then previous.stop() end
    local players = host:GetService("Players")
    local teleport = host:GetService("TeleportService")
    local http = host:GetService("HttpService")
    local scheduler = ctx.task or task
    local log = ctx.log or warn
    local state = {jobId = host.JobId, version = 2, active = true, tried = {}, pending = nil}
    env.SAE_AUTO_HOP = state
    local connection
    function state.stop()
        state.active = false
        if connection then connection:Disconnect(); connection = nil end
    end
    local function alive() return state.active and env.SAE_AUTO_HOP == state end
    local function startVendor()
        if not alive() or state.pending or #players:GetPlayers() > 3 then return end
        if ctx.startVendor then ctx.startVendor(); return end
        if env.SAE_ZEROIN_JOB == host.JobId then return end
        env.SAE_ZEROIN_JOB = host.JobId
        log("[SAE HOP] population <=3; loading Zeroin")
        -- Independently watch for the gate: third-party chunks may not return.
        scheduler.spawn(function()
            local core = host:GetService("CoreGui")
            local input = host:GetService("VirtualInputManager")
            local function visible(button)
                local node = button
                while node and node ~= host do
                    if node:IsA("GuiObject") and not node.Visible then return false end
                    if node:IsA("ScreenGui") and not node.Enabled then return false end
                    node = node.Parent
                end
                return button.AbsoluteSize.X > 0 and button.AbsoluteSize.Y > 0
            end
            for _ = 1, 90 do
                if env.SAE_AUTO_HOP ~= state then return end
                for _, root in ipairs({core, players.LocalPlayer:FindFirstChildOfClass("PlayerGui")}) do
                    for _, object in ipairs(root:GetDescendants()) do
                        if object:IsA("TextButton") and object.Text == "Join Discord & Open UI" and visible(object) then
                            local point = object.AbsolutePosition + object.AbsoluteSize / 2
                            input:SendMouseButtonEvent(point.X, point.Y, 0, true, host, 0)
                            input:SendMouseButtonEvent(point.X, point.Y, 0, false, host, 0)
                            log("[SAE HOP] clicked Join Discord & Open UI; verify Zeroin UI")
                            return
                        end
                    end
                end
                scheduler.wait(1)
            end
            log("[SAE HOP] Zeroin gate not found within 90s; send UI screenshot/log")
        end)
        local ok, err = pcall(function()
            local chunk, compileError = loadstring(host:HttpGet("https://zeroinhub.com/api/script"))
            assert(chunk, compileError)
            chunk()
        end)
        if not ok then
            env.SAE_ZEROIN_JOB = nil
            log("[SAE HOP] Zeroin load failed: " .. tostring(err))
        end
    end
    local function fetch(url)
        if ctx.fetch then return ctx.fetch(url) end
        local send = env.request or env.http_request or request or http_request
            or (syn and syn.request)
        if send then
            local response = send({Url = url, Method = "GET"})
            assert(response and tonumber(response.StatusCode) == 200, "server list HTTP failed")
            return http:JSONDecode(response.Body)
        end
        return http:JSONDecode(host:HttpGet(url))
    end
    scheduler.spawn(function()
        local ok, err = pcall(function()
            while alive() and (not host:IsLoaded() or not players.LocalPlayer) do scheduler.wait(1) end
            if not alive() then return end
            scheduler.wait(5)
            if not alive() then return end
            -- Only check on load, not every time someone joins later.
            log("[SAE HOP] players=" .. #players:GetPlayers() .. "; hop when >3")
            if #players:GetPlayers() <= 3 then startVendor(); state.stop(); return end
            local player = players.LocalPlayer
            connection = teleport.TeleportInitFailed:Connect(function(who, result, message, place, options)
                local pending = state.pending
                if not alive() or not pending or who ~= player or place ~= host.PlaceId then return end
                local serverId
                if options then pcall(function() serverId = options.ServerInstanceId end) end
                if serverId and serverId ~= "" and serverId ~= pending.id then return end
                pending.failure = tostring(result) .. ": " .. tostring(message)
            end)
            while alive() do
                if #players:GetPlayers() <= 3 then startVendor(); break end
                local candidates, seen, cursors = {}, {}, {}
                local success, listError = pcall(function()
                    local cursor
                    for _ = 1, 3 do
                        local url = "https://games.roblox.com/v1/games/" .. host.PlaceId
                            .. "/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100"
                        if cursor then url = url .. "&cursor=" .. http:UrlEncode(cursor) end
                        local page = fetch(url)
                        assert(type(page) == "table" and type(page.data) == "table", "invalid server list")
                        for _, room in ipairs(page.data) do
                            local count, maximum = tonumber(room.playing), tonumber(room.maxPlayers)
                            if type(room.id) == "string" and room.id ~= "" and room.id ~= host.JobId
                                and count and count >= 0 and count <= 2 and maximum and count < maximum
                                and not seen[room.id] and not state.tried[room.id] then
                                seen[room.id] = true
                                table.insert(candidates, {id = room.id, playing = count})
                            end
                        end
                        cursor = page.nextPageCursor
                        if type(cursor) ~= "string" or cursor == "" or cursors[cursor] then break end
                        cursors[cursor] = true
                    end
                end)
                if not success then log("[SAE HOP] list failed: " .. tostring(listError)) end
                table.sort(candidates, function(a, b)
                    if a.playing == b.playing then return a.id < b.id end
                    return a.playing < b.playing
                end)
                for _, room in ipairs(candidates) do
                    if not alive() or #players:GetPlayers() <= 3 then break end
                    state.tried[room.id] = true
                    local pending = {id = room.id}
                    state.pending = pending
                    log("[SAE HOP] joining " .. room.id .. " players=" .. room.playing)
                    local sent, sendError = pcall(function()
                        teleport:TeleportToPlaceInstance(host.PlaceId, room.id, player)
                    end)
                    if not sent then pending.failure = tostring(sendError) end
                    -- Do not issue a competing teleport while the outcome is unknown.
                    -- GameFull/772 raises TeleportInitFailed: advance to a DIFFERENT room.
                    while alive() and not pending.failure do scheduler.wait(1) end
                    if not alive() then break end
                    log("[SAE HOP] failed; trying another server: " .. pending.failure)
                    state.pending = nil
                    scheduler.wait(3)
                end
                if alive() then scheduler.wait(30) end
            end
        end)
        state.stop()
        if not ok then log("[SAE HOP] stopped: " .. tostring(err)) end
    end)
    return state
end
