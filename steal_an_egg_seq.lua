-- ============================================================
-- STEAL AN EGG — SEQUENCE (ตามที่ user ออกแบบ)
--   1) ยืนหน้าจุดเซฟโซน  2) ไปกองไข่จุดแรก อุ้มไข่อะไรก็ได้ 1 ใบ → วาง(ฝาก)
--   3) แล้วค่อยไปเก็บไข่เป้าหมาย(ตาม tier) → วาง(ฝาก)  → วน
-- ขยับ "ตัวจริง" (CFrame ทุกเฟรม) = server เห็นการข้ามเส้น SeparationLine = ฝากได้จริง
-- ============================================================
local SCRIPT_VERSION = "v2.1"
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G

local CFG = { FLY_SPEED=380, STAND_Y=3, GRAB_T=3.0, DEPOSIT_T=6, LOOP_GAP=0.2, RARITY="", MIN_TIER=0 }

local function log(t) print("[SAE-SEQ "..SCRIPT_VERSION.."] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h=hum() return h and h.Health>0 end
local function req(path) local ok,m=pcall(function() local n=RS for _,s in ipairs(path) do n=n:WaitForChild(s,5) end return require(n) end) return ok and m or nil end

local EggState = req({"Client","EggState"})
local Assets   = req({"Data","Assets"})

-- rarity map
local rarityOf = {}
pcall(function()
    if Assets and Assets.Directory then
        for k,e in pairs(Assets.Directory) do
            local r = e and e.Rarity
            if type(r)=="table" then
                local info={ name=r.DisplayName or "?", tier=r.RarityNumber or 0 }
                rarityOf[tostring(k)]=info; if e.Name then rarityOf[tostring(e.Name)]=info end
            end
        end
    end
end)
local function rarityFor(cat) return rarityOf[tostring(cat)] or {name="?",tier=0} end

-- SeparationLine (เส้นแดง SAFE ZONE) + crossing
local line
pcall(function() local a=WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas"); line=a and a:FindFirstChild("SeparationLine") end)
local function lineNormal() local s=line.Size local n=(s.X<=s.Z) and line.CFrame.RightVector or line.CFrame.LookVector return Vector3.new(n.X,0,n.Z).Unit end
local function signedSide(pos) return (pos-line.Position):Dot(lineNormal()) end
local HOME = ENV.SAE_HOME or Vector3.new(425,70,-362)
local SAFE_SIGN = line and ((signedSide(HOME)>=0) and 1 or -1) or 1

-- carry state
local carrying=false
pcall(function() if EggState and EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true end) end end)

-- ===== MOVEMENT: flight controller (ตัวจริง CFrame ทุกเฟรม, noclip, ไม่ anchor) =====
ENV.SAE_ALIVE = true
local MOVE_GOAL=nil
task.spawn(function()   -- noclip
    while ENV.SAE_ALIVE do
        local ch=player.Character
        if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end end end
        RunService.Stepped:Wait()
    end
end)
task.spawn(function()   -- flight (ถือ CFrame ทุกเฟรม = ไม่ตกแมพ + ข้ามเส้น=ฝาก)
    while ENV.SAE_ALIVE do
        local dt=RunService.Heartbeat:Wait()
        local h=hrp()
        if h then
            if MOVE_GOAL==nil then MOVE_GOAL=h.Position end
            local d=MOVE_GOAL-h.Position; local m=d.Magnitude
            local np=(m<=CFG.FLY_SPEED*dt or m<1) and MOVE_GOAL or (h.Position+d.Unit*(CFG.FLY_SPEED*dt))
            pcall(function() h.CFrame=CFrame.new(np) end)
        end
    end
end)
local function flyTo(pos, arrive)
    MOVE_GOAL=Vector3.new(pos.X, pos.Y+CFG.STAND_Y, pos.Z)
    local dl=os.clock()+20
    while ENV.SAE_ALIVE and alive() do
        local h=hrp(); if not h then return false end
        if (MOVE_GOAL-h.Position).Magnitude < (arrive or 3) then return true end
        if os.clock()>dl then return false end
        RunService.Heartbeat:Wait()
    end
    return false
end
-- ข้ามเส้นแบบ explicit (เผื่อบินตรงยังไม่ trigger)
local function crossOnce()
    if not line then return end
    local h=hrp(); if not h then return end
    local y=h.Position.Y; local n=lineNormal(); local safeDir=n*SAFE_SIGN
    local foot=h.Position - signedSide(h.Position)*n
    MOVE_GOAL=Vector3.new((foot-safeDir*18).X, y, (foot-safeDir*18).Z)   -- ฝั่งสนาม
    local t=os.clock(); while carrying and os.clock()-t<1.2 and (MOVE_GOAL-(hrp() and hrp().Position or MOVE_GOAL)).Magnitude>3 do RunService.Heartbeat:Wait() end
    MOVE_GOAL=Vector3.new((foot+safeDir*38).X, y, (foot+safeDir*38).Z)   -- ข้ามกลับฝั่งเซฟ
    local t2=os.clock(); while carrying and os.clock()-t2<1.5 do RunService.Heartbeat:Wait() end
end

-- ===== EGGS =====
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local function fieldEggs()
    local out={}
    local ok,data=pcall(function() return EggState and EggState.ReadFieldEggs() end)
    if ok and type(data)=="table" and type(data.Records)=="table" then
        local myPos=(hrp() and hrp().Position) or Vector3.new()
        for _,rec in pairs(data.Records) do
            if type(rec)=="table" and rec.Uid then
                local pos=(typeof(rec.BoundsCFrame)=="CFrame") and rec.BoundsCFrame.Position or myPos
                local rr=rarityFor(rec.AssetCategory)
                out[#out+1]={uid=rec.Uid,pos=pos,cat=tostring(rec.AssetCategory),area=tostring(rec.AreaId),
                             rarity=rr.name,tier=rr.tier,slotKey=slotKey(rec),dist=(pos-myPos).Magnitude}
            end
        end
    end
    return out
end
local function nearestEgg()
    local e=fieldEggs(); table.sort(e,function(a,b) return a.dist<b.dist end); return e[1]
end
local function wantTier(x)
    if CFG.MIN_TIER>0 and x.tier<CFG.MIN_TIER then return false end
    local w=(CFG.RARITY or ""):lower(); if w=="" then return true end
    for name in w:gmatch("[^,]+") do if x.rarity:lower()==name:gsub("%s","") then return true end end
    return false
end
local function targetEgg()
    local e=fieldEggs(); local o={}
    for _,x in ipairs(e) do if wantTier(x) then o[#o+1]=x end end
    table.sort(o,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    return o[1]
end

-- ===== GRAB + DEPOSIT =====
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
    flyTo(egg.pos)
    local t=os.clock()
    while ENV.SAE_ALIVE and alive() and not carrying and os.clock()-t<CFG.GRAB_T do
        pcall(function() if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(egg.uid, egg.slotKey) end end)
        firePrompts(egg.pos)
        RunService.Heartbeat:Wait()
    end
    return carrying
end
-- "วาง" = ปล่อย/ทิ้งไข่ตรงนั้นเลย (ไม่อุ้มกลับบ้าน ไม่ข้ามเส้น)
local function dropHere()
    local ok=false
    pcall(function() if EggState and EggState.DropFieldEgg then EggState.DropFieldEgg() ok=true end end)
    local t=os.clock(); while carrying and os.clock()-t<1.5 do RunService.Heartbeat:Wait() end   -- รอปล่อยจริง
    return not carrying, ok
end

-- ===== COMMANDS =====
ENV.SAE_SETHOME=function()
    local h=hrp(); if h then ENV.SAE_HOME=h.Position; HOME=h.Position; if line then SAFE_SIGN=(signedSide(HOME)>=0) and 1 or -1 end log("ตั้ง HOME(เซฟโซน) = "..tostring(h.Position)) end
end
ENV.SAE_TIER=function(r) CFG.RARITY=r or ""; log("target tier = "..(CFG.RARITY=="" and "ทุกระดับ" or CFG.RARITY)) end
ENV.SAE_LIST=function()
    local e=fieldEggs(); table.sort(e,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    log("ไข่ในสนาม "..#e.." ใบ (เรียง tier):")
    for i=1,math.min(#e,12) do local x=e[i] print(("  #%d [%s t%d] %s @dist %.0f"):format(i,x.rarity,x.tier,x.cat,x.dist)) end
end
ENV.SAE_START=function()
    ENV.SAE_RUN=true; log("▶️ START — ยืนเซฟโซน→วาปเก็บใบแรกปล่อย→วาปเก็บเป้าหมายปล่อย (หยุด SAE_STOP)")
    task.spawn(function()
        while ENV.SAE_RUN and ENV.SAE_ALIVE and alive() do
            -- 1) ยืนหน้าจุดเซฟโซน
            flyTo(HOME); task.wait(0.15)
            -- 2) วาปไปไข่จุดแรก (ใกล้สุด) อุ้มอะไรก็ได้ 1 ใบ → ปล่อยตรงนั้น
            local first=nearestEgg()
            if first then
                log("① วาปเก็บไข่จุดแรก: "..first.cat.." (dist "..math.floor(first.dist)..")")
                if grab(first) then log(dropHere() and "  ✅ ปล่อยไข่แล้ว" or "  ⚠️ ปล่อยไม่สำเร็จ")
                else log("  ⚠️ อุ้มไม่ติด") end
            end
            -- 3) วาปไปไข่เป้าหมาย(tier) → ปล่อยตรงนั้น
            local tgt=targetEgg()
            if tgt then
                log("② วาปเก็บเป้าหมาย: "..tgt.cat.." ["..tgt.rarity.."]")
                if grab(tgt) then log(dropHere() and "  ✅ ปล่อยไข่เป้าหมายแล้ว" or "  ⚠️ ปล่อยไม่สำเร็จ")
                else log("  ⚠️ อุ้มไม่ติด") end
            else
                log("ไม่มีไข่ตรง tier — รอรอบใหม่"); task.wait(1)
            end
            task.wait(CFG.LOOP_GAP)
        end
        log("⏹️ หยุดลูปแล้ว")
    end)
end
ENV.SAE_STOP=function() ENV.SAE_RUN=false log("หยุด") end
ENV.SAE_KILL=function() ENV.SAE_RUN=false ENV.SAE_ALIVE=false log("ปิดหมด (คืนตัวละคร)") end

log("โหลดแล้ว ✅ EggState="..(EggState and"✅"or"❌").." Line="..(line and"✅"or"❌"))
log("ใช้: ยืนกลางเซฟโซน → SAE_SETHOME() → SAE_TIER(\"Mythic\") → SAE_START()  (ดูไข่: SAE_LIST())")
