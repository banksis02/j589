-- All GGx startup hopping disabled; retain existing farm loader.
-- Return a starter so the controller can also be tested with fake services.
return function(context)
    local ctx = context or {}
    local host = ctx.game or game
    if host.PlaceId ~= 107778070777162 then return end
    local env = ctx.env or (getgenv and getgenv() or _G)
    local previous = env.SAE_AUTO_HOP
    -- Once farming was admitted, later joins or loader revisions must not restart hopping.
    if env.SAE_FARM_READY_JOB == host.JobId or env.SAE_VENDOR_JOB == host.JobId or env.SAE_SENA_JOB == host.JobId then
        if previous and previous.stop then previous.stop() end
        env.SAE_FARM_READY_JOB = host.JobId
        return previous
    end
    if previous and previous.jobId == host.JobId and previous.version == 12 then return previous end
    if previous and previous.stop then previous.stop() end
    local players = host:GetService("Players")


    local scheduler = ctx.task or task
    local log = ctx.log or warn
    local state = {jobId = host.JobId, version = 12, active = true, tried = {}, pending = nil}
    env.SAE_AUTO_HOP = state
    local connection
    function state.stop()
        state.active = false
        if connection then connection:Disconnect(); connection = nil end
    end
    local function alive() return state.active and env.SAE_AUTO_HOP == state and env.SAE_FARM_READY_JOB ~= host.JobId and env.SAE_VENDOR_JOB ~= host.JobId end
    local function populationReady()
        if not alive() or state.pending then return end
        env.SAE_FARM_READY_JOB = host.JobId
        state.stop() -- stop BEFORE vendor code can yield or start farming
        log("[SAE HOP] all startup hopping disabled")
        scheduler.spawn(function()
            local ok, err = pcall(function()
                local src = host:HttpGet("https://raw.githubusercontent.com/banksis02/j589/main/steal_an_egg_performance.lua?v=1")
                local chunk, compileError = loadstring(src)
                assert(chunk, compileError)
                chunk()()
            end)
            if not ok then log("[SAE PERFORMANCE] load failed: " .. tostring(err)) end
        end)
        if env.SAE_VENDOR_JOB == host.JobId then return end
        -- Latch before invoking vendor code: a partial run must not start twice.
        env.SAE_VENDOR_JOB = host.JobId
        log("[SAE HOP] population ready; loading Luarmor loader")
        local ok, err = pcall(function()
            local source = host:HttpGet("https://api.luarmor.net/files/v4/loaders/36107afd3107e8d841f9d1a69e2465d4.lua")
            local chunk, compileError = loadstring(source)
            assert(chunk, compileError)
            chunk()
        end)
        if not ok then log("[SAE VENDOR] load failed: " .. tostring(err)) end
    end
        populationReady()
    return state
end
