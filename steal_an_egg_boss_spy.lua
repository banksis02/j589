-- STEAL AN EGG — BOSS SPY (ดักสคริปบอสที่ใช้ได้ ว่าเข้า/ตี ท่าไหนไม่โดนเตะ)
-- ★ passive: LogService + poll เท่านั้น ไม่ hook ไม่ยิง remote = ปลอดภัย (สคริปที่ใช้ได้ทำงานปกติ)
-- ใช้: รัน spy → รันสคริปบอสที่ใช้ได้ → ให้มันเข้า+ตีบอส 1 รอบ → SAE_BSPY_STOP() → วาง log
local Players=game:GetService("Players"); local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService"); local LogService=game:GetService("LogService")
local player=Players.LocalPlayer
local ENV=(type(getgenv)=="function" and getgenv()) or _G
local logs={}; local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function save() local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"boss_spy.txt",txt) end end
local function push(l) logs[#logs+1]=l; print("[BSPY] "..l); save() end
local function V(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function inArena() local h=hrp() return h and h.Position.X<-1000 end
local function heldTool() local c=player.Character if c then for _,it in ipairs(c:GetChildren()) do if it:IsA("Tool") then return it.Name end end end return "-" end
local function bossHP()
    local a=WS:FindFirstChild("BossArena"); local b=a and a:FindFirstChild("Boss")
    if b then for _,d in ipairs(b:GetDescendants()) do if d:IsA("TextLabel") then local c,m=tostring(d.Text):match("([%d,]+)%s*/%s*([%d,]+)") if c then return c.."/"..m end end end end
    return "?"
end

-- LogService (ข้อความเกม)
local lastMsg=""
local KW={"boss","Boss","rift","Rift","arena","Arena","enter","Enter","damage","Damage","crystal","Crystal","reward","Reward","claim"}
pcall(function() LogService.MessageOut:Connect(function(msg)
    if type(msg)~="string" or msg==lastMsg or msg:find("[BSPY]",1,true) then return end
    for _,k in ipairs(KW) do if msg:find(k,1,true) then lastMsg=msg
        push(("[%s] 📜 %s | %s inArena=%s"):format(T(), msg:gsub("^%s+",""):sub(1,90), V(hrp() and hrp().Position), tostring(inArena()))) break end end
end) end)

-- poll: position/weapon/HP (ดู teleport vs เดิน, ถืออาวุธ, HP ลด)
ENV.SAE_BSPY_ON=true
task.spawn(function()
    local last=0; local lastPos; local wasArena=false
    while ENV.SAE_BSPY_ON do
        local h=hrp()
        if h then
            local moved=lastPos and (h.Position-lastPos).Magnitude or 0
            -- จับตอนเข้า arena (teleport ก้อนใหญ่?)
            if inArena()~=wasArena then wasArena=inArena()
                push(("[%s] ★ %s arena! pos=%s Δ%.0f (Δใหญ่=teleport/Δเล็ก=เดิน) ถือ=%s"):format(T(), wasArena and "เข้า" or "ออก", V(h.Position), moved, heldTool())) end
            if os.clock()-last>0.4 and (moved>3 or inArena()) then last=os.clock()
                push(("[%s] %s Δ%.0f ถือ=%s bossHP=%s"):format(T(), V(h.Position), moved, heldTool(), bossHP())) end
            lastPos=h.Position
        end
        task.wait(0.1)
    end
end)
function SAE_BSPY_STOP() ENV.SAE_BSPY_ON=false save() push("🛑 STOP ("..#logs.." บรรทัด) วาง log มา") end
pcall(function() ENV.SAE_BSPY_STOP=SAE_BSPY_STOP; _G.SAE_BSPY_STOP=SAE_BSPY_STOP end)
push("════ BOSS SPY (passive) ════ รันสคริปบอสที่ใช้ได้ → เข้า+ตีบอส → SAE_BSPY_STOP()")
push("ดู: เข้า arena Δใหญ่(teleport)/เล็ก(เดิน) + ถืออาวุธอะไร + bossHP ลดยังไง + 📜 log เกม")
