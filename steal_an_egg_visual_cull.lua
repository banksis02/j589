-- Local reversible pet presentation test. No inventory/remotes/teleports.
if game.PlaceId ~= 107778070777162 then return end
local env=getgenv and getgenv() or _G
if env.SAE_PET_CULL_STOP then env.SAE_PET_CULL_STOP() end
local folder=workspace:FindFirstChild('ClientRenderedAssets')
local active=true
local connections={}
local saved={}
local detached={}
local tracked=setmetatable({},{__mode='k'})
local hidden=0
local watched=setmetatable({},{__mode='k'})
local function clearParticles(obj)
    if obj:IsA('ParticleEmitter') or obj:IsA('Trail') then
        pcall(function()obj:Clear()end)
    end
end
local function change(obj,key,value)
    local ok,old=pcall(function()return obj[key]end)
    if not ok or old==value then return end
    saved[obj]=saved[obj] or {}
    if saved[obj][key]==nil then saved[obj][key]={old=old,new=value} end
    pcall(function()obj[key]=value end)
end
local function enforce(obj,key,value)
    change(obj,key,value)
    watched[obj]=watched[obj] or {}
    if watched[obj][key] then return end
    watched[obj][key]=true
    table.insert(connections,obj:GetPropertyChangedSignal(key):Connect(function()
        if not active then return end
        pcall(function()if obj[key]~=value then obj[key]=value end end)
        clearParticles(obj)
    end))
end
local function suppress(obj)
    if obj:IsA('ParticleEmitter') or obj:IsA('Trail') or obj:IsA('Beam')
        or obj:IsA('BillboardGui') or obj:IsA('SurfaceGui') or obj:IsA('Light') then
        enforce(obj,'Enabled',false)
        clearParticles(obj)
        if obj:IsA('ParticleEmitter') then enforce(obj,'Rate',0) end
    elseif obj:IsA('Sound') then
        enforce(obj,'Volume',0)
    elseif obj:IsA('BasePart') then
        enforce(obj,'LocalTransparencyModifier',1)
        enforce(obj,'CastShadow',false)
    elseif obj:IsA('Decal') or obj:IsA('Texture') then
        enforce(obj,'Transparency',1)
    elseif obj:IsA('Highlight') then
        enforce(obj,'Enabled',false)
    elseif obj:IsA('Fire') or obj:IsA('Smoke') or obj:IsA('Sparkles') then
        enforce(obj,'Enabled',false)
    end
end
local function accept(model)
    if not active or tracked[model] or not model:IsA('Model') then return end
    if model:GetAttribute('UID')==nil or model:GetAttribute('OwnerUserId')==nil then return end
    tracked[model]=true
    local function apply(obj)
        if not active then return end
        suppress(obj)
        -- Only the observed nested visual Model; retain CENTER/root and outer model.
        if obj.Parent==model and obj.Name=='Model' and obj:IsA('Model') then
            detached[obj]=model
            obj.Parent=nil
            hidden+=1
        end
    end
    for _,obj in ipairs(model:GetDescendants()) do apply(obj) end
    table.insert(connections,model.DescendantAdded:Connect(function(obj)
        task.defer(function()if active then apply(obj) end end)
    end))
end
local function stop()
    if not active then return end
    active=false
    for _,c in ipairs(connections) do c:Disconnect() end
    for obj,props in pairs(saved) do
        for key,v in pairs(props) do
            pcall(function()if obj[key]==v.new then obj[key]=v.old end end)
        end
    end
    for obj,parent in pairs(detached) do
        pcall(function()
            if obj.Parent==nil and parent.Parent==folder and not parent:FindFirstChild('Model') then
                obj.Parent=parent
            end
        end)
    end
    table.clear(saved);table.clear(detached)
    print('[SAE PET CULL] stopped; restored surviving visuals')
end
env.SAE_PET_CULL_STOP=stop
local petFolders=setmetatable({},{__mode='k'})
local function watchPetFolder(value)
    if not active or value.Name~='ClientRenderedAssets' or not value:IsA('Folder') or petFolders[value] then return end
    folder=value
    petFolders[value]=true
    table.insert(connections,value.ChildAdded:Connect(function(model)
        task.defer(function()
            if not active then return end
            accept(model)
            if not tracked[model] then
                task.delay(2,function()if active and model.Parent==value then accept(model) end end)
            end
        end)
    end))
    for _,model in ipairs(value:GetChildren()) do accept(model) end
end
table.insert(connections,workspace.ChildAdded:Connect(watchPetFolder))
if folder then watchPetFolder(folder) end
-- PlacedEggRenders is the observed hatching presentation container.
-- Keep models/hitboxes/collisions intact; do not touch AreaEggSlotsClient.
local eggFolders=setmetatable({},{__mode='k'})
local function watchEggFolder(eggs)
    if not active or eggs.Name~='PlacedEggRenders' or not eggs:IsA('Folder') or eggFolders[eggs] then return end
    eggFolders[eggs]=true
    table.insert(connections,eggs.DescendantAdded:Connect(function(obj)
        task.defer(function()
            if active and obj:IsDescendantOf(eggs) then suppress(obj) end
        end)
    end))
    for _,obj in ipairs(eggs:GetDescendants()) do suppress(obj) end
    print('[SAE PET CULL] hatching visuals hidden; entries='..#eggs:GetChildren())
end
local eggs=workspace:FindFirstChild('PlacedEggRenders')
if eggs then watchEggFolder(eggs) end
table.insert(connections,workspace.ChildAdded:Connect(watchEggFolder))
print('[SAE PET CULL] visual models detached: '..hidden..'; inventory untouched')
print('[SAE PET CULL] restore: getgenv().SAE_PET_CULL_STOP()')
-- Emit() can produce particles even while Enabled=false. Clear only pet effects.
task.spawn(function()
    while active do
        task.wait(.5)
        if not active then break end
        for obj in pairs(watched) do clearParticles(obj) end
    end
end)
