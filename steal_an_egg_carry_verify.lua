-- ============================================================
-- STEAL AN EGG — CARRY VERIFY (เช็คละเอียด: server เห็นเราอุ้มไข่จริงไหม?)
-- อ่านอย่างเดียว ไม่ hook ไม่ยิง remote = ปลอดภัย
-- หลักการ: ไข่จริงเป็น instance ที่ server replicate — ถ้าอุ้มจริง ไข่ต้อง "ตามตัวเรา"
--   • ไข่ตามตัวเรา (ระยะ ~ใกล้) + มี weld/เจ้าของ=เรา  → server เห็นเราอุ้มจริง ✅
--   • ไข่ค้างที่รัง (ระยะไกล/ไม่ขยับ)                    → client คิดไปเอง = DESYNC ❌
-- รัน → ปล่อยฟามเก็บ 1-2 รอบ → SAE_VSTOP() → ก๊อป log มาให้
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local player  = Players.LocalPlayer
local MYID    = player.UserId

local logs, watching = {}, false
local function push(l) logs[#logs+1]=l; print(l) end
local function save()
    local t=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_carry_verify.txt",t) end
end
local function hrp() local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") return h end
local function ppos() local h=hrp() if h then local p=h.Position return ("(%.0f,%.0f,%.0f)"):format(p.X,p.Y,p.Z) end return "?" end

-- หาโมเดลไข่จาก uid (ClientRenderedAssets.<ownerid>_<uid> หรือชื่อมี uid)
local function findEgg(uid)
    uid=tostring(uid)
    for _,root in ipairs({WS:FindFirstChild("ClientRenderedAssets"), WS}) do
        if root then
            for _,m in ipairs(root:GetChildren()) do
                if tostring(m.Name):find(uid,1,true) then return m end
            end
        end
    end
    for _,m in ipairs(WS:GetDescendants()) do
        if (m:IsA("Model") or m:IsA("BasePart")) and tostring(m.Name):find(uid,1,true) then return m end
    end
    return nil
end
local function eggPos(m)
    if m:IsA("Model") then local pp=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart") return pp and pp.Position end
    if m:IsA("BasePart") then return m.Position end
    return nil
end
local function attrsStr(m)
    local a={} for k,v in pairs(m:GetAttributes()) do a[#a+1]=k.."="..tostring(v) end
    table.sort(a) return table.concat(a,", ")
end
-- หา weld ที่ผูกไข่กับตัวเรา (server สร้าง = หลักฐานอุ้มจริง)
local function findWeldToChar(eggModel)
    local ch=player.Character; if not ch then return nil end
    local charParts={} for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then charParts[p]=true end end
    for _,w in ipairs(eggModel:GetDescendants()) do
        if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then
            local ok,p0=pcall(function() return w.Part0 end); local _,p1=pcall(function() return w.Part1 end)
            if (p0 and charParts[p0]) or (p1 and charParts[p1]) then return w end
        end
    end
    -- เช็คฝั่ง character ด้วย (เผื่อ weld อยู่ใต้ตัวละคร)
    for _,w in ipairs(ch:GetDescendants()) do
        if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then
            local _,p0=pcall(function() return w.Part0 end); local _,p1=pcall(function() return w.Part1 end)
            local inEgg=function(x) if not x then return false end for _,e in ipairs(eggModel:GetDescendants()) do if e==x then return true end end return false end
            if inEgg(p0) or inEgg(p1) then return w end
        end
    end
    return nil
end

-- ★ ฟังผลฝากจาก server (RedeemVerdict) — แยกสำเร็จ/เฟล
local redeemAt, redeemInfo = nil, nil
pcall(function()
    local NET=RS:FindFirstChild("Packages"); NET=NET and NET:FindFirstChild("Networking")
    local rv=NET and NET:FindFirstChild("RE/EggWorld/FieldEggRedeemVerdict")
    if rv and rv.OnClientEvent then
        rv.OnClientEvent:Connect(function(info)
            redeemAt=os.clock()
            local d={} if type(info)=="table" then for k,v in pairs(info) do d[#d+1]=tostring(k).."="..tostring(v) end end
            redeemInfo=table.concat(d,", ")
            push("   🎉 REDEEM-VERDICT (ฝากสำเร็จ!): "..redeemInfo.."  @"..ppos())
            save()
        end)
    end
end)
-- lastUid ล่าสุดที่อุ้ม (ไว้เช็คหลังปล่อย)
local lastUid=nil

-- ฟัง CarryChanged (client บอกว่าเริ่ม/เลิกอุ้ม)
pcall(function()
    local ES=require(RS:WaitForChild("Client"):WaitForChild("EggState"))
    if ES.CarryChanged and ES.CarryChanged.Connect then
        ES.CarryChanged:Connect(function(cs)
            if cs and cs.IsCarrying then
                lastUid=cs.Uid
                push("\n════════ 🥚 CLIENT บอกว่าเริ่มอุ้ม uid="..tostring(cs.Uid).." @"..ppos().." ════════")
                local egg=findEgg(cs.Uid)
                if not egg then push("❌ หาโมเดลไข่ไม่เจอ (อาจเป็นชื่ออื่น) — server อาจไม่ได้สร้าง = น่าสงสัย DESYNC"); save(); return end
                push("โมเดลไข่: "..egg:GetFullName())
                push("attrs เริ่มต้น: "..attrsStr(egg))
                -- สุ่มเช็คทุก 0.2 วิ ว่าไข่ตามตัวเราไหม
                watching=true
                task.spawn(function()
                    local mind, maxd, samples, followed = 1e9, 0, 0, 0
                    local t0=os.clock()
                    while watching and os.clock()-t0<30 do
                        if not egg or not egg.Parent then push("   ⚠️ โมเดลไข่หายจาก workspace แล้ว @"..ppos()); break end
                        local ep=eggPos(egg); local h=hrp()
                        if ep and h then
                            local d=(ep-h.Position).Magnitude
                            mind=math.min(mind,d); maxd=math.max(maxd,d); samples=samples+1
                            if d<12 then followed=followed+1 end
                            local w=findWeldToChar(egg)
                            local owner=egg:GetAttribute("OwnerUserId") or egg:GetAttribute("CarrierUserId") or egg:GetAttribute("Owner")
                            push(("   t+%.1fs | ไข่ห่างตัวเรา %.1f studs | เจ้าของ=%s(เรา=%d) | weld=%s | parent=%s | State=%s"):format(
                                os.clock()-t0, d, tostring(owner), MYID,
                                w and ("✅"..w.ClassName) or "❌ไม่มี",
                                tostring(egg.Parent and egg.Parent.Name), tostring(egg:GetAttribute("State"))))
                            save()
                        end
                        task.wait(0.25)
                    end
                    -- สรุป
                    if samples>0 then
                        local pct=math.floor(followed/samples*100)
                        push(("\n   📊 สรุป: ไข่ห่างตัวเรา min=%.1f max=%.1f | ตามตัวเรา(<12)=%d%%"):format(mind,maxd,pct))
                        if pct>=70 then push("   ✅ สรุป: SERVER เห็นเราอุ้มไข่จริง (ไข่ตามตัวเรา)")
                        else push("   ❌ สรุป: DESYNC! ไข่ไม่ตามตัวเรา = server ไม่เห็นเราอุ้ม (client คิดไปเอง)") end
                        save()
                    end
                end)
            else
                watching=false
                local ps=ppos()
                -- ★ ตัดสินผล: ถ้า RedeemVerdict เพิ่งยิง(<2วิ) = สำเร็จ; ไม่งั้น = เฟล(คืนรัง)
                local ok = redeemAt and (os.clock()-redeemAt)<2
                push(("════════ 📦 เลิกอุ้ม @%s → %s ════════"):format(ps,
                    ok and ("✅✅ ฝากสำเร็จ! ("..(redeemInfo or "").." )") or "❌❌ เฟล! (ไม่มี RedeemVerdict = ไข่คืนรัง/โดนแย่ง)"))
                -- เช็คว่าไข่กลับไปไหน (นับจาก lastUid)
                task.spawn(function()
                    task.wait(0.4)
                    if lastUid then
                        local egg=findEgg(lastUid)
                        if egg then
                            local ep=eggPos(egg); local h=hrp()
                            local d=(ep and h) and (ep-h.Position).Magnitude or -1
                            push(("   🔎 หลังปล่อย: ไข่ยังอยู่ %s | ห่างตัวเรา %.0f studs %s"):format(
                                egg:GetFullName(), d, d>50 and "(=ไข่เด้งไปไกล/คืนรัง)" or "(=อยู่แถวนี้)"))
                        else
                            push("   🔎 หลังปล่อย: ไข่หายจาก workspace (=ฝากเข้าระบบแล้ว/หมดอายุ)")
                        end
                        save()
                    end
                end)
                save()
            end
        end)
    else
        push("❌ EggState.CarryChanged ต่อไม่ได้")
    end
end)

push("════════════════════════════════════════")
push("📡 CARRY VERIFY เปิด — ปล่อยฟามเก็บไข่ 1-2 รอบ")
push("ดูบรรทัด 't+..s | ไข่ห่างตัวเรา' : ใกล้(<12)=อุ้มจริง / ไกล=desync")
push("เสร็จ → SAE_VSTOP()")
push("════════════════════════════════════════")
save()

function SAE_VSTOP() watching=false save() push("🛑 STOP — copy แล้ว ("..#logs.." บรรทัด)") end
