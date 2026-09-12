-- ============================================================
-- STEAL AN EGG — SEQ (บินด้วย BodyVelocity = ไม่โดน ObbyAntiTP ดึงกลับ)
--   เทคนิคจาก naharsyaifullah: บินฟิสิกส์ (BodyVelocity) แทน CFrame/tween → server เห็นลื่นปกติ
--   ลำดับ: ยืนเซฟโซน → (ยกไข่มั่วหน้าเซฟโซน 1 ใบ→วาง) → ไข่ไกลระดับสูง → อุ้มกลับบ้าน(ฝากข้ามเส้น) → วน
-- ============================================================
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[SEQ] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h=hum() return h~=nil and h.Health>0 end

-- require game modules
local EggState, Assets
pcall(function() EggState = require(RS:WaitForChild("Client",10):WaitForChild("EggState",10)) end)
pcall(function() Assets   = require(RS:WaitForChild("Data",10):WaitForChild("Assets",10)) end)
log("EggState="..tostring(EggState~=nil).." Assets="..tostring(Assets~=nil))
if not EggState then warn("[SEQ] ❌ ไม่เจอ EggState"); return end

-- rarity map
local rarityOf={}
pcall(function() if Assets and Assets.Directory then for k,e in pairs(Assets.Directory) do local r=e and e.Rarity
    if type(r)=="table" then local info={name=r.DisplayName or "?",tier=r.RarityNumber or 0} rarityOf[tostring(k)]=info if e.Name then rarityOf[tostring(e.Name)]=info end end end end end)
local function rarityFor(cat) return rarityOf[tostring(cat)] or {name="?",tier=0} end

-- ปิด ObbyAntiTPClient (insurance เบาๆ ไม่ hook __namecall = ไม่เสี่ยง BAC; BodyVelocity ไม่ค่อยโดนอยู่แล้ว)
local function destroyAnti(root) if not root then return end for _,i in ipairs(root:GetDescendants()) do if i.Name=="ObbyAntiTPClient" and i:IsA("LocalScript") then pcall(function() i.Disabled=true i:Destroy() end) end end end
pcall(function() WS:SetAttribute("ClientObbyAntiTp",false) end)
pcall(function() destroyAnti(player:FindFirstChild("PlayerScripts")); destroyAnti(player.Character) end)
player.CharacterAdded:Connect(function() task.wait(0.5); pcall(function() WS:SetAttribute("ClientObbyAntiTp",false) destroyAnti(player:FindFirstChild("PlayerScripts")); destroyAnti(player.Character) end) end)

-- SeparationLine (เส้นแดง SAFE ZONE) — ฝาก = ข้ามเส้น
local line
pcall(function() local a=WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas"); line=a and a:FindFirstChild("SeparationLine") end)
local function lineNormal() local s=line.Size local n=(s.X<=s.Z) and line.CFrame.RightVector or line.CFrame.LookVector return Vector3.new(n.X,0,n.Z).Unit end
local function signedSide(pos) return (pos-line.Position):Dot(lineNormal()) end
local HOME = ENV.SAE_HOME or Vector3.new(425,70,-362)
local SAFE_SIGN = line and ((signedSide(HOME)>=0) and 1 or -1) or 1

local CFG={ SPEED=340, STAND_Y=3, RARITY="", MIN_TIER=0, GRAB_T=3.0, ARRIVE=6, LOOP_GAP=0.2, PRIME=true }
local carrying=false
pcall(function() if EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)

-- ===== บินด้วย BodyVelocity (ฟิสิกส์ = ไม่ lagback) =====
ENV.SAE_ALIVE=true
local function stopFly() end
local function killFly() end
-- ★★ วาปแบบ Humanoid-swap: ถอด Humanoid ออก → set CFrame → ใส่คืน
--    ObbyAntiTP เช็ค velocity ผ่าน Humanoid → ไม่มี Humanoid = เช็คไม่ได้ = วาปไกลไม่โดนดึงกลับ
--    (เทคนิคจากสคริปที่ใช้ได้จริง: teleport 4000+ studs/tick, Humanoid oscillate 0↔1)
local function flyTo(target, timeout, radius)
    local c=player.Character
    local hum=c and c:FindFirstChildOfClass("Humanoid")
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local dest=CFrame.new(target.X, target.Y+CFG.STAND_Y, target.Z)
    -- วาปเป็นสเต็ปใหญ่ (ถอด humanoid ระหว่างวาป) — ทำ 2-3 ครั้งให้ server รับตำแหน่งชัวร์
    for i=1,2 do
        c=player.Character; hum=c and c:FindFirstChildOfClass("Humanoid"); root=c and c:FindFirstChild("HumanoidRootPart")
        if not root then break end
        local par = hum and hum.Parent
        if hum then pcall(function() hum.Parent=nil end) end
        pcall(function() root.CFrame=dest end)
        if hum and par then pcall(function() hum.Parent=par end) end
        RunService.Heartbeat:Wait()
    end
    task.wait(0.1)   -- ให้ server รับตำแหน่งใหม่
    return true
end

-- ===== อ่านไข่ (Sync จาก server = เห็นไข่ไกล) =====
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local lastSync=0
local function fieldEggs()
    if os.clock()-lastSync>0.8 then lastSync=os.clock(); pcall(function() EggState.SyncFieldEggs() end) end
    local out={}
    local ok,data=pcall(function() return EggState.ReadFieldEggs() end)
    if ok and type(data)=="table" and type(data.Records)=="table" then
        local h=hrp(); local myPos=(h and h.Position) or Vector3.new()
        for _,rec in pairs(data.Records) do
            if type(rec)=="table" and rec.Uid then
                local pos=(typeof(rec.BoundsCFrame)=="CFrame") and rec.BoundsCFrame.Position or myPos
                local rr=rarityFor(rec.AssetCategory)
                out[#out+1]={uid=rec.Uid,pos=pos,cat=tostring(rec.AssetCategory),rarity=rr.name,tier=rr.tier,slotKey=slotKey(rec),dist=(pos-myPos).Magnitude}
            end
        end
    end
    return out
end
local function frontEgg() local e=fieldEggs(); table.sort(e,function(a,b) return (a.pos-HOME).Magnitude<(b.pos-HOME).Magnitude end); return e[1] end
local function wantTier(x)
    if CFG.MIN_TIER>0 and x.tier<CFG.MIN_TIER then return false end
    local w=(CFG.RARITY or ""):lower(); if w=="" then return true end
    for name in w:gmatch("[^,]+") do if x.rarity:lower()==name:gsub("%s","") then return true end end
    return false
end
local function targetEgg()
    local e=fieldEggs(); local o={}
    for _,x in ipairs(e) do if wantTier(x) then o[#o+1]=x end end
    table.sort(o,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist>b.dist end)  -- tier สูง+ไกลสุด
    return o[1]
end

-- ===== GRAB / DROP / CARRY-HOME =====
local function firePrompts(pos)
    if typeof(fireproximityprompt)~="function" then return end
    for _,c in ipairs(WS:GetChildren()) do
        if c.Name=="SmartPromptPart" and c:IsA("BasePart") and (c.Position-pos).Magnitude<=22 then
            for _,p in ipairs(c:GetChildren()) do if p:IsA("ProximityPrompt") then pcall(function() p.Enabled=true p.HoldDuration=0 p.MaxActivationDistance=math.max(p.MaxActivationDistance or 0,60) p.RequiresLineOfSight=false fireproximityprompt(p) end) end end
        end
    end
end
local function grab(egg)
    if carrying then return true end
    local reached=flyTo(egg.pos, 30, CFG.ARRIVE)
    local h=hrp(); local dleft=h and (Vector3.new(egg.pos.X,egg.pos.Y,egg.pos.Z)-h.Position).Magnitude or -1
    if dleft>15 then log("   ⚠️ ยังห่างไข่ "..math.floor(dleft).." studs") end
    local t=os.clock()
    while ENV.SAE_RUN and not carrying and os.clock()-t<CFG.GRAB_T do
        pcall(function() if EggState.CarryFieldEgg then EggState.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    return carrying
end
local function dropHere()
    pcall(function() if EggState.DropFieldEgg then EggState.DropFieldEgg() end end)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end
    return not carrying
end
-- ข้ามเส้น (บิน BodyVelocity ฝั่งสนาม→ฝั่งเซฟ) → ฝาก
local function crossOnce()
    if not line then return end
    local h=hrp(); if not h then return end
    local y=h.Position.Y; local n=lineNormal(); local safeDir=n*SAFE_SIGN
    local foot=h.Position - signedSide(h.Position)*n
    flyTo(Vector3.new((foot-safeDir*18).X,y,(foot-safeDir*18).Z), 3, 4)   -- ฝั่งสนาม
    flyTo(Vector3.new((foot+safeDir*40).X,y,(foot+safeDir*40).Z), 4, 4)   -- ข้ามกลับฝั่งเซฟ
end
local function carryHome()
    flyTo(HOME, 30, CFG.ARRIVE)                   -- บินกลับบ้าน (ข้ามเส้น = ฝาก)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end
    local tries=0
    while carrying and ENV.SAE_RUN and tries<5 do tries=tries+1; crossOnce() end
    return not carrying
end

-- ===== COMMANDS =====
local function bind(name,fn) ENV[name]=fn; pcall(function() _G[name]=fn end) end
bind("SAE_SETHOME", function() local h=hrp(); if h then ENV.SAE_HOME=h.Position; HOME=h.Position; if line then SAFE_SIGN=(signedSide(HOME)>=0) and 1 or -1 end log("ตั้ง HOME="..tostring(h.Position)) end end)
bind("SAE_TIER", function(x) CFG.RARITY=x or ""; log("target tier = "..(CFG.RARITY=="" and "ทุกระดับ(สูงสุดก่อน)" or CFG.RARITY)) end)
bind("SAE_PRIME", function(b) CFG.PRIME=(b==true); log("ยกไข่มั่วหน้าเซฟโซนก่อน = "..tostring(CFG.PRIME)) end)
bind("SAE_SPEED", function(s) CFG.SPEED=math.clamp(tonumber(s) or 340,16,1000); log("speed="..CFG.SPEED) end)
bind("SAE_LIST", function()
    local e=fieldEggs(); table.sort(e,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    log("ไข่ในสนาม "..#e.." ใบ:")
    for i=1,math.min(#e,15) do local x=e[i] print(("  #%d [%s t%d] %s @%.0f"):format(i,x.rarity,x.tier,x.cat,x.dist)) end
end)
bind("SAE_STOP", function() ENV.SAE_RUN=false stopFly() log("หยุด") end)
bind("SAE_KILL", function() ENV.SAE_RUN=false ENV.SAE_ALIVE=false killFly() log("ปิดหมด") end)
bind("SAE_START", function()
    ENV.SAE_RUN=true; log("▶️ START (หยุด SAE_STOP)")
    task.spawn(function()
        while ENV.SAE_RUN and ENV.SAE_ALIVE do
            flyTo(HOME, 30, CFG.ARRIVE)               -- ① ยืนเซฟโซน
            if CFG.PRIME then                          -- ② ยกไข่มั่วกองแรกหน้าเซฟโซน → วาง
                local first=frontEgg()
                if first then log("① กองแรกหน้าเซฟโซน: "..first.cat); if grab(first) then dropHere() end end
            end
            local tgt=targetEgg()                      -- ③ ไข่ไกลระดับสูง → อุ้มกลับบ้าน(ฝาก)
            if tgt then
                log("② เป้าหมาย: "..tgt.cat.." ["..tgt.rarity.."] @"..math.floor(tgt.dist))
                if grab(tgt) then log(carryHome() and "  ✅ ฝากเข้าบ้านแล้ว!" or "  ⚠️ ฝากไม่ผ่าน") else log("  ⚠️ อุ้มไม่ติด/ไปไม่ถึง") end
            else log("ไม่มีไข่ตรง tier"); task.wait(1) end
            task.wait(CFG.LOOP_GAP)
        end
        stopFly(); log("⏹️ หยุดลูป")
    end)
end)

log("✅ พร้อม! ยืนกลางเซฟโซน → SAE_SETHOME() → SAE_TIER(\"Mythic\") → SAE_START()   (ดูไข่: SAE_LIST() | speed: SAE_SPEED(400))")
