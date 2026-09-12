-- ============================================================
-- STEAL AN EGG — DEPOSIT SPY (ดักตอน MIRANDA ฝากไข่ไกล — ว่ามันทำไง)
-- ★ passive: connect OnClientEvent + poll เท่านั้น ไม่ hook ไม่ยิง remote = MIRANDA ทำงานปกติ
-- จับ: (1) FieldClaimed/RedeemVerdict ยิงตอนไหน+ไข่อะไร (2) ขากลับ egg sync กับตัวไหม (3) pos/velocity ตอนฝาก
-- ใช้: รัน probe นี้ก่อน → รัน MIRANDA → ให้มันเก็บไข่ไกล+ฝาก 1 รอบ → SAE_DSPY_STOP() → วาง log
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G

local logs={}; local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function push(l) logs[#logs+1]=l; print("[DSPY] "..l) end
local function save() local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_deposit_spy.txt",txt) end end
local function V(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end

-- EggState
local EggState; pcall(function() EggState=require(RS:WaitForChild("Client",8):WaitForChild("EggState",8)) end)
local carrying, carryUid = false, nil

-- (1) จับ deposit สำเร็จ = FieldClaimed (EggState) + RE redeem/shifted events
if EggState then
    pcall(function() if EggState.CarryChanged then EggState.CarryChanged:Connect(function(cs)
        local was=carrying; carrying=(cs and cs.IsCarrying)==true; carryUid=cs and cs.Uid
        local h=hrp()
        if carrying and not was then push(("[%s] ✋ เริ่มอุ้ม uid=%s @%s"):format(T(), tostring(carryUid), V(h and h.Position))) end
        if was and not carrying then push(("[%s] 🔻 หยุดอุ้ม (ฝากสำเร็จ/คืนรัง?) @%s"):format(T(), V(h and h.Position))) end
        save()
    end) end end
    pcall(function() if EggState.FieldClaimed then EggState.FieldClaimed:Connect(function(info)
        local h=hrp()
        push(("[%s] 🎉 FieldClaimed (ฝากจริง!) info=%s @%s vel=%.0f"):format(T(),
            (type(info)=="table" and ((info.DisplayName or "?").." ["..(info.Rarity or "?").."]")) or tostring(info),
            V(h and h.Position), h and h.AssemblyLinearVelocity.Magnitude or -1))
        save()
    end) end end
end
-- RE events (redeem/shifted) — connect ทุกตัวที่ชื่อเกี่ยว
local function connectRE(root)
    if not root then return end
    pcall(function() for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("RemoteEvent") and (d.Name:find("Redeem") or d.Name:find("Claim") or d.Name:find("Shifted") or d.Name:find("FieldEgg")) then
            pcall(function() d.OnClientEvent:Connect(function(...)
                local a={...}; local s={}
                for i=1,math.min(#a,4) do local v=a[i]; s[i]=(typeof(v)=="Instance" and v.Name) or (type(v)=="table" and "table") or tostring(v) end
                push(("[%s] 📩 %s(%s)"):format(T(), d.Name, table.concat(s,","))); save()
            end) end
        end
    end end)
end
connectRE(RS:FindFirstChild("Packages"))
connectRE(RS)

-- หา "ไข่ที่กำลังอุ้ม" ใน Workspace (ตาม carryUid) เพื่อวัด sync กับตัวละคร
local function carriedEggPos()
    if not carryUid then return nil end
    local m=WS:FindFirstChild(tostring(carryUid))
    if m then local ok,p=pcall(function() return (m:IsA("BasePart") and m.Position) or (m.PrimaryPart and m.PrimaryPart.Position) or (m:FindFirstChildWhichIsA("BasePart") and m:FindFirstChildWhichIsA("BasePart").Position) end) if ok then return p end end
    return nil
end

-- (2)(3) poll: ตอนอุ้ม → log pos/velocity ของตัว + ไข่ + ระยะห่าง(sync)
ENV.SAE_DSPY_ON=true
task.spawn(function()
    local last=0
    while ENV.SAE_DSPY_ON do
        local h=hrp()
        if h and carrying then
            if os.clock()-last>0.25 then last=os.clock()
                local vel=0; pcall(function() vel=h.AssemblyLinearVelocity.Magnitude end)
                local ep=carriedEggPos()
                local sync = ep and (ep-h.Position).Magnitude or -1
                push(("[%s] อุ้ม เรา%s vel=%.0f | ไข่%s ห่าง=%.0f"):format(T(), V(h.Position), vel, V(ep), sync))
                save()
            end
        end
        task.wait(0.1)
    end
end)

function SAE_DSPY_STOP()
    ENV.SAE_DSPY_ON=false
    save(); push("🛑 STOP — copy แล้ว วางมาให้ ("..#logs.." บรรทัด)"); save()
end
pcall(function() ENV.SAE_DSPY_STOP=SAE_DSPY_STOP; _G.SAE_DSPY_STOP=SAE_DSPY_STOP end)

push("════ DEPOSIT SPY เปิด (passive ไม่ hook) ════")
push("รัน MIRANDA → เก็บไข่ไกล+ฝาก 1 รอบ → SAE_DSPY_STOP() → วาง log")
push("ดู: 🎉FieldClaimed(ฝากจริง) + ตอนอุ้ม 'ห่าง='(ไข่ sync กับตัวไหม) + vel(ขากลับใช้ velocity?)")
save()
