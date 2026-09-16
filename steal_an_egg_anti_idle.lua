-- Reversible Idled connection suppression; no simulated input.
if game.PlaceId ~= 107778070777162 then return end
local env = getgenv and getgenv() or _G
if env.SAE_IDLE_RESTORE then env.SAE_IDLE_RESTORE() end
if type(getconnections) ~= "function" then
    warn("[SAE IDLE] getconnections unavailable")
    return
end
local player = game:GetService("Players").LocalPlayer
if not player then return end
local ok, connections = pcall(getconnections, player.Idled)
if not ok then warn("[SAE IDLE] cannot read connections"); return end
local disabled = {}
env.SAE_IDLE_RESTORE = function()
    local remaining = {}
    for _, connection in ipairs(disabled) do
        local restored = pcall(function() connection:Enable() end)
        if not restored then table.insert(remaining, connection) end
    end
    disabled = remaining
    print("[SAE IDLE] restore failures:", #disabled)
end
for _, connection in ipairs(connections) do
    pcall(function()
        if connection.Enabled == true
            and type(connection.Disable) == "function"
            and type(connection.Enable) == "function" then
            connection:Disable()
            table.insert(disabled, connection)
        end
    end)
end
print("[SAE IDLE] disabled connections:", #disabled)
