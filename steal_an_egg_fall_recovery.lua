-- Automatic fall recovery is disabled: Tween farming can resemble stuck Freefall.
-- Stop an earlier watcher when this revision is run in an existing session.
if game.PlaceId ~= 107778070777162 then return end
local env = getgenv and getgenv() or _G
if type(env.SAE_FALL_STOP) == "function" then
    local ok, err = pcall(env.SAE_FALL_STOP)
    if not ok then warn("[SAE FALL] stopping previous watcher failed: " .. tostring(err)) end
end
env.SAE_FALL_STOP = nil
print("[SAE FALL] Automatic rejoin disabled; no fall-triggered teleports")
