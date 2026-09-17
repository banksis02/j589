-- Pet, hatching and effect suppression disabled. Retain sky-only preference.
if game.PlaceId ~= 107778070777162 then return end
local env = getgenv and getgenv() or _G
if env.SAE_PET_CULL_STOP then env.SAE_PET_CULL_STOP() end
local active = true
local saved, cloudsSaved, connections = {}, {}, {}
local lighting = game:GetService('Lighting')
local terrain = workspace:FindFirstChildOfClass('Terrain')
local function hideSky(obj)
    if not active then return end
    if obj.Parent == lighting and (obj:IsA('Sky') or obj:IsA('Atmosphere')) then
        saved[obj] = obj.Parent
        obj.Parent = nil
    elseif terrain and obj.Parent == terrain and obj:IsA('Clouds') then
        -- อย่า reparent Clouds! เกมมี LightingsController อ่าน Terrain.Clouds ทุกเฟรม
        -- ถ้าลบออกจะ error "Clouds is not a valid member" รัวๆ → แค่ปิดการแสดงผลพอ
        if cloudsSaved[obj] == nil then cloudsSaved[obj] = obj.Enabled end
        pcall(function() obj.Enabled = false end)
    end
end
local function stop()
    active = false
    for _, c in ipairs(connections) do c:Disconnect() end
    for obj, parent in pairs(saved) do
        pcall(function() if obj.Parent == nil then obj.Parent = parent end end)
    end
    for obj, enabled in pairs(cloudsSaved) do
        pcall(function() obj.Enabled = enabled end)
    end
    table.clear(saved)
    table.clear(cloudsSaved)
end
env.SAE_PET_CULL_STOP = stop
connections[1] = lighting.ChildAdded:Connect(hideSky)
if terrain then table.insert(connections, terrain.ChildAdded:Connect(hideSky)) end
for _, obj in ipairs(lighting:GetChildren()) do hideSky(obj) end
if terrain then for _, obj in ipairs(terrain:GetChildren()) do hideSky(obj) end end
print('[SAE PET CULL] disabled; surviving pet and egg visuals restored; sky-only mode')
