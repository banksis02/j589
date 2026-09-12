-- ============================================================
-- STEAL AN EGG — DEPOSIT SPY v2 (ดัก LogService = ข้อความ console เกมทั้งหมด + pos/velocity)
-- ★ passive: LogService.MessageOut + poll เท่านั้น ไม่ hook = MIRANDA ทำงานปกติ
-- จับ "Area egg claim"(=ฝากสำเร็จ) + guard + egg tool + ตำแหน่ง/velocity ตอนนั้น = รู้ว่า MIRANDA ฝากไข่ไกลท่าไหน
-- ใช้: รัน probe → รัน MIRANDA → เก็บไข่ไกล+ฝาก 1 รอบ → SAE_DSPY_STOP() → วาง log
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local LogService=game:GetService("LogService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G

local logs={}; local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function copyAll()
    local txt=table.concat(logs,"\n")
    local done=false
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard,(syn and syn.write_clipboard)}) do
        if type(fn)=="function" and pcall(fn,txt) then done=true; break end
    end
    if type(writefile)=="function" then pcall(writefile,"egg_deposit_spy.txt",txt) end
    return done
end
local function push(l) logs[#logs+1]=l; print("[DSPY] "..l); copyAll() end
local function V(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function state()
    local h=hrp(); if not h then return "?" end
    local vel=0; pcall(function() vel=h.AssemblyLinearVelocity.Magnitude end)
    return ("เรา%s vel=%.0f"):format(V(h.Position), vel)
end

-- (1) ดัก console เกมทั้งหมด — จับคำสำคัญ
local KW={"claim","Claim","egg","Egg","guard","Guard","redeem","Redeem","deposit","Deposit","deliver","carry","Carry","nest","return","Field","Area egg","latency"}
local function want(s) for _,k in ipairs(KW) do if s:find(k,1,true) then return true end end return false end
local lastMsg=""
pcall(function() LogService.MessageOut:Connect(function(msg, mtype)
    if type(msg)~="string" then return end
    if want(msg) and msg~=lastMsg and not msg:find("[DSPY]",1,true) then
        lastMsg=msg
        -- ตัดสั้น + แนบ state ปัจจุบัน
        local short=msg:gsub("^%s+",""):sub(1,120)
        push(("[%s] 📜 %s | %s"):format(T(), short, state()))
    end
end) end)

-- (2) poll: log ตำแหน่ง+velocity เรื่อยๆ (เห็น pattern การขยับ MIRANDA ขากลับ)
ENV.SAE_DSPY_ON=true
task.spawn(function()
    local last=0; local lastPos
    while ENV.SAE_DSPY_ON do
        local h=hrp()
        if h then
            local moved = lastPos and (h.Position-lastPos).Magnitude or 0
            lastPos=h.Position
            if os.clock()-last>0.3 and moved>8 then last=os.clock()   -- log เฉพาะตอนขยับ (>8/tick)
                push(("[%s] ▸ %s Δ%.0f"):format(T(), state(), moved))
            end
        end
        task.wait(0.1)
    end
end)

function SAE_DSPY_STOP()
    ENV.SAE_DSPY_ON=false
    local ok=copyAll()
    push("🛑 STOP — "..#logs.." บรรทัด | clipboard="..(ok and "ก๊อปแล้ว✅" or "❌(อ่านไฟล์ egg_deposit_spy.txt แทน)"))
    copyAll()
end
pcall(function() ENV.SAE_DSPY_STOP=SAE_DSPY_STOP; _G.SAE_DSPY_STOP=SAE_DSPY_STOP end)

push("════ DEPOSIT SPY v2 (ดัก LogService) ════")
push("รัน MIRANDA → เก็บไข่ไกล+ฝาก 1 รอบ → SAE_DSPY_STOP() → วาง log")
push("test state: "..state())
copyAll()
