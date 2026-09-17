-- GGX Oxide-adapted collector test v0.2. Not the production runtime.
local env=getgenv and getgenv() or _G
assert(not env.GGX_SAE_RUNTIME, 'Run this test in a fresh session without the main script')
if env.GGX_OXIDE_TEST and env.GGX_OXIDE_TEST.destroy then env.GGX_OXIDE_TEST.destroy() end
assert(not env.GGX_SAE_TEST, 'Stop the other egg test and rejoin before running Oxide test')
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
-- Adapted from Oxide StealSpecificEggRobust + TravelRoadPath.
-- Test only: no hatch, placement, sales, boss, or treadmill actions.
local M = {}
local RS=game:GetService('ReplicatedStorage')
local LP=game:GetService('Players').LocalPlayer
local TweenService=game:GetService('TweenService')
local EggState=require(RS.Client.EggState)
local Assets=require(RS.Data.Assets)
local Save=require(RS.Shared.Save)
local Identity=require(RS.Shared.Util.AreaEggSlotIdentity)
local active=false
local worker,tween
local areas,rarities={},{}
local logs,audits={},{}
local function log(s)
    print('[GGX OXIDE TEST] '..s)
    for _,fn in ipairs(logs) do pcall(fn,s) end
end
local function root() return LP.Character and LP.Character:FindFirstChild('HumanoidRootPart') end
local function hum() return LP.Character and LP.Character:FindFirstChildOfClass('Humanoid') end
local function records()
    local ok,s=pcall(EggState.ReadFieldEggs)
    return ok and type(s)=='table' and s.Records or nil
end
local function record(uid)
    for _,r in pairs(records() or {}) do if r.Uid==uid then return r end end
end
local function carried(uid)
    local r=record(uid)
    return r and tonumber(r.CarrierUserId)==LP.UserId and tostring(r.State):lower()=='carried'
end
local function bag(uid)
    local ok,d=pcall(Save.Get)
    return ok and d and d.EggInventory and d.EggInventory[uid]~=nil
end
local function home()
    for _,p in ipairs(workspace.Plots:GetChildren()) do
        local sign=p:FindFirstChild('PlotSign')
        local board=sign and sign:FindFirstChild('PlayerPlotSign')
        local f=board and board:FindFirstChild('Frame')
        local i=f and f:FindFirstChild('PlayerIcon')
        if i and i.Image:match('[?&]id=(%d+)')==tostring(LP.UserId) then
            local c=p:FindFirstChild('CenterPoint')
            if c then return Vector3.new(c.Position.X,math.max(c.Position.Y,70.4),c.Position.Z) end
        end
    end
end
local function ragdolled()
    local h=hum()
    if not h then return true end
    local s=h:GetState()
    return s==Enum.HumanoidStateType.Physics or s==Enum.HumanoidStateType.Ragdoll
        or s==Enum.HumanoidStateType.FallingDown or s==Enum.HumanoidStateType.PlatformStanding
end
-- Oxide MoveToPoint: advance from the current replicated position each Heartbeat.
local function move(pos,speed,uid)
    local r,h=root(),hum()
    if not active or not r or not h or h.Health<=0 then
        log('MOVE BLOCKED: character not alive/ready'); return false
    end
    speed=math.clamp(tonumber(speed) or 750,50,750)
    local total=(r.Position-pos).Magnitude
    local deadline=os.clock()+math.min(total/50+5,60)
    local best=total
    local progressAt=os.clock()
    while active do
        if root()~=r or hum()~=h or h.Health<=0 then
            log('MOVE CANCEL: character changed/dead'); return false
        end
        if uid and not carried(uid) then
            r.AssemblyLinearVelocity=Vector3.zero
            log('MOVE CANCEL: carry lost')
            return bag(uid) or false
        end
        local delta=pos-r.Position
        local remaining=delta.Magnitude
        if remaining<1 then
            r.AssemblyLinearVelocity=Vector3.zero
            r.AssemblyAngularVelocity=Vector3.zero
            return true
        end
        if remaining<best-1 then best=remaining;progressAt=os.clock() end
        if os.clock()>deadline or os.clock()-progressAt>3 then
            r.AssemblyLinearVelocity=Vector3.zero
            log(string.format('MOVE BLOCKED: remaining=%.1f; position=%s',remaining,tostring(r.Position)))
            return false
        end
        local dt=game:GetService('RunService').Heartbeat:Wait()
        -- STOP/respawn/carry can change while waiting; never write stale character state.
        if not active or root()~=r or hum()~=h or h.Health<=0 then return false end
        if uid and not carried(uid) then r.AssemblyLinearVelocity=Vector3.zero;return bag(uid) or false end
        delta=pos-r.Position
        if delta.Magnitude>0 then
            local nextPos=r.Position+delta.Unit*math.min(speed*math.min(dt,0.1),delta.Magnitude)
            r.CFrame=CFrame.lookAt(nextPos,nextPos+delta.Unit)
        end
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end
    return false
end
local function travel(pos,uid)
    local r=root(); if not r then return false end
    local y=math.max(r.Position.Y,pos.Y,70.4)
    local route={{Vector3.new(r.Position.X,y,-364.5),750}}
    if uid and r.Position.X>580 then
        table.insert(route,{Vector3.new(580,y,-364.5),750})
    end
    table.insert(route,{Vector3.new(pos.X,y,-364.5),uid and 245 or 750})
    table.insert(route,{pos+Vector3.new(0,1.2,0),uid and 245 or 750})
    for index,step in ipairs(route) do
        if uid and bag(uid) then return true end
        if not move(step[1],step[2],uid) then log('ROUTE STOP: segment '..index);return false end
    end
    return true
end
local function pickup(uid)
    local r=record(uid)
    if not active or not r then return false end
    local key
    if Identity.LooksLikeFirstAreaUid(r.Uid) then key=Identity.SlotKey(r.AreaId,r.NestId) end
    -- One request at a time; stopping cancels this worker before any further requests.
    local ok,err=pcall(function() EggState.CarryFieldEgg(uid,key) end)
    if not ok then log('Carry error: '..tostring(err)) end
    local untilTime=os.clock()+1.5
    repeat
        if not active then return false end
        if carried(uid) then return true end
        task.wait(0.03)
    until os.clock()>=untilTime
    return false
end
local function collect(target)
    local uid=target.Uid
    local base=home()
    if not base then log('Cannot identify own plot'); return end
    local latest=record(uid)
    if not latest or ((latest.State~='Slot' and latest.State~='Dropped') and latest.State~='Dropped') or not latest.BoundsCFrame then return end
    log('APPROACH '..tostring(latest.AssetCategory)..' / '..tostring(latest.AreaId))
    if not travel(latest.BoundsCFrame.Position) then task.wait(2);return end
    log('ARRIVED: requesting pickup')
    if not pickup(uid) then log('Pickup not confirmed'); return end
    log('WAIT GUARD: '..uid)
    local t=os.clock()
    while active and carried(uid) and os.clock()-t<4 and not ragdolled() do task.wait(0.05) end
    if not active then return end
    if ragdolled() or not carried(uid) then
        log('RECOVER: wait until standing before pickup')
        task.wait(0.65)
        t=os.clock()
        while active and ragdolled() and os.clock()-t<3.2 do
            local h=hum();if h then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
            task.wait(0.12)
        end
        if not active or ragdolled() then return end
        task.wait(0.35)
        -- Oxide gives the guard time to return idle. Re-read UID rather than old nest position.
        task.wait(1.6)
        for _=1,3 do
            if not active then return end
            if carried(uid) then break end
            local dropped=record(uid)
            if not dropped or not dropped.BoundsCFrame then return end
            local state=tostring(dropped.State):lower()
            if state~='slot' and state~='dropped' then task.wait(0.3);continue end
            if not move(dropped.BoundsCFrame.Position+Vector3.new(0,1.8,0),750) then return end
            if pickup(uid) then break end
        end
    end
    if not active or not carried(uid) then log('No egg held; cancel return');return end
    log('RETURN: confirmed local carry')
    if not travel(base,uid) then log('Carry lost during return; rescan');return end
    t=os.clock()
    while active and not bag(uid) and os.clock()-t<3 do task.wait(0.05) end
    log(bag(uid) and 'DELIVERED: UID found in EggInventory' or 'UNCONFIRMED: UID not in bag')
end
function M.getAllMaps()
    local result={}
    for _,name in ipairs({'Forest','Lake','Desert','Jungle','Snow','Volcano','Abyss Ocean','Prehistoric','Cosmic','Cherry Blossom','Titan Temple','Light Dark'}) do table.insert(result,{name=name}) end
    return result
end
function M.setTargets(_) end
function M.setFilters(a,r) areas=table.clone(a);rarities=table.clone(r);return 'applied' end
function M.onLog(fn) table.insert(logs,fn) end
function M.onAudit(fn) table.insert(audits,fn) end
function M.isRunning() return active end
function M.stop()
    active=false
    if tween then tween:Cancel();tween=nil end
    if worker then pcall(task.cancel,worker);worker=nil end
    local r=root();if r then r.AssemblyLinearVelocity=Vector3.zero end
    log('STOPPED')
end
M.destroy=M.stop
function M.start()
    if active then return end
    assert(home(),'Cannot identify own plot')
    active=true
    worker=task.spawn(function()
        while active do
            local candidates={}
            local r=root()
            for _,egg in pairs(records() or {}) do
                if (egg.State=='Slot' or egg.State=='Dropped') and egg.BoundsCFrame and egg.Uid and Filter.allowed(egg,Assets,areas,rarities) then
                    table.insert(candidates,{record=egg,rarity=Filter.rarity(egg,Assets),dFromPlayer=r and (r.Position-egg.BoundsCFrame.Position).Magnitude or math.huge})
                end
            end
            table.sort(candidates,Filter.prefer)
            for _,fn in ipairs(audits) do pcall(fn,'OXIDE / selected='..#candidates) end
            if candidates[1] then
                local ok,err=pcall(collect,candidates[1].record)
                if not ok then log('ERROR '..tostring(err));if tween then tween:Cancel();tween=nil end end
            end
            task.wait(0.5)
        end
    end)
end
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
local title = label("GGX / OXIDE COLLECTOR · TEST 0.2",16,10,390,28,16)
local function button(text,x,y,w,h,fn)
    local b = make("TextButton", {Text=text, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        BackgroundColor3=tile, TextColor3=Color3.fromRGB(240,246,255), BorderSizePixel=0,
        Font=Enum.Font.Gotham, TextSize=12, AutoButtonColor=true}, panel)
    make("UICorner", {CornerRadius=UDim.new(0,6)}, b)
    connect(b.Activated, fn)
    return b
end
local status = label("เลือกโซนและระดับไข่ แล้วกด START",16,43,438,35,13)
local function report(text)
    status.Text = tostring(text)
    print("[GGX SAE TEST] " .. tostring(text))
end
local chosenAreas, chosenRarities = {}, {}
local options = env.GGX_OXIDE_TEST_CONFIG or {}
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
label("RARITY • เก็บระดับสูงสุดที่เลือกก่อน",16,228,438,20,12)
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
label("เก็บ → รอยามตี → ลุกและเก็บคืน → กลับบ้านตัวเอง",16,314,438,22,11)
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
env.GGX_OXIDE_TEST = {
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
        env.GGX_OXIDE_TEST = nil
    end,
}

if options.autoStart == true then start() end
