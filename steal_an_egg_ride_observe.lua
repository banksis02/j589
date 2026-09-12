-- ============================================================
-- STEAL AN EGG — RIDE OBSERVER (ดูว่าสคริปที่ใช้ได้ "ขี่ยาม" ยังไง)
-- ★ ไม่ hook / ไม่ยิง remote / ไม่แตะ __namecall → สคริปที่ใช้ได้ทำงานปกติ (ไม่พังเหมือนตัวเก่า)
-- แค่: (1) ฟัง DescendantAdded บนตัวละคร = จับ Weld/Align/BodyMover ที่มันสร้าง
--      (2) poll ทุก 0.2s = ตำแหน่งเรา/ยามใกล้สุด + offset (หน้า/หลัง/บน) + สถานะยาม + Platform/Sit
-- วิธีใช้: รัน observer นี้ก่อน → รันสคริปที่ใช้ได้ → เก็บไข่+ขี่ยาม 1 รอบ → SAE_OBS_STOP() → วาง log
-- ============================================================
local Players = game:GetService("Players")
local WS      = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player  = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G

local logs={}
local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function push(l) logs[#logs+1]=l; print("[OBS] "..l) end
local function save()
    local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_ride_observe.txt",txt) end
end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

local function char() return player.Character end
local function hrp() local c=char() return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char() return c and c:FindFirstChildOfClass("Humanoid") end

-- หายามทั้งหมด (มี Humanoid+HRP) ยกเว้นผู้เล่น
local function allGuards()
    local out={}
    local function scan(root) if not root then return end pcall(function()
        for _,m in ipairs(root:GetDescendants()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                local gh=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                if gh then
                    local isPlayer=false
                    pcall(function() isPlayer = Players:GetPlayerFromCharacter(m)~=nil end)
                    if not isPlayer then out[#out+1]={model=m,root=gh} end
                end
            end
        end
    end) end
    scan(WS:FindFirstChild("_Guards"))
    local a=WS:FindFirstChild("__OBJECTS"); a=a and a:FindFirstChild("Areas"); a=a and a:FindFirstChild("GuardAreas")
    scan(a)
    return out
end
local function nearestGuard()
    local h=hrp(); if not h then return nil end
    local best,bd=nil,1e9
    for _,g in ipairs(allGuards()) do
        local ok,d=pcall(function() return (g.root.Position-h.Position).Magnitude end)
        if ok and d<bd then bd=d; best=g end
    end
    return best,bd
end

-- ───────── (1) จับ Weld/Align/BodyMover ที่สคริปสร้างบนตัวละคร ─────────
local MOVERS={Weld=true,WeldConstraint=true,Motor6D=true,AlignPosition=true,AlignOrientation=true,
    BodyPosition=true,BodyVelocity=true,BodyGyro=true,LinearVelocity=true,AlignOrientation=true,
    VectorForce=true,BodyMover=true,AngularVelocity=true}
local connChar
local function whatIsPart(part)
    if not part then return "nil" end
    local m=part:FindFirstAncestorOfClass("Model")
    local tag = m and (m:GetAttribute("GuardState") and "GUARD:"..m.Name or m.Name) or "?"
    return part.Name.."@"..tag
end
local function watchChar(c)
    if not c then return end
    if connChar then pcall(function() connChar:Disconnect() end) end
    connChar=c.DescendantAdded:Connect(function(d)
        if MOVERS[d.ClassName] then
            local info={d.ClassName.." '"..d.Name.."' parent="..(d.Parent and d.Parent.Name or "?")}
            local ok,s=pcall(function()
                if d:IsA("Weld") or d:IsA("Motor6D") then
                    return " Part0="..whatIsPart(d.Part0).." Part1="..whatIsPart(d.Part1).." C0="..tostring(d.C0)
                elseif d:IsA("WeldConstraint") then
                    return " Part0="..whatIsPart(d.Part0).." Part1="..whatIsPart(d.Part1)
                elseif d.ClassName=="AlignPosition" or d.ClassName=="AlignOrientation" then
                    local a0=d.Attachment0 and d.Attachment0.Parent; local a1=d.Attachment1 and d.Attachment1.Parent
                    return " Att0="..whatIsPart(a0).." Att1="..whatIsPart(a1)..(d.Attachment0 and "" or " Mode="..tostring(d.Mode))
                end
                return ""
            end)
            push(("[%s] +MOVER %s%s"):format(T(), info[1], (ok and s) or ""))
            save()
        end
    end)
    push(("[%s] เฝ้าตัวละคร %s"):format(T(), c.Name))
end
watchChar(char())
player.CharacterAdded:Connect(function(c) task.wait(0.3); watchChar(c) end)

-- ───────── (2) poll สถานะทุก 0.2s ─────────
ENV.SAE_OBS_ON=true
local lastPos, lastLine
task.spawn(function()
    while ENV.SAE_OBS_ON do
        local h=hrp(); local hm=hum()
        if h then
            local g,gd=nearestGuard()
            local rel, offStr = nil, "?"
            if g then
                -- offset ในกรอบ local ของยาม (ยามหันหน้า = -Z) → บอกว่าเราอยู่ หน้า/หลัง/ซ้าย/ขวา/บน
                local ok,r=pcall(function() return g.root.CFrame:PointToObjectSpace(h.Position) end)
                if ok then rel=r
                    local fb = r.Z < -2 and ("หน้า%.0f"):format(-r.Z) or (r.Z>2 and ("หลัง%.0f"):format(r.Z) or "กลาง")
                    local lr = r.X < -2 and ("ซ้าย%.0f"):format(-r.X) or (r.X>2 and ("ขวา%.0f"):format(r.X) or "-")
                    local ud = ("บน%.0f"):format(r.Y)
                    offStr = fb.." "..lr.." "..ud
                end
            end
            -- ระยะขยับ (ตรวจว่ากำลังถูกพา)
            local moved = lastPos and (h.Position-lastPos).Magnitude or 0
            lastPos=h.Position
            local plat = hm and tostring(hm.PlatformStand) or "?"
            local sit  = hm and tostring(hm.Sit) or "?"
            local ws   = hm and ("%.0f"):format(hm.WalkSpeed) or "?"
            local anch = tostring(h.Anchored)
            local gst  = g and (g.model:GetAttribute("GuardState") or "?") or "-"
            local gtp  = g and tostring(g.model:GetAttribute("TargetPlayer") or "") or ""
            local line=("[%s] เรา%s Δ%.0f | ยาม%s d%.0f off[%s] st=%s tgt=%s | Plat=%s Sit=%s WS=%s Anch=%s")
                :format(T(), P(h.Position), moved, g and P(g.root.Position) or "?", gd or -1, offStr, tostring(gst), gtp, plat, sit, ws, anch)
            -- log เฉพาะเมื่อเปลี่ยน (กัน spam) หรือกำลังขยับเยอะ
            if line~=lastLine or moved>3 then push(line); lastLine=line; save() end
        end
        task.wait(0.2)
    end
end)

function SAE_OBS_STOP()
    ENV.SAE_OBS_ON=false
    if connChar then pcall(function() connChar:Disconnect() end) connChar=nil end
    save()
    push("🛑 STOP — copy แล้ว วางมาให้ ("..#logs.." บรรทัด)")
    save()
end
pcall(function() ENV.SAE_OBS_STOP=SAE_OBS_STOP; _G.SAE_OBS_STOP=SAE_OBS_STOP end)

push("════════ RIDE OBSERVER เปิด (ไม่ hook = สคริปที่ใช้ได้ทำงานปกติ) ════════")
push("รันสคริปที่ใช้ได้ → เก็บไข่+ขี่ยาม 1 รอบ → SAE_OBS_STOP() → วาง log")
push("ดู: +MOVER (มันผูก Weld/Align กับยามไหม + offset) และ off[หน้า/หลัง/บน] ตอนขี่")
save()
