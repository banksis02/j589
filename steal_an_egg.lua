-- ============================================================
-- STEAL AN EGG — FARM v0.8  placeId 107778070777162
-- รวมทุกอย่างที่เรียนมา + บินสูงข้าม Guard (เก็บไข่ระดับสูงโซนไกลได้)
--   1) ปิด ObbyAntiTP (bypass lagback) — from monthonsova SpeedBypass
--   2) anti-fall กันโดนตีปลิว (ไม่ใช้ noclip แล้ว = มีพื้นยืน ไม่ตกแมพ)
--   3) บินไปไข่ → EggState.CarryFieldEgg + fireproximityprompt เก็บ
--   4) ⭐ บินสูง (เหนือ guard) กลับ safe zone → ฝาก (guard จับไม่ได้)
--   5) กรอง rarity (Mythic+) จาก Data.Assets/Rarity
--
--   SAE_SETHOME()      ยืนกลาง SAFE ZONE แล้วเรียก (จุดฝาก)
--   SAE_TIER("Mythic") ตั้งระดับ (ว่าง=ทุกระดับ; ใส่คั่นด้วย , ได้)
--   SAE_LIST() / SAE_TAP(1) / SAE_STEAL() / SAE_STOP()
-- ============================================================

local SCRIPT_VERSION = "v1.3"
_G.SAE_GEN = (_G.SAE_GEN or 0) + 1
local GEN = _G.SAE_GEN
local function alive() return GEN == _G.SAE_GEN end

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local player     = Players.LocalPlayer
local ENV = (type(getgenv) == "function" and getgenv()) or _G

local CFG = {
    FLY_SPEED   = 500,   -- ความเร็วบิน (studs/วิ)
    FLY_STEP    = 6,     -- ขยับต่อเฟรม (เล็ก=เนียน/ไม่กระตุก AC)
    FLY_HEIGHT  = 0,     -- 0 = ขากลับบินราบระดับปกติ (ลอยแค่ STAND_Y ไม่ปีนขึ้น)
    STAND_Y     = 3,
    COLLECT_T   = 2.5,   -- พยายามเก็บนานสุด (วิ)
    DEPOSIT_T   = 6,     -- รอฝากเสร็จ (วิ)
    RARITY      = "",    -- SAE_TIER
    MIN_TIER    = 0,     -- หรือกรองด้วย tier number
    LOOP_GAP    = 0.15,
}

local function log(t) print("[SAE " .. SCRIPT_VERSION .. "] " .. tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end

-- ── require โมดูลเกม ─────────────────────────────────────────
local function req(path)
    local ok,m = pcall(function() local n=RS for _,s in ipairs(path) do n=n:WaitForChild(s,5) end return require(n) end)
    return ok and m or nil
end
local EggState = req({"Client","EggState"})
local Assets   = req({"Data","Assets"})
local NET = RS:FindFirstChild("Packages"); NET=NET and NET:FindFirstChild("Networking")
local SNAP  = NET and NET:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")

-- rarity map: ชนิด → {name,tier}
local rarityOf = {}
pcall(function()
    if Assets and Assets.Directory then
        for k,e in pairs(Assets.Directory) do
            local r = e and e.Rarity
            if type(r)=="table" then
                local info = { name=r.DisplayName or "?", tier=r.RarityNumber or 0 }
                rarityOf[tostring(k)] = info
                if e.Name then rarityOf[tostring(e.Name)] = info end
            end
        end
    end
end)
local function rarityFor(cat) return rarityOf[tostring(cat)] or {name="?",tier=0} end

-- ============================================================
-- BYPASS ObbyAntiTP (port monthonsova SpeedBypass) + NOCLIP
-- ============================================================
local MARK={"ObbyAntiTP","ObbyAntiTp"}; local NEU={check=true,lagback=true,punish=true,kill=true}
local function srcAnti(s) if type(s)~="string" then return false end for _,m in ipairs(MARK) do if s:find(m,1,true) then return true end end return false end
local metaHook,oldNC,disC,hookF=false,nil,{},{}
ENV.SAE_BLOCK_PIVOT=true
local function destroyAnti(root) if not root then return end for _,i in ipairs(root:GetDescendants()) do if i.Name=="ObbyAntiTPClient" and i:IsA("LocalScript") then pcall(function() i.Disabled=true i:Destroy() end) end end end
local function installHook()
    if metaHook or typeof(getrawmetatable)~="function" then return end
    local ok,mt=pcall(getrawmetatable,game); if not ok or not mt or typeof(mt.__namecall)~="function" then return end
    oldNC=mt.__namecall; pcall(setreadonly,mt,false)
    mt.__namecall=function(self,...) if getnamecallmethod()=="PivotTo" and ENV.SAE_BLOCK_PIVOT and (self==player.Character or self==hrp()) then return self end return oldNC(self,...) end
    pcall(setreadonly,mt,true); metaHook=true
end
local function neuter() if typeof(getgc)~="function" or typeof(hookfunction)~="function" then return end pcall(function() for _,fn in ipairs(getgc(true)) do if type(fn)=="function" and not hookF[fn] then local a,n=pcall(debug.info,fn,"n") local b,s=pcall(debug.info,fn,"s") if a and NEU[n] and b and srcAnti(s) then hookF[fn]=hookfunction(fn,function() return nil end) end end end end) end
local function discSig() if typeof(getconnections)~="function" then return end for _,sig in ipairs({RunService.Heartbeat,RunService.Stepped}) do pcall(function() for _,c in ipairs(getconnections(sig)) do local f=c.Function if f then local ok,s=pcall(debug.info,f,"s") if ok and srcAnti(s) and not disC[c] then pcall(function() c:Disable() end) disC[c]=true end end end end) end end
local function applyBypass()
    pcall(function() Workspace:SetAttribute("ClientObbyAntiTp",false) end)
    installHook(); neuter(); discSig()
    destroyAnti(player:FindFirstChild("PlayerScripts")); destroyAnti(player.Character)
end
-- ============================================================
-- ⭐ FLIGHT CONTROLLER (ลูปเดียว คุมตำแหน่งทั้งหมด)
--   • set CFrame ทุกเฟรมไปหา MOVE_GOAL (ลื่น เร็วจริง FLY_SPEED)
--   • ถือ CFrame แม้ตอนนิ่ง = ไม่ร่วงตกแมพ (ไม่ต้อง anchor)
--   • noclip (ทะลุ ไม่สะดุดรั้ว) — ❌ ไม่ anchor (anchor ทำ server รีตำแหน่ง=หยุด/สะดุด)
--   สั่งบิน: ตั้งค่า MOVE_GOAL (flyTo ทำให้)
-- ============================================================
local MOVE_GOAL=nil     -- Vector3 เป้าหมาย (รวม STAND_Y แล้ว); nil = ยึดตำแหน่งปัจจุบัน
ENV.SAE_MOVESAFE=true
task.spawn(function()
    local ST=Enum.HumanoidStateType
    while alive() and ENV.SAE_MOVESAFE do
        local dt=RunService.Heartbeat:Wait()
        local ch=player.Character
        local r=ch and ch:FindFirstChild("HumanoidRootPart")
        local h=ch and ch:FindFirstChildOfClass("Humanoid")
        if r then
            for _,p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end
            end
            if h then pcall(function()
                h:SetStateEnabled(ST.FallingDown,false); h:SetStateEnabled(ST.Ragdoll,false)
                h:SetStateEnabled(ST.PlatformStanding,false); h.PlatformStand=false
            end) end
            if MOVE_GOAL==nil then MOVE_GOAL=r.Position end
            local cur=r.Position
            local d=(MOVE_GOAL-cur).Magnitude
            local np
            if d<=CFG.FLY_SPEED*dt or d<1 then np=MOVE_GOAL
            else np=cur+(MOVE_GOAL-cur).Unit*(CFG.FLY_SPEED*dt) end
            pcall(function() r.CFrame=CFrame.new(np) end)   -- ทุกเฟรม = ลื่น + ไม่ร่วง
        end
    end
end)
ENV.SAE_UNSAFE=function() ENV.SAE_MOVESAFE=false end   -- คืนสภาพ (เดินเองได้)

-- flyTo(pos): ตั้งเป้า แล้วรอจนถึง
local function flyTo(pos)
    MOVE_GOAL=Vector3.new(pos.X, pos.Y+CFG.STAND_Y, pos.Z)
    local dl=os.clock()+20
    while alive() do
        local r=hrp(); if not r then return false end
        if (MOVE_GOAL-r.Position).Magnitude<3 then return true end
        if os.clock()>dl then return false end
        RunService.Heartbeat:Wait()
    end
    return false
end
local function flyHighTo(pos) return flyTo(pos) end   -- เลิกบินสูง (ยามจับ XZ ไม่สน Y)

-- ยิง prompt เก็บ (เฉพาะใกล้ไข่)
local function firePrompts(pos)
    if typeof(fireproximityprompt)~="function" then return end
    for _,c in ipairs(Workspace:GetChildren()) do
        if c.Name=="SmartPromptPart" and c:IsA("BasePart") and (c.Position-pos).Magnitude<=22 then
            for _,p in ipairs(c:GetChildren()) do if p:IsA("ProximityPrompt") then pcall(function() p.Enabled=true p.HoldDuration=0 p.MaxActivationDistance=math.max(p.MaxActivationDistance or 0,60) p.RequiresLineOfSight=false fireproximityprompt(p) end) end end
        end
    end
end

-- ============================================================
-- EGGS + carry state
-- ============================================================
local function slotKey(rec) if type(rec.Uid)=="string" and rec.Uid:find("FirstAreaEgg",1,true) then return tostring(rec.AreaId)..":"..tostring(rec.NestId) end return nil end
local function getEggs()
    if not SNAP then return {} end
    local ok,snap=pcall(function() return SNAP:InvokeServer() end)
    if not ok or type(snap)~="table" or type(snap.Records)~="table" then return {} end
    local myPos=(hrp() and hrp().Position) or Vector3.new()
    local out={}
    for _,rec in pairs(snap.Records) do
        if type(rec)=="table" and rec.Uid then
            local pos=(typeof(rec.BoundsCFrame)=="CFrame") and rec.BoundsCFrame.Position or myPos
            local rr=rarityFor(rec.AssetCategory)
            out[#out+1]={rec=rec,uid=rec.Uid,pos=pos,area=tostring(rec.AreaId),cat=tostring(rec.AssetCategory),rarity=rr.name,tier=rr.tier,slotKey=slotKey(rec),dist=(pos-myPos).Magnitude}
        end
    end
    table.sort(out,function(a,b) if a.tier~=b.tier then return a.tier>b.tier end return a.dist<b.dist end)
    return out
end
local function wantEgg(e)
    if CFG.MIN_TIER>0 and e.tier<CFG.MIN_TIER then return false end
    local w=(CFG.RARITY or ""):lower()
    if w=="" then return true end
    for name in w:gmatch("[^,]+") do if e.rarity:lower()==name:gsub("%s","") then return true end end
    return false
end
local function pickTargets() local o={} for _,e in ipairs(getEggs()) do if wantEgg(e) then o[#o+1]=e end end return o end

local carrying,carryUid=false,nil
pcall(function() if EggState and EggState.CarryChanged and EggState.CarryChanged.Connect then EggState.CarryChanged:Connect(function(cs) carrying=(cs and cs.IsCarrying)==true carryUid=cs and cs.Uid end) end end)

local HOME
-- ยิงเก็บ 1 ครั้ง (กด E + CarryFieldEgg)
local function tryGrab(e)
    pcall(function() if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(e.uid,e.slotKey) end end)
    firePrompts(e.pos)
end
-- ============================================================
-- เก็บไข่ 1 ลูก: บินไป → กด E ให้ติดไว → "ไข่ติ๊ดเดียว ออกทันที" → ฝาก
--   ★ ห้ามยืนแช่ตรงไข่ (ยืนแช่ = guard ตีโดน/desync/เฟล)
-- ============================================================
local function carryOne(e)
    -- ถ้ายังถือไข่ค้างอยู่ เอาไปฝากก่อน
    if carrying and HOME then
        flyTo(HOME)
        local t=os.clock(); while alive() and carrying and os.clock()-t<CFG.DEPOSIT_T do task.wait(0.1) end
    end

    -- ★ DRIVE-BY: ตั้งเป้าไปไข่ (controller บินให้) + กด E ทุกเฟรม (ไม่หยุดยืน)
    --   ยามตื่นช้า 0.63 วิ หลังขโมยสำเร็จ → ติดปุ๊บ controller พาหนีทันที
    MOVE_GOAL=Vector3.new(e.pos.X, e.pos.Y+CFG.STAND_Y, e.pos.Z)
    local t0=os.clock()
    while alive() and not carrying and os.clock()-t0<CFG.COLLECT_T do
        tryGrab(e)                       -- กด E ทุกเฟรม (controller บินเข้าหาไข่ให้เอง)
        RunService.Heartbeat:Wait()
    end
    if not carrying then return false end   -- เก็บไม่ติดในเวลา → ข้ามลูกนี้

    -- ★ ไข่ติดแล้ว → หนีกลับ safe zone "ทันที" ความเร็ว 500 (ยามไล่สุด ~120 ตามไม่ทัน)
    if HOME then
        flyTo(HOME)
        local t=os.clock(); while alive() and carrying and os.clock()-t<CFG.DEPOSIT_T do task.wait(0.1) end
    end
    return not carrying
end

-- ============================================================
-- COMMANDS
-- ============================================================
ENV.SAE_SETHOME=function() local r=hrp() if not r then log("ไม่มีตัว") return end HOME=r.Position log("✅ จำ SAFE ZONE = "..tostring(r.Position).." (ยืนกลางโซนตอนเรียกนะ)") end
ENV.SAE_TIER=function(n) CFG.RARITY=tostring(n or "") log("ระดับ = "..(CFG.RARITY==""and"ทุกระดับ"or CFG.RARITY)) end
ENV.SAE_LIST=function() local eggs=getEggs() log("ไข่ = "..#eggs.." (หายากก่อน)") for i=1,math.min(15,#eggs) do local e=eggs[i] log(("  #%d [%s] %s | %s(t%d) dist=%d"):format(i,e.area,e.cat,e.rarity,e.tier,e.dist)) end end
ENV.SAE_TAP=function(n) n=tonumber(n) or 1 local e=pickTargets()[n] if not e then log("ไม่มีไข่(ตามตัวกรอง)") return end log(("เก็บ #%d [%s] %s %s"):format(n,e.area,e.cat,e.rarity)) local ok=carryOne(e) log(ok and "✅ ได้ไข่+ฝากแล้ว!" or "⚠️ ไม่สำเร็จ (เก็บไม่ติด/ฝากไม่ผ่าน)") end
ENV.SAE_STEAL=function()
    if not (SNAP and EggState) then log("❌ โมดูลไม่ครบ") return end
    if not HOME then log("⚠️ ยัง SAE_SETHOME() (ยืนกลาง SAFE ZONE)") return end
    ENV.SAE_RUNNING=true; log("▶️ STEAL เริ่ม! (ระดับ:"..(CFG.RARITY==""and"ทุก"or CFG.RARITY)..") หยุด SAE_STOP()")
    task.spawn(function()
        while alive() and ENV.SAE_RUNNING do
            applyBypass()
            local eggs=pickTargets()
            if #eggs==0 then task.wait(2)
            else local got=0 for _,e in ipairs(eggs) do if not(alive() and ENV.SAE_RUNNING) then break end if carryOne(e) then got=got+1 end task.wait(CFG.LOOP_GAP) end log("รอบนี้ได้ "..got) end
        end
        log("⏹️ หยุด")
    end)
end
ENV.SAE_STOP=function() ENV.SAE_RUNNING=false if ENV.SAE_UNSAFE then ENV.SAE_UNSAFE() end log("หยุด (คืน anchor แล้ว เดินเองได้)") end

applyBypass()
player.CharacterAdded:Connect(function() task.wait(0.6) if alive() then applyBypass() end end)
task.spawn(function() while alive() do task.wait(3) pcall(applyBypass) end end)

log("โหลดแล้ว ✅ v"..SCRIPT_VERSION.." EggState="..(EggState and"✅"or"❌").." Snapshot="..(SNAP and"✅"or"❌"))
log("⭐ บินสูงข้าม guard (FLY_HEIGHT=70) เก็บไข่ระดับสูงโซนไกลได้")
log("SAE_SETHOME()(กลาง SAFE ZONE) → SAE_TIER('Mythic') → SAE_TAP(1) → SAE_STEAL()")
