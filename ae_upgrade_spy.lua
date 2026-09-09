-- ============================================================
-- AE — UPGRADE / PRIORITY SPY (ดักเฉพาะ ReplicaSignal FireServer — hook เบา ไม่แครช)
--   จุดประสงค์: จับ "ชื่อ action + args จริง" ตอนกดอัพเกรด / ปรับ priority
--   วิธีใช้ (ในด่าน):
--     1) รันสคริปต์นี้
--     2) วางยูนิต 1 ตัว → กด Upgrade 2 ครั้ง → เปลี่ยน Priority (เช่น First→Boss)
--     3) กดปุ่ม STOP บนจอ (หรือ _G.SPY_STOP()) → ก๊อป clipboard มาวาง
--   ⚠️ hook เบาแบบเดียวกับตัวอัด (proven): guard self==ReplicaSignal + FireServer ก่อน
--      แล้วค่อยแตะ args — ไม่ pack ทุก namecall (กันแครชแบบ spy รุ่นเก่า)
-- ============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = {}
local logq = {}          -- คิว {a2,a3,a4,a5,a6} จาก hook (serialize นอก hook)
local function add(t) t=tostring(t); out[#out+1]=t; print("[SPY] "..t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn)=="function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile)=="function" then pcall(writefile, "ae_upgrade_spy.txt", text) end
end
local function ser(v, d)
    d=d or 0; local t=typeof(v)
    if t=="Instance" then return "<"..v.ClassName..">"..v.Name
    elseif t=="string" then return string.format("%q",v)
    elseif t=="CFrame" then local p=v.Position return ("CFrame(%.1f,%.1f,%.1f)"):format(p.X,p.Y,p.Z)
    elseif t=="Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z)
    elseif t=="table" then
        if d>=3 then return "{..}" end
        local parts,n={},0
        for k,vv in pairs(v) do n=n+1; if n>30 then parts[#parts+1]="..."; break end
            parts[#parts+1]="["..tostring(k).."]="..ser(vv,d+1) end
        return "{"..table.concat(parts,", ").."}"
    else return t..":"..tostring(v) end
end

-- ── ค้นหา ReplicaSignal ──
local replicaSig
pcall(function()
    replicaSig = RS:WaitForChild("RemoteEvents", 5):WaitForChild("ReplicaSignal", 5)
end)
add("════ UPGRADE/PRIORITY SPY ════  ReplicaSignal="..(replicaSig and "✅" or "❌"))
if not replicaSig then add("❌ ไม่เจอ ReplicaSignal"); save(); return end
if type(hookmetamethod)~="function" then add("❌ executor ไม่มี hookmetamethod"); save(); return end

-- ── snapshot ยูนิตของเรา (ก่อน) เพื่อดู field ที่เปลี่ยนเวลาอัพเกรด/priority ──
local registry
pcall(function()
    local shared = RS:FindFirstChild("Shared")
    local RC = require(shared:FindFirstChild("ReplicaClient"))
    for _, up in pairs(debug.getupvalues(RC.FromId)) do
        if type(up)=="table" then
            for kk in pairs(up) do if type(kk)=="number" then registry=up; break end end
            if registry then break end
        end
    end
end)
local function dumpMyUnits(tag)
    if not registry then return end
    add(""); add("── ยูนิตของเรา ["..tag.."] ──")
    for _, rep in pairs(registry) do
        local ok, tok = pcall(function() return rep.Token end)
        if ok and tok=="GameUnit" then
            local okd, d = pcall(function() return rep.Data end)
            if okd and type(d)=="table" and d.Owner==player then
                local parts={}
                for k,v in pairs(d) do parts[#parts+1]=("[%s]=%s"):format(tostring(k), ser(v)) end
                add("   {"..table.concat(parts, ", ").."}")
            end
        end
    end
end
dumpMyUnits("ก่อนทำ")

-- ── hook เบา ──
local capturing = true
local oldNC
oldNC = hookmetamethod(game, "__namecall", function(self, ...)
    if capturing and self == replicaSig and getnamecallmethod() == "FireServer" then
        local a1, a2, a3, a4, a5, a6 = ...   -- เลือก 6 ตัวแรก (ไม่ pack ทั้งก้อน = เบา)
        logq[#logq+1] = { a1, a2, a3, a4, a5, a6 }
    end
    return oldNC(self, ...)
end)

-- ตัวประมวลผลคิว (serialize นอก hook)
task.spawn(function()
    while capturing do
        task.wait(0.3)
        while #logq > 0 do
            local it = table.remove(logq, 1)
            local parts = {}
            for i = 1, 6 do parts[#parts+1] = ser(it[i]) end
            add("FIRE  "..table.concat(parts, " | "))
        end
    end
end)

-- ── ปุ่ม STOP ──
_G.SPY_STOP = function()
    capturing = false
    task.wait(0.4)
    while #logq > 0 do
        local it = table.remove(logq, 1)
        local parts = {}
        for i = 1, 6 do parts[#parts+1] = ser(it[i]) end
        add("FIRE  "..table.concat(parts, " | "))
    end
    dumpMyUnits("หลังทำ")
    add(""); add("รวม fire = ดูรายการ FIRE ด้านบน (หา action ที่เกี่ยวกับ Upgrade/Priority)")
    save()
    add(">> STOP แล้ว — ก๊อป clipboard มาวางให้เดฟ")
end

pcall(function()
    local old = player.PlayerGui:FindFirstChild("AE_Spy_UI"); if old then old:Destroy() end
end)
local gui = Instance.new("ScreenGui"); gui.Name="AE_Spy_UI"; gui.ResetOnSpawn=false
gui.DisplayOrder=999999; gui.Parent=player.PlayerGui
local b = Instance.new("TextButton", gui)
b.Size=UDim2.new(0,180,0,44); b.Position=UDim2.new(0,210,0.5,60)
b.BackgroundColor3=Color3.fromRGB(180,40,40); b.TextColor3=Color3.fromRGB(255,255,255)
b.Text="⏹ STOP + ก๊อปผล"; b.TextSize=13; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
Instance.new("UICorner", b).CornerRadius=UDim.new(0,6)
b.MouseButton1Click:Connect(function() _G.SPY_STOP() end)

add("")
add(">> พร้อมดัก — วางยูนิต → Upgrade 2 ครั้ง → เปลี่ยน Priority → กด STOP")
