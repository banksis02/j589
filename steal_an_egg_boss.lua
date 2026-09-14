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

-- ── หา object ──
local function portal() local m=WS:FindFirstChild("BossArenaTeleport") return m end
local function portalHitbox() local m=portal() return m and (m:FindFirstChild("Hitbox") or m:FindFirstChildWhichIsA("BasePart")) end
local function arena() return WS:FindFirstChild("BossArena") end
local function bossModel() local a=arena() return a and a:FindFirstChild("Boss") end
local function bossPos() local b=bossModel() if not b then return nil end return (b.PrimaryPart and b.PrimaryPart.Position) or (b:FindFirstChildWhichIsA("BasePart") and b:FindFirstChildWhichIsA("BasePart").Position) end
local function inArena() local h=hrp() if not h then return false end return h.Position.X < -1000 end  -- arena อยู่ X ~-15000
-- HP บอสจาก UI
local function bossHP()
    local pg=player:FindFirstChild("PlayerGui"); local ui=pg and pg:FindFirstChild("BossFightUI")
    if ui then local lbl=ui:FindFirstChild("HealthAmount",true) if lbl and lbl:IsA("TextLabel") then
        local cur,max=tostring(lbl.Text):match("(%d+)%s*/%s*(%d+)") return tonumber(cur), tonumber(max) end end
    return nil
end
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
            local hb=portalHitbox()
            if not hb then log("❌ ไม่เจอ Hitbox ประตู"); ENV.SAE_BOSS_RUN=false; return end
            log("① เดินชนประตู @"..P(hb.Position))
            local t=os.clock()
            while alive() and ENV.SAE_BOSS_RUN and not inArena() and os.clock()-t<15 do
                local h=hrp(); if h then pcall(function() h.CFrame=CFrame.new(hb.Position+Vector3.new(0,2,0)) end) end
                task.wait(0.3)
            end
            if not inArena() then log("⚠️ เข้า arena ไม่ได้ (ประตูอาจปิด/ต้องเงื่อนไข)"); ENV.SAE_BOSS_RUN=false; return end
            log("✅ เข้า arena แล้ว @"..P(hrp() and hrp().Position))
        end
        -- ② ถือ Katana
        local kat=equipKatana()
        log(kat and ("② ถือ "..kat.Name) or "② ⚠️ ไม่มี Katana — ตีอาจไม่เข้า")
        -- ③ เข้าหาบอส + ฟัน
        log("③ เข้าหาบอส + ฟัน")
        while alive() and ENV.SAE_BOSS_RUN and inArena() do
            local bp=bossPos()
            if not bp then log("บอสหาย/ตายแล้ว → ออก"); break end
            local h=hrp(); if not h then break end
            -- เข้าใกล้ระยะฟัน
            if (bp-h.Position).Magnitude>CFG.MELEE then
                pcall(function() h.CFrame=CFrame.new(bp + (h.Position-bp).Unit*CFG.MELEE + Vector3.new(0,2,0)) end)
            end
            -- ฟัน (Activate ดาบ)
            if kat and kat.Parent==player.Character then pcall(function() kat:Activate() end) end
            local c=bossHP(); if c and c<=0 then log("🎉 บอสตาย!"); break end
            task.wait(CFG.ATTACK_GAP)
        end
        -- ④ จบ
        local c,m=bossHP()
        log(("④ จบรอบบอส (HP=%s/%s)"):format(tostring(c),tostring(m)))
        ENV.SAE_BOSS_RUN=false
    end)
end
ENV.SAE_BOSS_STOP=function() ENV.SAE_BOSS_RUN=false log("หยุดตีบอส") end

pcall(function() for _,n in ipairs({"SAE_BOSS_GO","SAE_BOSS_STOP","SAE_BOSS_STATUS"}) do _G[n]=ENV[n] end end)
log("✅ พร้อม — SAE_BOSS_STATUS() เช็ค | SAE_BOSS_GO() เข้าประตู+ตีบอส | SAE_BOSS_STOP()")
