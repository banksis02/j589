-- GGX Scramble movement-only test: native game handles weapon and attacks.
local env=getgenv and getgenv() or _G
assert(not env.GGX_SAE_RUNTIME,'Run without the main farm script')
if env.GGX_SCRAMBLE_TEST then env.GGX_SCRAMBLE_TEST.destroy() end
local player=game:GetService('Players').LocalPlayer
local TweenService=game:GetService('TweenService')
local ENTRY=Vector3.new(2211.3125,69.64420318603516,-360.2830810546875)
local running=false
local target,move,moveRoot,moveGoal,lastChar
local entered=false
local nextPick=0
local gui=Instance.new('ScreenGui')
gui.Name='GGX_ScrambleMovementTest';gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild('PlayerGui')
local panel=Instance.new('Frame');panel.Size=UDim2.fromOffset(340,125);panel.Position=UDim2.new(0.5,-170,0.15,0);panel.BackgroundColor3=Color3.fromRGB(16,24,36);panel.Parent=gui
local label=Instance.new('TextLabel');label.Size=UDim2.new(1,-12,0,72);label.Position=UDim2.fromOffset(6,0);label.BackgroundTransparency=1;label.TextColor3=Color3.new(1,1,1);label.TextSize=14;label.TextWrapped=true;label.Parent=panel
local function show(s) if label.Text~=s then label.Text=s;print('[GGX SCRAMBLE MOVE] '..s) end end
local function cancel()
    if move then move:Cancel();move=nil end
    if moveRoot and moveRoot.Parent then moveRoot.AssemblyLinearVelocity=Vector3.zero end
    moveRoot=nil;moveGoal=nil
end
local function hp(model)
    if not model or not model.Parent then return end
    local r=model:FindFirstChild('RootPart')
    local board=r and r:FindFirstChild('ScrambleHealth')
    local bar=board and board:FindFirstChild('HealthProgress')
    local text=bar and bar:FindFirstChild('TextLabel')
    if not board or not board.Enabled or not text or not text.Visible then return end
    local a,b=text.Text:match('(%d+)%s*/%s*(%d+)%s*HP')
    return tonumber(a),tonumber(b),r
end
local function glide(root,pos)
    if move and move.PlaybackState==Enum.PlaybackState.Playing and moveRoot==root and (moveGoal-pos).Magnitude<5 then return end
    cancel();moveRoot=root;moveGoal=pos
    move=TweenService:Create(root,TweenInfo.new(math.max(0.1,(root.Position-pos).Magnitude/150),Enum.EasingStyle.Linear),{CFrame=CFrame.new(pos)})
    move:Play()
end
local function stop() running=false;target=nil;cancel();show('หยุดแล้ว') end
local connections={}
for i,title in ipairs({'START','STOP'}) do
    local b=Instance.new('TextButton');b.Size=UDim2.fromOffset(150,36);b.Position=UDim2.fromOffset(12+(i-1)*166,80);b.Text=title;b.TextSize=15;b.Parent=panel
    table.insert(connections,b.Activated:Connect(function()
        if i==1 then cancel();target=nil;entered=false;running=true else stop() end
    end))
end
local function tick()
    if not running then return end
    local c=player.Character
    local root=c and c:FindFirstChild('HumanoidRootPart')
    local h=c and c:FindFirstChildOfClass('Humanoid')
    if c~=lastChar then cancel();target=nil;entered=false;lastChar=c end
    if not root or not h or h.Health<=0 then cancel();target=nil;show('รอตัวละครเกิด • ไม่มีคำสั่งรีเซ็ต');return end
    if not entered then
        if (root.Position-ENTRY).Magnitude>10 then glide(root,ENTRY);show('ลอยเข้าโซนอีเวนต์ • 150 studs/s');return end
        cancel();entered=true;nextPick=os.clock()+1
    end
    if target then
        local value=hp(target)
        if not value or value<=0 then cancel();target=nil;nextPick=os.clock()+0.5;show('เป้าหมายหมดเลือดหรือหาย • หยุดติดตาม');return end
    end
    if not target then
        if os.clock()<nextPick then return end
        nextPick=os.clock()+1
        local folder=workspace:FindFirstChild('ScrambleLocalVisuals')
        local best=math.huge
        for _,m in ipairs(folder and folder:GetChildren() or {}) do
            if m:IsA('Model') and m.Name:match('^DroneVisual_') then
                local value,_,part=hp(m)
                if value and value>0 and part and part.Position.Y>20 then
                    local d=(root.Position-part.Position).Magnitude
                    if d<best then best=d;target=m end
                end
            end
        end
        if not target then cancel();show('อยู่ในโซนแล้ว • รอหุ่นโหลด/เกิด');return end
    end
    local value,max,part=hp(target)
    if not value or value<=0 or not part or part.Position.Y<20 then cancel();target=nil;return end
    local offset=root.Position-part.Position
    -- Stop outside the visual body; do not track into its centre.
    local size=target:GetAttribute('VisualSize')
    local radius=typeof(size)=='Vector3' and math.max(size.X,size.Z)/2+2 or 6
    if offset.Magnitude<=radius+1.5 then
        cancel();show('ถึงระยะแล้ว • ให้เกมตีเอง • '..value..'/'..max..' HP');return
    end
    local flat=Vector3.new(offset.X,0,offset.Z)
    local side=flat.Magnitude>0.1 and flat.Unit or Vector3.new(1,0,0)
    glide(root,part.Position+side*radius)
    show('ลอยเข้าใกล้หุ่น • '..value..'/'..max..' HP')
end
local thread=task.spawn(function()
    while gui.Parent do
        local ok,err=pcall(tick)
        if not ok then stop();show('ERROR '..tostring(err)) end
        task.wait(0.1)
    end
end)
env.GGX_SCRAMBLE_TEST={stop=stop,destroy=function()
    stop();task.cancel(thread)
    for _,c in ipairs(connections) do c:Disconnect() end
    gui:Destroy();env.GGX_SCRAMBLE_TEST=nil
end}
show('GGX SCRAMBLE • MOVE ONLY\nเลือก START • เกมถืออาวุธและตีเอง')
