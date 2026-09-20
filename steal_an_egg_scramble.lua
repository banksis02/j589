-- ============================================================================
-- Steal An Egg — อีเวนต์ตีบอท Dr. Scramble (Drone) : ตีด้วย Katana melee
-- บอท = Workspace.ScrambleLocalVisuals.DroneVisual_* (RootPart, ไม่มี Humanoid)
-- ตี = เดินเข้าใกล้ (Humanoid:MoveTo) + หันหน้า + Tool:Activate (เกมคิดดาเมจเอง)
-- ไม่ยิง remote / ไม่ hook = ปลอดภัยกับ AC
-- ควบคุม: SAE_SCRAMBLE_ON() / SAE_SCRAMBLE_OFF() / SAE_SCRAMBLE_STATUS()
-- ============================================================================
if game.PlaceId~=107778070777162 then return end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local plr=Players.LocalPlayer

_G.SAE_SCRAMBLE_GEN=(_G.SAE_SCRAMBLE_GEN or 0)+1
local GEN=_G.SAE_SCRAMBLE_GEN

local CFG={ MELEE=13, STAND_GAP=5, MOVE_SPEED=90, ATTACK_GAP=0.3, REEQUIP_GAP=1.0, SEARCH_WAIT=0.4 }

local function char() return plr.Character end
local function root() local c=char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ---- อาวุธ: ใช้ของลูกค้าที่มี (Gear ที่ไม่ใช่ Trap) — ไม่ฟิก Katana ----
local function isTrap(t) return tostring(t:GetAttribute("GearName") or t.Name):lower():find("trap")~=nil end
local function isGearWeapon(t)
    return t:IsA("Tool") and t:GetAttribute("ItemType")=="Gear" and not isTrap(t)
end
local function findWeapon()
    -- 1) ที่ถืออยู่ (equipped) ก่อน ถ้าเป็นอาวุธ
    local c=char()
    if c then for _,t in ipairs(c:GetChildren()) do if isGearWeapon(t) then return t end end end
    -- 2) อาวุธ Gear ชิ้นแรกใน backpack (= อาวุธของลูกค้า ช่อง 1)
    local bp=plr:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if isGearWeapon(t) then return t end end end
    -- 3) fallback: tool แรกสุดที่ถืออยู่/ในกระเป๋า
    if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then return t end end end
    return bp and bp:FindFirstChildWhichIsA("Tool") or nil
end
local lastEquip=-math.huge
local function ensureEquipped()
    local h=hum(); if not h then return nil end
    local t=findWeapon(); if not t then return nil end
    if t.Parent~=char() then
        if os.clock()-lastEquip>=CFG.REEQUIP_GAP then
            pcall(function() h:UnequipTools(); h:EquipTool(t) end)
            lastEquip=os.clock()
        end
        return nil
    end
    return t
end

-- ---- หาบอทโดรน + อ่าน HP ----
local function dronePart(m)
    return m:FindFirstChild("RootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end
local function isDrone(m)
    if not m:IsA("Model") then return false end
    if m:GetAttribute("ScrambleTier")~=nil or m:GetAttribute("ScrambleAnimatedRig")==true then return true end
    return m.Name:find("Drone")~=nil
end
-- อ่าน HP จากป้าย 'X/Y' ที่เป็น descendant ของโดรน (คืน cur,max)
local function readHP(m)
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local a,b=tostring(d.Text):match("(%d+)%s*/%s*(%d+)")
            if a then return tonumber(a),tonumber(b) end
        end
    end
    return nil,nil
end
-- รวมโดรนทั้งหมด (ScrambleLocalVisuals เป็นหลัก + เผื่อ ACTUAL_DRONES)
local function allDrones()
    local list={}
    local seen={}
    for _,folderName in ipairs({"ScrambleLocalVisuals","ACTUAL_DRONES"}) do
        local folder=workspace:FindFirstChild(folderName)
        if folder then
            for _,m in ipairs(folder:GetChildren()) do
                if isDrone(m) and not seen[m] then
                    local p=dronePart(m)
                    if p then seen[m]=true; list[#list+1]={model=m,part=p} end
                end
            end
        end
    end
    return list
end
-- เลือกเป้า: HP มากก่อน (10/10 > 5/5 > 3/3) แล้วค่อยใกล้สุด
local function pickTarget()
    local r=root(); if not r then return nil end
    local list=allDrones()
    if #list==0 then return nil,0 end
    for _,e in ipairs(list) do
        local cur,max=readHP(e.model)
        e.hp=max or 0
        e.cur=cur or 1
        e.dist=(e.part.Position-r.Position).Magnitude
    end
    table.sort(list,function(a,b)
        if a.hp~=b.hp then return a.hp>b.hp end   -- HP สูงก่อน
        return a.dist<b.dist                        -- เท่ากัน = ใกล้ก่อน
    end)
    local t=list[1]
    return t.model, t.dist, t.hp, t.part, #list
end

-- ---- ตี ----
local lastSwing=0
local function swing(tool)
    if os.clock()-lastSwing>=CFG.ATTACK_GAP and tool.Enabled and tool:GetAttribute("CooldownActive")~=true then
        pcall(function() tool:Deactivate(); tool:Activate() end)
        lastSwing=os.clock()
    end
end
-- ลอยเข้าหาโดรนแบบลื่นด้วย TweenService (เหมือนตีหินบอส Rift) — ไม่ใช่ set CFrame ตรง = ไม่โดนดึงกลับ
local moveTween,curGoal
local function cancelMove() if moveTween then moveTween:Cancel(); moveTween=nil end curGoal=nil end
local function glideTo(targetPos)
    local r=root(); if not r then return math.huge end
    local flat=Vector3.new(r.Position.X-targetPos.X,0,r.Position.Z-targetPos.Z)
    local dir=flat.Magnitude>0.1 and flat.Unit or Vector3.new(0,0,1)
    local dest=Vector3.new(targetPos.X,targetPos.Y,targetPos.Z)+dir*CFG.STAND_GAP  -- ยืนห่าง STAND_GAP ที่ความสูงเป้า
    local goalCF=CFrame.lookAt(dest,Vector3.new(targetPos.X,dest.Y,targetPos.Z))
    -- สร้าง tween ใหม่เฉพาะตอนเป้าขยับ/tween จบ (กันกระตุก)
    if (not moveTween) or moveTween.PlaybackState~=Enum.PlaybackState.Playing
       or (not curGoal) or (curGoal-dest).Magnitude>3 then
        cancelMove()
        curGoal=dest
        local dur=math.max(0.08,(dest-r.Position).Magnitude/CFG.MOVE_SPEED)
        moveTween=TweenService:Create(r,TweenInfo.new(dur,Enum.EasingStyle.Linear),{CFrame=goalCF})
        moveTween:Play()
    end
    return (r.Position-targetPos).Magnitude
end

-- เข้าโซนอีเวนต์ (วาปเข้าไปหาโดรน) — ยิง remote ของเกมเอง เหมือน AskEnter ของบอส
local function findRemote(name)
    local direct=RS:FindFirstChild(name)   -- ชื่อมี "/" เป็นชื่อ child ตรงๆ ได้
    if direct and (direct:IsA("RemoteFunction") or direct:IsA("RemoteEvent")) then return direct end
    for _,d in ipairs(RS:GetDescendants()) do
        if (d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) and d.Name==name then return d end
    end
end
local lastEnter=-math.huge
local function enterZone()
    local rf=findRemote("RF/MonsterEvent/RequestTeleport") or findRemote("RF/Scramble/Request")
    if not rf then return false,"no remote" end
    local ok=pcall(function() return rf:InvokeServer() end)
    lastEnter=os.clock()
    return ok,rf.Name
end

local running=false
local state="idle"
local function loop()
    running=true
    while GEN==_G.SAE_SCRAMBLE_GEN and running do
        local h=hum()
        if not h or h.Health<=0 or not root() then state="no character"; cancelMove(); task.wait(0.4); continue end
        local tool=ensureEquipped()
        if not tool then state="waiting weapon"; task.wait(0.3); continue end
        local drone,_,thp,p=pickTarget()
        if not drone or not p then
            -- ไม่เจอบอท = อาจอยู่นอกโซน → วาปเข้าเองทุก 5 วิ
            if os.clock()-lastEnter>5 then state="no drones — เข้าโซน"; enterZone() else state="no drones (waiting)" end
            cancelMove(); task.wait(CFG.SEARCH_WAIT); continue
        end
        local dist=glideTo(p.Position)          -- ลอยเข้าหาโดรนแบบลื่น (tween)
        if dist<=CFG.MELEE then
            state=string.format("ATTACK drone HP%d (%.0f)",thp or 0,dist)
            swing(tool)
        else
            state=string.format("gliding → drone HP%d (%.0f)",thp or 0,dist)
        end
        RunService.Heartbeat:Wait()
    end
    running=false
    state="stopped"
end

ENV.SAE_SCRAMBLE_ENTER=function()
    local ok,info=enterZone()
    print("[SCRAMBLE] ENTER fired: ok="..tostring(ok).." ("..tostring(info)..")")
end
ENV.SAE_SCRAMBLE_ON=function()
    if running then print("[SCRAMBLE] กำลังทำงานอยู่แล้ว"); return end
    print("[SCRAMBLE] เริ่มตีบอท (ใช้อาวุธในช่อง 1, ตีตัว HP มากก่อน)")
    task.spawn(loop)
end
ENV.SAE_SCRAMBLE_OFF=function()
    running=false
    cancelMove()
    local h=hum(); if h then h:Move(Vector3.zero) end
    print("[SCRAMBLE] หยุด")
end
ENV.SAE_SCRAMBLE_STATUS=function()
    local d,dist,thp,_,n=pickTarget()
    print(string.format("[SCRAMBLE] running=%s | state=%s | drones=%d | target=%s",
        tostring(running),state,n or 0,d and string.format("HP%d @ %.0f",thp or 0,dist or -1) or "none"))
end

print("[SCRAMBLE] โหลดแล้ว — พิมพ์ SAE_SCRAMBLE_ON() เพื่อเริ่มตีบอท / SAE_SCRAMBLE_OFF() หยุด / SAE_SCRAMBLE_STATUS() เช็ค")
