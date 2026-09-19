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
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local plr=Players.LocalPlayer

_G.SAE_SCRAMBLE_GEN=(_G.SAE_SCRAMBLE_GEN or 0)+1
local GEN=_G.SAE_SCRAMBLE_GEN

local CFG={ MELEE=16, ATTACK_GAP=0.3, REEQUIP_GAP=1.0, SEARCH_WAIT=0.4 }

local function char() return plr.Character end
local function root() local c=char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ---- อาวุธ (Katana / IsBat / Gear ที่เป็นดาบ) ----
local function isWeapon(t)
    if not t:IsA("Tool") then return false end
    if t:GetAttribute("IsBat")==true then return true end
    if t:GetAttribute("ItemType")~="Gear" then return false end
    local words={}
    for wd in tostring(t:GetAttribute("GearName") or t.Name):lower():gmatch("%a+") do words[wd]=true end
    if words.trap then return false end
    return words.katana or words.sword or words.blade or words.axe or words.bat or false
end
local function findWeapon()
    for _,holder in ipairs({char(),plr:FindFirstChild("Backpack")}) do
        if holder then for _,t in ipairs(holder:GetChildren()) do if isWeapon(t) then return t end end end
    end
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

-- ---- หาบอทโดรน ----
local function dronePart(m)
    return m:FindFirstChild("RootPart") or m:FindFirstChildWhichIsA("BasePart")
end
local function isDrone(m)
    if not m:IsA("Model") then return false end
    if m:GetAttribute("ScrambleTier")~=nil or m:GetAttribute("ScrambleAnimatedRig")==true then return true end
    return m.Name:find("Drone")~=nil
end
local function nearestDrone()
    local folder=workspace:FindFirstChild("ScrambleLocalVisuals")
    if not folder then return nil end
    local r=root(); if not r then return nil end
    local best,bestD
    for _,m in ipairs(folder:GetChildren()) do
        if isDrone(m) then
            local p=dronePart(m)
            if p then
                local d=(p.Position-r.Position).Magnitude
                if not bestD or d<bestD then best,bestD=m,d end
            end
        end
    end
    return best,bestD
end

-- ---- ตี ----
local lastSwing=0
local function faceAndSwing(targetPos,tool)
    local r=root(); if not r then return end
    -- หันหน้าเข้าหาบอท (rotation อย่างเดียว ปลอดภัย)
    pcall(function() r.CFrame=CFrame.lookAt(r.Position,Vector3.new(targetPos.X,r.Position.Y,targetPos.Z)) end)
    if os.clock()-lastSwing>=CFG.ATTACK_GAP and tool.Enabled and tool:GetAttribute("CooldownActive")~=true then
        pcall(function() tool:Deactivate(); tool:Activate() end)
        lastSwing=os.clock()
    end
end

local running=false
local state="idle"
local function loop()
    running=true
    while GEN==_G.SAE_SCRAMBLE_GEN and running do
        local h=hum()
        if not h or h.Health<=0 or not root() then state="no character"; task.wait(0.4); continue end
        local tool=ensureEquipped()
        if not tool then state="waiting Katana"; task.wait(0.3); continue end
        local drone,dist=nearestDrone()
        if not drone then state="no drones (waiting)"; if h then h:Move(Vector3.zero) end; task.wait(CFG.SEARCH_WAIT); continue end
        local p=dronePart(drone)
        if not p then task.wait(0.1); continue end
        if dist>CFG.MELEE then
            state=string.format("moving → drone (%.0f)",dist)
            h:MoveTo(p.Position)
            task.wait(0.12)
        else
            state=string.format("ATTACK drone (%.0f)",dist)
            h:Move(Vector3.zero)          -- หยุดเดินตอนตี
            faceAndSwing(p.Position,tool)
            task.wait(0.06)
        end
    end
    running=false
    state="stopped"
end

ENV.SAE_SCRAMBLE_ON=function()
    if running then print("[SCRAMBLE] กำลังทำงานอยู่แล้ว"); return end
    print("[SCRAMBLE] เริ่มตีบอท (Katana melee)")
    task.spawn(loop)
end
ENV.SAE_SCRAMBLE_OFF=function()
    running=false
    local h=hum(); if h then h:Move(Vector3.zero) end
    print("[SCRAMBLE] หยุด")
end
ENV.SAE_SCRAMBLE_STATUS=function()
    local d,dist=nearestDrone()
    local folder=workspace:FindFirstChild("ScrambleLocalVisuals")
    local n=0; if folder then for _,m in ipairs(folder:GetChildren()) do if isDrone(m) then n+=1 end end end
    print(string.format("[SCRAMBLE] running=%s | state=%s | drones=%d | nearest=%s",tostring(running),state,n,d and string.format("%.0f",dist or -1) or "none"))
end

print("[SCRAMBLE] โหลดแล้ว — พิมพ์ SAE_SCRAMBLE_ON() เพื่อเริ่มตีบอท / SAE_SCRAMBLE_OFF() หยุด / SAE_SCRAMBLE_STATUS() เช็ค")
