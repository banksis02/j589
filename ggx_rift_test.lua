-- GGX Rift test 0.3. Entry remote retained from the user's steal_an_egg_boss.lua.
-- Separate egg collector. Phase signals derived from three user arena snapshots.
local env = getgenv and getgenv() or _G
if env.GGX_RIFT_TEST then env.GGX_RIFT_TEST.destroy() end
local options = env.GGX_RIFT_CONFIG or {}
local moveSpeed = math.clamp(tonumber(options.moveSpeed) or 150, 10, 500)
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
local gui=Instance.new("ScreenGui")
gui.Name="GGX_Rift_Test"; gui.ResetOnSpawn=false; gui.DisplayOrder=10001
gui.Parent=player:WaitForChild("PlayerGui")
local frame=Instance.new("Frame"); frame.Size=UDim2.fromOffset(410,230)
frame.Position=UDim2.new(0.5,-205,0.15,0); frame.BackgroundColor3=Color3.fromRGB(14,20,30); frame.Parent=gui
local text=Instance.new("TextLabel"); text.BackgroundTransparency=1; text.Size=UDim2.new(1,-24,0,150)
text.Position=UDim2.fromOffset(12,8); text.TextColor3=Color3.new(1,1,1); text.TextSize=15
text.TextWrapped=true; text.Parent=frame
local function show(s,d)
    if state~=s or detail~=d then print("[GGX RIFT] "..s.." | "..d) end
    state,detail=s,d
    text.Text="GGX RIFT TEST 0.3 • "..moveSpeed.." studs/s\n"..state.."\n"..detail
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
    local words={}
    for word in tool.Name:lower():gmatch("%a+") do words[word]=true end
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
local function approachAndHit(target)
    local r,h=root(),humanoid()
    if not r or not h or h.Health<=0 or not target.Parent then cancelMove(); return end
    -- Equip while approaching as well as while in attack range.
    local tool=weapon()
    local equipped=tool and tool.Parent==player.Character
    if tool and not equipped and os.clock()-lastEquip>=1 then
        lastEquip=os.clock()
        local ok,err=pcall(function() h:UnequipTools(); h:EquipTool(tool) end)
        if not ok then warn("[GGX RIFT] Equip failed: "..tostring(err)) end
    elseif not tool then
        show("NO_WEAPON","ไม่พบอาวุธ Gear; รออาวุธโหลด ไม่เลือกสัตว์แทน")
    end
    local center=targetPosition(target)
    if not center then cancelMove(); return end
    local closest=closestPosition(target,r.Position)
    if (closest-r.Position).Magnitude>3 then
        local away=Vector3.new(r.Position.X-center.X,0,r.Position.Z-center.Z)
        if away.Magnitude<0.1 then away=Vector3.new(1,0,0) end
        local destination=Vector3.new(closest.X,r.Position.Y,closest.Z)+away.Unit*1.5
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
    if os.clock()-lastSwing>=0.35 then
        local ok,err=pcall(function() tool:Activate() end)
        lastSwing=os.clock()
        if not ok then warn("[GGX RIFT] Attack failed: "..tostring(err)) end
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
    local targets,unknown=stones()
    if #targets>0 then
        show("CRYSTALS","หินเหลือ "..#targets.." • เป้า "..targets[1].part.Name.." HP "..targets[1].health)
        approachAndHit(targets[1].part); return
    end
    if unknown>0 then cancelMove(); show("NEED_DATA","อ่าน HP หินไม่ได้ "..unknown.." ก้อน • กด COPY DATA"); return end
    local hand=exposedHand()
    if hand then
        show("HAND_OPEN",hand.Name.." • HP "..tostring(current).."/"..tostring(maximum).." • Attacking + ป้ายเลือดมือ")
        approachAndHit(hand)
    else cancelMove(); show("WAIT_HAND","รอมือลดลง • ไม่ตีตัวบอส • ถ้ามือลงแล้วไม่ตี กด COPY DATA") end
end
local function diagnostics()
    local out={"GGX_RIFT_DATA v0.3", "state="..state,"inside="..tostring(inside()),"detail="..detail}
    local function add(obj)
        local attrs={}; for k,v in pairs(obj:GetAttributes()) do table.insert(attrs,k.."="..tostring(v)) end
        local line=obj:GetFullName().." ["..obj.ClassName.."] "..table.concat(attrs,",")
        if obj:IsA("Bone") then line..=" world="..tostring(obj.TransformedWorldCFrame.Position) end
        if obj:IsA("BasePart") then line..=" pos="..tostring(obj.Position).." size="..tostring(obj.Size) end
        if obj:IsA("TextLabel") then line..=" text="..obj.Text end
        table.insert(out,line)
    end
    local a=arena()
    if a then
        add(a)
        for _,obj in ipairs(a:GetDescendants()) do
            if #out>=220 then table.insert(out,"TRUNCATED"); break end
            local n=obj.Name:lower()
            if obj:IsA("Model") or obj:IsA("TextLabel") or next(obj:GetAttributes())~=nil
                or n:find("hand") or n:find("fist") or n:find("palm") or n:find("hitbox") then add(obj) end
        end
    end
    local textOut=table.concat(out,"\n")
    print(textOut)
    if type(setclipboard)=="function" then setclipboard(textOut); show(state,"คัดลอกข้อมูลแล้ว ส่งมาในแชตได้เลย") end
    return textOut
end
local function start()
    if running then return end
    -- Do not let the separate egg collector move the character during the Rift test.
    if env.GGX_SAE_TEST and env.GGX_SAE_TEST.stop then env.GGX_SAE_TEST.stop() end
    if env.SAE_BOSS_STOP then pcall(env.SAE_BOSS_STOP) end
    running=true
    worker=task.spawn(function()
        while running do
            local ok,err=pcall(tick)
            if not ok then cancelMove(); show("ERROR",tostring(err)); running=false; break end
            task.wait(0.25)
        end
    end)
end
local function button(title,x,fn)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(122,40); b.Position=UDim2.fromOffset(x,175)
    b.Text=title; b.TextSize=14; b.Parent=frame; b.Activated:Connect(fn)
end
button("START",12,start); button("STOP",144,stop); button("COPY DATA",276,diagnostics)
env.GGX_RIFT_TEST={start=start,stop=stop,diagnostics=diagnostics,destroy=function() stop(); gui:Destroy(); env.GGX_RIFT_TEST=nil end}
show(state,detail)
