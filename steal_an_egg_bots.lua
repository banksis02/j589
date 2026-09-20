-- ============================================================================
-- Steal An Egg — ตีบอท Dr. Scramble (Drone) : สแกนตัวใกล้สุด → ลอยไปหา → ตี
-- ลอยด้วย TweenService (ไม่ set CFrame ตรง = ไม่โดนดึงกลับ)
-- อาวุธ = Gear ช่อง 1 ของลูกค้า (ไม่ฟิก Katana) | ไม่ยิง remote ตอนตี = ปลอดภัย AC
-- คำสั่ง: SAE_BOTS_ON() / SAE_BOTS_OFF() / SAE_BOTS_STATUS() / SAE_BOTS_ENTER()
-- ============================================================================
if game.PlaceId~=107778070777162 then return end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G

_G.SAE_BOTS_GEN=(_G.SAE_BOTS_GEN or 0)+1
local GEN=_G.SAE_BOTS_GEN

local MELEE=13          -- ระยะฟันโดน
local STAND=5           -- ยืนห่างจากบอท (studs)
local MOVE_SPEED=90     -- ความเร็วลอย (studs/วิ)
local ATTACK_GAP=0.3    -- เว้นจังหวะฟัน

local function root() local c=plr.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=plr.Character return c and c:FindFirstChildOfClass("Humanoid") end

-- ---------- อาวุธ: Gear ที่ไม่ใช่ Trap (ของลูกค้า ช่อง 1) ----------
local function isTrap(t) return tostring(t:GetAttribute("GearName") or t.Name):lower():find("trap")~=nil end
local function isWeapon(t) return t:IsA("Tool") and t:GetAttribute("ItemType")=="Gear" and not isTrap(t) end
local function findWeapon()
    local c=plr.Character
    if c then for _,t in ipairs(c:GetChildren()) do if isWeapon(t) then return t end end end
    local bp=plr:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if isWeapon(t) then return t end end end
end
local lastEquip=0
local function ensureWeapon()
    local h=hum() if not h then return nil end
    local t=findWeapon() if not t then return nil end
    if t.Parent~=plr.Character then
        if tick()-lastEquip>1 then pcall(function() h:UnequipTools() h:EquipTool(t) end) lastEquip=tick() end
        return nil
    end
    return t
end

-- ---------- หาบอทโดรนตัวใกล้สุด ----------
local function dpart(m) return m:FindFirstChild("RootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart") end
local function isDrone(m)
    return m:IsA("Model") and (m:GetAttribute("ScrambleTier")~=nil or m:GetAttribute("ScrambleAnimatedRig")==true or m.Name:find("Drone")~=nil)
end
local function nearest()
    local r=root() if not r then return nil end
    local bm,bp,bd
    for _,folderName in ipairs({"ScrambleLocalVisuals","ACTUAL_DRONES"}) do
        local f=workspace:FindFirstChild(folderName)
        if f then for _,m in ipairs(f:GetChildren()) do
            if isDrone(m) then
                local p=dpart(m)
                if p then
                    local d=(p.Position-r.Position).Magnitude
                    if not bd or d<bd then bm,bp,bd=m,p,d end
                end
            end
        end end
    end
    return bm,bp,bd
end

-- ---------- ลอยเข้าหาเป้าด้วย tween (ไม่วาป) ----------
local tw,goal
local function stopMove() if tw then tw:Cancel() tw=nil end goal=nil end
local function glide(pos)
    local r=root() if not r then return math.huge end
    local flat=Vector3.new(r.Position.X-pos.X,0,r.Position.Z-pos.Z)
    local dir=flat.Magnitude>0.1 and flat.Unit or Vector3.new(0,0,1)
    local dest=Vector3.new(pos.X,pos.Y,pos.Z)+dir*STAND
    if (not tw) or tw.PlaybackState~=Enum.PlaybackState.Playing or (not goal) or (goal-dest).Magnitude>3 then
        stopMove() goal=dest
        local dur=math.max(0.08,(dest-r.Position).Magnitude/MOVE_SPEED)
        tw=TweenService:Create(r,TweenInfo.new(dur,Enum.EasingStyle.Linear),{CFrame=CFrame.lookAt(dest,Vector3.new(pos.X,dest.Y,pos.Z))})
        tw:Play()
    end
    return (r.Position-pos).Magnitude
end

-- ---------- ตี ----------
local lastSwing=0
local function swing(t)
    if tick()-lastSwing>=ATTACK_GAP and t.Enabled and t:GetAttribute("CooldownActive")~=true then
        pcall(function() t:Deactivate() t:Activate() end)
        lastSwing=tick()
    end
end

-- ---------- วาปเข้าโซนอีเวนต์ (optional) ----------
local function enterZone()
    local rf
    for _,d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteFunction") and (d.Name=="RF/MonsterEvent/RequestTeleport" or d.Name=="RF/Scramble/Request") then rf=d break end
    end
    if not rf then return false,"no remote" end
    local ok=pcall(function() return rf:InvokeServer() end)
    return ok,rf.Name
end

-- ---------- ลูปหลัก ----------
local running=false
local st="idle"
ENV.SAE_BOTS_ON=function()
    if running then print("[BOTS] ทำงานอยู่แล้ว") return end
    running=true
    print("[BOTS] เริ่มตีบอท (สแกนตัวใกล้สุด → ลอยไปหา → ตี)")
    task.spawn(function()
        while running and GEN==_G.SAE_BOTS_GEN do
            local h=hum()
            if not h or h.Health<=0 or not root() then
                st="no character" stopMove() task.wait(0.3)
            else
                local t=ensureWeapon()
                if not t then
                    st="waiting weapon" task.wait(0.3)
                else
                    local m,p=nearest()
                    if not m or not p then
                        st="no drones (waiting)" stopMove() task.wait(0.4)
                    else
                        local dist=glide(p.Position)
                        if dist<=MELEE then st=("ATTACK @ %.0f"):format(dist) swing(t)
                        else st=("glide @ %.0f"):format(dist) end
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end
        running=false st="stopped" stopMove()
    end)
end
ENV.SAE_BOTS_OFF=function() running=false stopMove() local h=hum() if h then h:Move(Vector3.zero) end print("[BOTS] หยุด") end
ENV.SAE_BOTS_STATUS=function()
    local m,_,d=nearest()
    print(("[BOTS] running=%s | state=%s | nearest=%s"):format(tostring(running),st,m and ("%.0f studs"):format(d) or "none"))
end
ENV.SAE_BOTS_ENTER=function()
    local ok,info=enterZone()
    print("[BOTS] ENTER: ok="..tostring(ok).." ("..tostring(info)..")")
end

print("[BOTS] โหลดแล้ว — SAE_BOTS_ENTER() วาปเข้าโซน / SAE_BOTS_ON() เริ่มตี / SAE_BOTS_OFF() หยุด / SAE_BOTS_STATUS() เช็ค")
