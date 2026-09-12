-- ============================================================
-- STEAL AN EGG — "ขี่ยังไง" PROBE (หา HOW ที่สคริปจริงทำให้ carrier ride server-sync)
-- ★ ไม่ hook / ไม่ยิง remote → สคริปจริงทำงานปกติ
-- ตอบ 3 ข้อ: (1) TeleguiadoGuard สร้างเอง/มีอยู่แล้ว (2) เรานั่ง Seat ไหม (3) ขยับด้วยอะไร (velocity/remote)
-- ใช้: รัน probe นี้ก่อน → รันสคริปจริง → เก็บไข่+ขี่กลับ 1 รอบ → SAE_HOW_STOP() → วาง log
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G

local logs={}; local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function push(l) logs[#logs+1]=l; print("[HOW] "..l) end
local function save() local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_ride_how.txt",txt) end end
local function V(v) return v and ("(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z) or "?" end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end

-- (1) TeleguiadoGuard สร้างเอง? — เช็คว่ามีอยู่ก่อนแล้วไหม + ดักตอนถูกสร้าง
local existsAtStart = WS:FindFirstChild("TeleguiadoGuard")~=nil
push("════ HOW PROBE ════")
push("(1) TeleguiadoGuard มีอยู่ตอนเริ่ม (ก่อนรันสคริปจริง)? = "..tostring(existsAtStart)
    .."  → ถ้า false แล้วเดี๋ยวมันโผล่ = สคริปสร้างเอง; ถ้า true = มีในเกมอยู่แล้ว(server รู้จัก)")
save()
local addConn
addConn=WS.ChildAdded:Connect(function(c)
    if c.Name=="TeleguiadoGuard" or (c:IsA("Model") and c:FindFirstChild("RootPart")) then
        push(("[%s] ★ Workspace.ChildAdded: %s (ClassName=%s) = สคริปสร้าง/spawn ตอนนี้"):format(T(), c.Name, c.ClassName))
        save()
    end
end)

-- ดัมพ์โครงสร้าง carrier แบบเจาะ mover/seat
local function deepDump(model)
    if not model then return end
    push("─── DUMP "..model:GetFullName().." ───")
    local seat, movers = {}, {}
    for _,d in ipairs(model:GetDescendants()) do
        local cn=d.ClassName
        if cn=="Seat" or cn=="VehicleSeat" then seat[#seat+1]=d:GetFullName() end
        if cn=="BodyVelocity" or cn=="BodyPosition" or cn=="BodyGyro" or cn=="LinearVelocity"
           or cn=="AlignPosition" or cn=="AlignOrientation" or cn=="VectorForce" or cn=="AngularVelocity"
           or cn=="BodyMover" or cn=="Motor6D" or cn=="Weld" then movers[#movers+1]=cn.."@"..d.Name end
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then push("   script: "..cn.." '"..d.Name.."'") end
    end
    push("   Seat/VehicleSeat: "..(#seat>0 and table.concat(seat,", ") or "❌ ไม่มี"))
    push("   Movers (BodyVelocity/Align/Weld/etc): "..(#movers>0 and table.concat(movers,", ") or "❌ ไม่มี"))
    local root=model:FindFirstChild("RootPart") or model.PrimaryPart
    if root then push("   RootPart: Anchored="..tostring(root.Anchored).." NetworkOwner(client อ่านได้ไหม)="..(function()
        local ok,r=pcall(function() return root:GetNetworkOwner() end); return ok and tostring(r) or "อ่านไม่ได้(server-owned/ไม่มีสิทธิ์)" end)()) end
    save()
end

-- (2)+(3) ตอนขี่: เช็ค Seat / mover / velocity ทุก 0.3s
ENV.SAE_HOW_ON=true
local dumped=false
task.spawn(function()
    while ENV.SAE_HOW_ON do
        local h=hrp(); local hm=hum()
        local tg=WS:FindFirstChild("TeleguiadoGuard")
        if tg and not dumped then dumped=true; deepDump(tg) end
        if h and hm then
            -- (2) นั่ง Seat ไหม
            local sit = hm.Sit
            local seatPart = hm.SeatPart and hm.SeatPart:GetFullName() or "nil"
            -- (3) ขยับด้วยอะไร: velocity ของตัวเรา + ของ carrier + mover ที่ผูกกับตัวเรา
            local myVel=0; pcall(function() myVel=h.AssemblyLinearVelocity.Magnitude end)
            local tgVel=0; if tg then local r=tg:FindFirstChild("RootPart"); if r then pcall(function() tgVel=r.AssemblyLinearVelocity.Magnitude end) end end
            -- mover ที่เกาะตัวเรา (BodyVelocity/Align บน HRP)
            local onMe={}
            for _,d in ipairs((player.Character and player.Character:GetDescendants()) or {}) do
                local cn=d.ClassName
                if cn=="BodyVelocity" or cn=="LinearVelocity" or cn=="AlignPosition" or cn=="BodyPosition" or cn=="VectorForce" then onMe[#onMe+1]=cn end
            end
            if sit or myVel>20 or tg then
                push(("[%s] Sit=%s SeatPart=%s | PlatformStand=%s | เราvel=%.0f carriervel=%.0f | moverบนตัวเรา=[%s] | เรา%s")
                    :format(T(), tostring(sit), seatPart, tostring(hm.PlatformStand), myVel, tgVel,
                    table.concat(onMe,","), V(h.Position)))
                save()
            end
        end
        task.wait(0.3)
    end
end)

function SAE_HOW_STOP()
    ENV.SAE_HOW_ON=false
    if addConn then pcall(function() addConn:Disconnect() end) end
    save(); push("🛑 STOP — copy แล้ว วางมาให้ ("..#logs.." บรรทัด)"); save()
end
pcall(function() ENV.SAE_HOW_STOP=SAE_HOW_STOP; _G.SAE_HOW_STOP=SAE_HOW_STOP end)

push("รันสคริปจริง → เก็บไข่+ขี่กลับ → SAE_HOW_STOP() → วาง log")
push("ดู: (1) ChildAdded TeleguiadoGuard? (2) Sit/SeatPart ตอนขี่? (3) เราvel vs carriervel + mover")
save()
