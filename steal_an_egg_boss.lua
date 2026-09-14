-- ============================================================
-- STEAL AN EGG — BOSS (ตีบอส RIFT)
-- recon: เดินชน Workspace.BossArenaTeleport.Hitbox → เข้า arena → Workspace.BossArena.Boss
--   อาวุธ = Katana (Gear) | HP = BossFightUI HealthAmount
-- flow: เข้าประตู → ถือ Katana → เข้าหาบอส → ฟัน(Activate)จนตาย → ออก
-- cmd: SAE_BOSS_GO() ไปตีบอส | SAE_BOSS_STOP() | SAE_BOSS_STATUS()
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[BOSS] "..tostring(t)) end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

_G.SAE_BOSS_GEN=(_G.SAE_BOSS_GEN or 0)+1
local GEN=_G.SAE_BOSS_GEN
local function alive() return GEN==_G.SAE_BOSS_GEN end
local CFG={ MELEE=8, ATTACK_GAP=0.15, ARRIVE=6 }

-- remote เข้าห้องบอส (ยิงเข้าตรงๆ ไม่ต้องเดินไปประตู)
local RS=game:GetService("ReplicatedStorage")
local NET=RS:FindFirstChild("Packages"); NET=NET and NET:FindFirstChild("Networking")
local AskEnter=NET and NET:FindFirstChild("RF/BossEvent/AskEnter")
local ReqTP   =NET and NET:FindFirstChild("RF/MonsterEvent/RequestTeleport")
local function enterRemote()
    -- ลอง AskEnter (ไม่มี arg → มี arg) แล้ว RequestTeleport
    if AskEnter then
        local ok,r=pcall(function() return AskEnter:InvokeServer() end)
        log("   AskEnter() → ok="..tostring(ok).." r="..tostring(r))
        if ok then return true end
    end
    if ReqTP then
        local ok,r=pcall(function() return ReqTP:InvokeServer() end)
        log("   RequestTeleport() → ok="..tostring(ok).." r="..tostring(r))
        if ok then return true end
    end
    return false
end

-- ── หา object ──
local function portal() local m=WS:FindFirstChild("BossArenaTeleport") return m end
local function portalHitbox() local m=portal() return m and (m:FindFirstChild("Hitbox") or m:FindFirstChildWhichIsA("BasePart")) end
local function arena() return WS:FindFirstChild("BossArena") end
local function bossModel() local a=arena() return a and a:FindFirstChild("Boss") end
local function bossPos() local b=bossModel() if not b then return nil end return (b.PrimaryPart and b.PrimaryPart.Position) or (b:FindFirstChildWhichIsA("BasePart") and b:FindFirstChildWhichIsA("BasePart").Position) end
local function inArena() local h=hrp() if not h then return false end return h.Position.X < -1000 end  -- arena อยู่ X ~-15000
-- ★ อ่าน HP จาก billboard บน model (หิน "5/5HP" / บอส "3100/7000 HP")
local function modelHP(m)
    if not m then return nil end
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("TextLabel") then
            local cur,max=tostring(d.Text):match("([%d,]+)%s*/%s*([%d,]+)")
            if cur and max then return tonumber((cur:gsub(",",""))), tonumber((max:gsub(",",""))) end
        end
    end
    return nil
end
local function bossHP() return modelHP(bossModel()) end
local function bossActive()  -- บอส/ประตู มีอยู่ไหม
    if portal() then return true end
    local c=bossHP(); return c~=nil
end

-- ── อาวุธ Katana ──
local function findKatana()
    for _,src in ipairs({player.Character, player:FindFirstChild("Backpack")}) do
        if src then for _,it in ipairs(src:GetChildren()) do
            if it:IsA("Tool") and (it.Name:find("Katana") or it.Name:find("Sword") or it:GetAttribute("ItemType")=="Gear") then return it, src end
        end end
    end
end
local function equipKatana()
    local kat=findKatana(); if not kat then return nil end
    if kat.Parent~=player.Character then local h=hum() if h then pcall(function() h:EquipTool(kat) end) end end
    return player.Character:FindFirstChild(kat.Name) or kat
end

-- ── movement (CFrame ตัวจริง — ในบอส arena ไม่มี guard/AC เข้ม) ──
local function moveTo(pos, radius, timeout)
    radius=radius or CFG.ARRIVE; local t=os.clock()
    while alive() and os.clock()-t<(timeout or 12) do
        local h=hrp(); if not h then break end
        local d=(pos-h.Position)
        if d.Magnitude<radius then return true end
        pcall(function() h.CFrame=CFrame.new(h.Position + d.Unit*math.min(12,d.Magnitude)) end)
        RunService.Heartbeat:Wait()
    end
    return false
end

ENV.SAE_BOSS_STATUS=function()
    local c,m=bossHP()
    log(("portal=%s inArena=%s boss=%s HP=%s/%s"):format(tostring(portal()~=nil), tostring(inArena()), tostring(bossModel()~=nil), tostring(c), tostring(m)))
    local k=findKatana(); log("Katana="..(k and "✅ "..k.Name or "❌ ไม่เจอ"))
end

ENV.SAE_BOSS_GO=function()
    if not bossActive() then log("❌ ไม่มีบอส/ประตูตอนนี้ (รอ event บอส spawn)"); return end
    ENV.SAE_BOSS_RUN=true
    task.spawn(function()
        -- ① เข้าประตู (ถ้ายังไม่อยู่ arena)
        if not inArena() then
            log("① เข้าห้องบอส (ยิง remote AskEnter — ไม่ต้องเดินไปประตู)")
            local t=os.clock()
            while alive() and ENV.SAE_BOSS_RUN and not inArena() and os.clock()-t<15 do
                enterRemote()
                local t2=os.clock(); while not inArena() and os.clock()-t2<2 do RunService.Heartbeat:Wait() end
            end
            if not inArena() then log("⚠️ เข้า arena ไม่ได้ (ประตูอาจปิด/ต้องเงื่อนไข)"); ENV.SAE_BOSS_RUN=false; return end
            log("✅ เข้า arena แล้ว @"..P(hrp() and hrp().Position))
        end
        -- ② ถือ Katana
        local kat=equipKatana()
        log(kat and ("② ถือ "..kat.Name) or "② ⚠️ ไม่มี Katana — ตีอาจไม่เข้า")
        local function katana() local k=player.Character and player.Character:FindFirstChildWhichIsA("Tool") return (k and (k.Name:find("Katana") or k:GetAttribute("ItemType")=="Gear")) and k or equipKatana() end
        local function swing() local k=katana() if k and k.Parent==player.Character then pcall(function() k:Activate() end) end end
        local function nearHit(p) -- ขยับเข้าระยะฟัน (CFrame สเต็ป ไม่วาป) + ฟัน
            local h=hrp(); if not h or not p then return end
            local d=(p-h.Position)
            if d.Magnitude>CFG.MELEE then pcall(function() h.CFrame=CFrame.new(h.Position + d.Unit*math.min(20,d.Magnitude) + Vector3.new(0,2,0)) end) end
        end
        -- หิน CrystalTowers
        local function crystals()
            local ct=arena() and arena():FindFirstChild("CrystalTowers"); local o={}
            if ct then for _,c in ipairs(ct:GetChildren()) do if tonumber(c.Name) and c:IsA("Model") then local p=(c.PrimaryPart and c.PrimaryPart.Position) or (c:FindFirstChildWhichIsA("BasePart") and c:FindFirstChildWhichIsA("BasePart").Position) if p then o[#o+1]={m=c,pos=p} end end end end
            return o
        end
        -- ③ loop: มีหิน HP>0 → ตีหินใกล้สุด / หินแตกหมด → ตีบอส (จน HP บอส 0)
        --   (Attacking ไม่ได้บอกล้ม — ใช้ HP หินแทน: หินหมด=บอสล้ม)
        log("③ เริ่มลูป: ตีหิน(HP>0) → หินหมด → ตีบอส")
        local lastLog=0
        while alive() and ENV.SAE_BOSS_RUN and inArena() do
            local bc,bm=bossHP()
            if bc and bc<=0 then log("🎉🎉 บอสตาย! (HP 0)"); break end
            if not bossModel() then log("บอสหาย → จบ"); break end
            -- หาหินที่ยังไม่แตก (HP>0 หรืออ่านไม่ได้) ใกล้สุด
            local target=nil; local h=hrp()
            for _,cr in ipairs(crystals()) do
                if cr.m.Parent then local hc=modelHP(cr.m)
                    if (hc==nil) or (hc>0) then
                        if not target then target=cr elseif h and (cr.pos-h.Position).Magnitude<(target.pos-h.Position).Magnitude then target=cr end
                    end
                end
            end
            if target then nearHit(target.pos); swing()          -- ตีหิน
            else local bp=bossPos(); if bp then nearHit(bp); swing() end end  -- หินหมด → ตีบอส
            if os.clock()-lastLog>3 then lastLog=os.clock()
                log(("   %s | บอสHP=%s/%s"):format(target and "ตีหิน" or "หินหมด→ตีบอส", tostring(bc), tostring(bm))) end
            task.wait(CFG.ATTACK_GAP)
        end
        -- ④ จบ
        local c2,m2=bossHP()
        log(("④ จบรอบบอส (HP=%s/%s)"):format(tostring(c2),tostring(m2)))
        ENV.SAE_BOSS_RUN=false
    end)
end
ENV.SAE_BOSS_STOP=function() ENV.SAE_BOSS_RUN=false log("หยุดตีบอส") end

pcall(function() for _,n in ipairs({"SAE_BOSS_GO","SAE_BOSS_STOP","SAE_BOSS_STATUS"}) do _G[n]=ENV[n] end end)
log("✅ พร้อม — SAE_BOSS_STATUS() เช็ค | SAE_BOSS_GO() เข้าประตู+ตีบอส | SAE_BOSS_STOP()")
