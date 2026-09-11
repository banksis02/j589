-- ============================================================
-- STEAL AN EGG — DELIVERY MONITOR (ไม่ hook = ไม่กวนการเก็บ)
-- ฟัง server→client events: รู้ว่าฝากสำเร็จ/ล้มเหลว + เหตุผล + เวลาจาก pickup
-- รันทับฟามได้เลย ปล่อยหลายรอบ (สำเร็จ+fail) → SAE_MSTOP()
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local logs, conns = {}, {}
local pickupAt, pickupPos = nil, nil

local function ppos() local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") if h then local p=h.Position return ("(%.0f,%.0f,%.0f)"):format(p.X,p.Y,p.Z),p end return "?",nil end
local function push(l) logs[#logs+1]=l; print(l) end
local function save()
    local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" then pcall(fn,txt) break end end
    if type(writefile)=="function" then pcall(writefile,"egg_monitor.txt",txt) end
end
local function ser(v)
    local t=typeof(v)
    if t=="Instance" then return "<"..v.ClassName..">"..v.Name
    elseif t=="string" then return string.format("%q",v)
    elseif t=="CFrame" then local p=v.Position return ("CF(%.0f,%.0f,%.0f)"):format(p.X,p.Y,p.Z)
    elseif t=="Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z)
    elseif t=="table" then local p={} for k,vv in pairs(v) do p[#p+1]=tostring(k).."="..ser(vv) end return "{"..table.concat(p,",").."}"
    else return tostring(v) end
end
local function args(...) local a={} for i,v in ipairs({...}) do a[i]=ser(v) end return table.concat(a,", ") end

local NET = RS:FindFirstChild("Packages"); NET = NET and NET:FindFirstChild("Networking")
local function conn(name, label)
    local r = NET and NET:FindFirstChild(name)
    if r and r.OnClientEvent then
        conns[#conns+1] = r.OnClientEvent:Connect(function(...)
            local ps = ppos()
            local dt = pickupAt and string.format(" | หลัง pickup %.1fs", os.clock()-pickupAt) or ""
            push(("⚡ %s(%s)  @%s%s"):format(label, args(...), ps, dt))
            save()
        end)
        return true
    end
    return false
end

-- ★ ดัก "State" ของไข่ที่กำลังอุ้ม (สมอกิ้งกัน: GuardCarried/Dropped = ยามแอบจับ)
local WS = game:GetService("Workspace")
local eggConns, lastState = {}, nil
local function findEggModel(uid)
    uid = tostring(uid)
    local cra = WS:FindFirstChild("ClientRenderedAssets")
    if cra then for _,m in ipairs(cra:GetChildren()) do if tostring(m.Name):find(uid,1,true) then return m end end end
    for _,m in ipairs(WS:GetDescendants()) do
        if m:IsA("Model") and tostring(m.Name):find(uid,1,true) then return m end
    end
    return nil
end
local function watchEgg(uid)
    for _,c in ipairs(eggConns) do pcall(function() c:Disconnect() end) end
    eggConns = {}; lastState = nil
    local m = findEggModel(uid)
    if not m then push("   (หาโมเดลไข่ uid="..tostring(uid).." ไม่เจอ)"); return end
    push("   🔎 ดูไข่: "..m:GetFullName())
    local function dumpAttrs(tag)
        local a = {}
        for k,v in pairs(m:GetAttributes()) do a[#a+1]=k.."="..tostring(v) end
        push(("   [%s] attrs: %s"):format(tag, table.concat(a,", ")))
    end
    dumpAttrs("pickup")
    eggConns[#eggConns+1] = m.AttributeChanged:Connect(function(name)
        local val = m:GetAttribute(name)
        push(("   ⚙️ STATE เปลี่ยน: %s = %s   @%s"):format(name, tostring(val), (ppos())))
        if name=="State" then lastState = tostring(val) end
        save()
    end)
end

-- pickup/deposit จาก EggState (event ไม่ใช่ hook)
pcall(function()
    local ES = require(RS:WaitForChild("Client"):WaitForChild("EggState"))
    if ES.CarryChanged and ES.CarryChanged.Connect then
        conns[#conns+1] = ES.CarryChanged:Connect(function(cs)
            local ps, pv = ppos()
            if cs and cs.IsCarrying then
                pickupAt = os.clock(); pickupPos = pv
                push(("🥚 PICKUP  Uid=%s @%s"):format(tostring(cs.Uid), ps))
                pcall(function() watchEgg(cs.Uid) end)
            else
                local dt = pickupAt and string.format("%.1fs", os.clock()-pickupAt) or "?"
                push(("📦 CARRY-END (ฝากเสร็จ/คืนรัง) @%s | อุ้มนาน %s | State ล่าสุด=%s"):format(ps, dt, tostring(lastState)))
            end
            save()
        end)
    end
end)

-- ผลการฝาก + ข้อความเกม (server→client, ปลอดภัย)
local ok1 = conn("RE/EggWorld/FieldEggRedeemVerdict", "REDEEM-VERDICT(ผลฝาก)")
conn("RE/EggWorld/FieldEggGone", "FieldEggGone")
conn("RE/EggWorld/FieldEggShifted", "FieldEggShifted")
conn("RE/EggWorld/OwnerShifted", "OwnerShifted")
conn("RE/RewardScreen/Show", "RewardScreen")
conn("RE/Toasts/Line", "Toast")
conn("RE/Broadcasts/RaiseNotice", "Broadcast")
conn("RE/Alerts/Raise", "Alert")
conn("RE/Payouts/Shower", "Payout")

push("════════════════════════════════════════")
push("📡 MONITOR เปิด (ไม่ hook) — RedeemVerdict="..(ok1 and "✅ต่อได้" or "❌ไม่เจอ"))
push("ปล่อยฟามเก็บ 3-5 รอบ (ทั้งสำเร็จ+fail) แล้ว SAE_MSTOP()")
push("ดู REDEEM-VERDICT ว่าตอน fail args ต่างจากสำเร็จยังไง + อุ้มนานกี่วิ")
push("════════════════════════════════════════")

function SAE_MSTOP()
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    save()
    push("🛑 STOP — copy แล้ว ("..#logs.." บรรทัด)")
end
