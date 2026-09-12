-- ============================================================
-- STEAL AN EGG — CARRIER PROBE (ล็อกดู "TeleguiadoGuard" ที่สคริปที่ใช้ได้สร้างขี่กลับบ้าน)
-- ★ ไม่ hook / ไม่ยิง remote → สคริปที่ใช้ได้ทำงานปกติ
-- จับ WeldConstraint/Weld ที่ผูกตัวเรากับ carrier → ล็อก carrier → รายงาน:
--   - carrier เป็นอะไร (สร้างเอง/ยามเกม?) parent, ClassName, #children, attributes
--   - ขยับด้วย "ฟิสิกส์" (AssemblyLinearVelocity) หรือ "tween CFrame" (Anchored)?
--   - offset ตัวเรา↔carrier เป๊ะ (หน้า/หลัง/บน) เพื่อ copy ท่า
-- ใช้: รัน probe ก่อน → รันสคริปที่ใช้ได้ → เก็บไข่+ขี่กลับ 1 รอบ → SAE_CP_STOP() → วาง log
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G

local logs={}; local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function push(l) logs[#logs+1]=l; print("[CP] "..l) end
local function save() local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_carrier_probe.txt",txt) end end
local function P(v) return v and ("(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z) or "?" end
local function char() return player.Character end
local function hrp() local c=char() return c and c:FindFirstChild("HumanoidRootPart") end

-- รายงานทุกอย่างของ carrier part ครั้งเดียว (ตอนเจอ)
local function dumpCarrier(part)
    if not part then return end
    local m=part:FindFirstAncestorOfClass("Model") or part.Parent
    push("═══════ พบ CARRIER ═══════")
    push("  Part: "..part:GetFullName())
    push("  ClassName="..part.ClassName.." Anchored="..tostring(part.Anchored).." CanCollide="..tostring(part.CanCollide).." Massless="..tostring(part.Massless))
    push("  Size="..tostring(part.Size).." Transparency="..tostring(part.Transparency))
    if m then
        push("  Model="..m:GetFullName().." ClassName="..m.ClassName)
        local kids={} for _,c in ipairs(m:GetChildren()) do kids[#kids+1]=c.Name.."("..c.ClassName..")" end
        push("  ลูกของ Model ("..#kids.."): "..table.concat(kids,", "))
        local hum=m:FindFirstChildOfClass("Humanoid")
        push("  มี Humanoid? "..(hum and "ใช่ (เหมือนยาม) HP="..tostring(hum.Health) or "ไม่มี (=part เปล่า/สร้างเอง)"))
        local at={} pcall(function() for k,v in pairs(m:GetAttributes()) do at[#at+1]=k.."="..tostring(v) end end)
        push("  attributes: "..(#at>0 and table.concat(at,", ") or "(ไม่มี)"))
        push("  Model อยู่ใน: "..(m.Parent and m.Parent:GetFullName() or "?"))
    end
    save()
end

local carrier=nil
local connChar
local function watchChar(c)
    if not c then return end
    if connChar then pcall(function() connChar:Disconnect() end) end
    connChar=c.DescendantAdded:Connect(function(d)
        if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
            local p0,p1=d.Part0,d.Part1
            local mine=hrp()
            local other=(p0==mine and p1) or (p1==mine and p0) or p1 or p0
            if other and other~=mine then
                push(("[%s] +WELD %s: %s <-> %s"):format(T(), d.ClassName, p0 and p0.Name or "?", p1 and p1.Name or "?"))
                if d:IsA("Weld") then push("   C0="..tostring(d.C0).." C1="..tostring(d.C1)) end
                carrier=other
                dumpCarrier(other)
            end
        end
    end)
end
watchChar(char())
player.CharacterAdded:Connect(function(c) task.wait(0.3); watchChar(c) end)

-- poll: ถ้ามี carrier แล้ว → log offset ตัวเรา↔carrier + carrier ขยับยังไง
ENV.SAE_CP_ON=true
local lastCarPos, lastMyPos
task.spawn(function()
    while ENV.SAE_CP_ON do
        local h=hrp()
        if h and carrier and carrier.Parent then
            local cp=carrier.Position
            local rel=carrier.CFrame:PointToObjectSpace(h.Position)
            local fb = rel.Z<-2 and ("หน้า%.1f"):format(-rel.Z) or (rel.Z>2 and ("หลัง%.1f"):format(rel.Z) or "กลาง")
            local lr = rel.X<-2 and ("ซ้าย%.1f"):format(-rel.X) or (rel.X>2 and ("ขวา%.1f"):format(rel.X) or "-")
            local carMoved=lastCarPos and (cp-lastCarPos).Magnitude or 0
            lastCarPos=cp
            local vel=0 pcall(function() vel=carrier.AssemblyLinearVelocity.Magnitude end)
            local anch=tostring(carrier.Anchored)
            push(("[%s] carrier%s Δ%.0f vel=%.0f anch=%s | เรา%s off[%s %s บน%.1f]")
                :format(T(), P(cp), carMoved, vel, anch, P(h.Position), fb, lr, rel.Y))
            save()
        end
        task.wait(0.2)
    end
end)

function SAE_CP_STOP()
    ENV.SAE_CP_ON=false
    if connChar then pcall(function() connChar:Disconnect() end) connChar=nil end
    save(); push("🛑 STOP — copy แล้ว วางมาให้ ("..#logs.." บรรทัด)"); save()
end
pcall(function() ENV.SAE_CP_STOP=SAE_CP_STOP; _G.SAE_CP_STOP=SAE_CP_STOP end)

push("════════ CARRIER PROBE เปิด (ไม่ hook) ════════")
push("รันสคริปที่ใช้ได้ → เก็บไข่+ขี่กลับ 1 รอบ → SAE_CP_STOP() → วาง log")
push("ดู: dump CARRIER (สร้างเอง/ยาม? Anchored? มี Humanoid?) + carrier vel/Δ (ฟิสิกส์ vs tween) + offset")
save()
