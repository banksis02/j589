-- ============================================================
-- STEAL AN EGG — OBSERVER (ดูว่าสคริปที่ "ใช้ได้แต่ล็อกโค้ด" ทำงานยังไง)
-- อ่านอย่างเดียว ไม่ hook = ปลอดภัย. จับพฤติกรรม: ขยับด้วยอะไร/ปิด AntiTP ไหม/clone humanoid ไหม
-- วิธีใช้: รันสคริปที่ใช้ได้ของคุณก่อน → เปิด auto steal/teleport → รัน observer นี้ → ปล่อยมันฟาม 1-2 รอบ → SAE_OBSTOP()
-- ============================================================
local Players    = game:GetService("Players")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G

local logs={}
local function push(l) logs[#logs+1]=l; print(l) end
local function save()
    local t=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_observe.txt",t) end
end
local function ch() return player.Character end
local function hrp() local c=ch() return c and c:FindFirstChild("HumanoidRootPart") end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end

push("════════ OBSERVER เปิด — เก็บพฤติกรรมสคริปที่ใช้ได้ ════════")
push("time="..os.date("%H:%M:%S"))

-- สถานะเริ่มต้น
do
    local ps=player:FindFirstChild("PlayerScripts")
    local anti = ps and ps:FindFirstChild("Game") and ps.Game:FindFirstChild("ObbyAntiTP")
    local antiClient
    if ps then for _,d in ipairs(ps:GetDescendants()) do if d.Name=="ObbyAntiTPClient" then antiClient=d break end end end
    push("ObbyAntiTPClient (ใน PlayerScripts) = "..(antiClient and ("มีอยู่ Disabled="..tostring(antiClient.Disabled)) or "❌ ถูกลบ/ไม่มี (=สคริปปิดมันแล้ว)"))
    push("Workspace.ClientObbyAntiTp attr = "..tostring(WS:GetAttribute("ClientObbyAntiTp")))
end

ENV.SAE_OBS=true
local BODYMOVERS={"BodyVelocity","LinearVelocity","AlignPosition","BodyPosition","VectorForce","BodyGyro","AlignOrientation","BodyThrust"}
local seenMover, lastWS, lastPos, lastAnchored, lastHumCount, maxJump = {}, nil, nil, nil, nil, 0
local samples, moverFrames, teleportFrames = 0, 0, 0

task.spawn(function()
    while ENV.SAE_OBS do
        local c=ch(); local h=hrp()
        local hu=c and c:FindFirstChildOfClass("Humanoid")
        if c and h then
            samples=samples+1
            -- 1) BodyMover ที่ script ใส่ไว้บนตัว
            local activeMovers={}
            for _,d in ipairs(c:GetDescendants()) do
                for _,cls in ipairs(BODYMOVERS) do
                    if d:IsA(cls) then
                        activeMovers[#activeMovers+1]=cls.."("..d.Name..")"
                        if not seenMover[d] then
                            seenMover[d]=true
                            local extra=""
                            pcall(function() if d:IsA("BodyVelocity") then extra=" Vel="..P(d.Velocity).." MaxF="..tostring(d.MaxForce.X)
                                elseif d:IsA("LinearVelocity") then extra=" VecVel="..P(d.VectorVelocity)
                                elseif d:IsA("AlignPosition") then extra=" Pos="..P(d.Position).." maxF="..tostring(d.MaxForce) end end)
                            push(("⚙️ พบ MOVER ใหม่: %s บน %s%s"):format(cls, d.Parent and d.Parent.Name or "?", extra))
                        end
                    end
                end
            end
            if #activeMovers>0 then moverFrames=moverFrames+1 end
            -- 2) WalkSpeed เปลี่ยน
            if hu then
                local ws=hu.WalkSpeed
                if lastWS~=nil and math.abs(ws-lastWS)>1 then push(("🏃 WalkSpeed: %.0f → %.0f"):format(lastWS, ws)) end
                lastWS=ws
            end
            -- 3) anchored เปลี่ยน
            if lastAnchored~=nil and h.Anchored~=lastAnchored then push("⚓ HRP.Anchored → "..tostring(h.Anchored)) end
            lastAnchored=h.Anchored
            -- 4) teleport (กระโดดไกลใน 1 เฟรม) vs velocity ลื่น
            if lastPos then
                local jump=(h.Position-lastPos).Magnitude
                if jump>maxJump then maxJump=jump end
                if jump>60 then teleportFrames=teleportFrames+1; if teleportFrames<=6 then push(("⚡ TELEPORT! กระโดด %.0f studs ใน 1 tick (movers=%s)"):format(jump, #activeMovers>0 and table.concat(activeMovers,",") or "ไม่มี")) end end
            end
            lastPos=h.Position
            -- 5) humanoid clone (มี Humanoid เกิน 1)
            local hc=0 for _,d in ipairs(c:GetChildren()) do if d:IsA("Humanoid") then hc=hc+1 end end
            if lastHumCount~=nil and hc~=lastHumCount then push("🧬 จำนวน Humanoid ในตัว = "..hc.." (clone trick?)") end
            lastHumCount=hc
        end
        task.wait(0.1)
    end
end)

function SAE_OBSTOP()
    ENV.SAE_OBS=false
    task.wait(0.2)
    push("\n════════ สรุปพฤติกรรม ════════")
    push("samples="..samples.." | เฟรมที่มี BodyMover="..moverFrames.." | เฟรม teleport(>60)="..teleportFrames)
    push("กระโดดไกลสุดใน 1 tick = "..math.floor(maxJump).." studs")
    push("WalkSpeed ล่าสุด = "..tostring(lastWS))
    push("→ วิเคราะห์:")
    if moverFrames>samples*0.3 then push("  ✅ ใช้ BodyMover (velocity flight) เป็นหลัก")
    elseif teleportFrames>0 then push("  ✅ ใช้ TELEPORT (CFrame กระโดด) — maxJump "..math.floor(maxJump))
    elseif lastWS and lastWS>30 then push("  ✅ ใช้ WalkSpeed boost เดินเร็ว")
    else push("  ? ขยับแบบปกติ/tween (ไม่เจอ mover/teleport ชัด)") end
    save()
    push("🛑 STOP — copy แล้ว วางมาให้เลย")
end
pcall(function() _G.SAE_OBSTOP=SAE_OBSTOP; ENV.SAE_OBSTOP=SAE_OBSTOP end)
save()
push("▶️ กำลังดู... ปล่อยสคริปที่ใช้ได้ฟาม 1-2 รอบ (วาปเก็บไข่) แล้วพิมพ์ SAE_OBSTOP()")
