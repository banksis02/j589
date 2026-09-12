-- ============================================================
-- STEAL AN EGG — PLACE TEST (เทส remote ฝากตรง RF/EggWorld/AskPlaceEgg)
-- จาก chaocauminhlason: ฝากไข่ = ยิง AskPlaceEgg({LocalCFrame=CFrame.new(0,0,0), Uid=eggUid})
-- ★ standalone ไม่ยุ่ง MON_lean — เทสว่า remote นี้วางไข่ลงฐาน(ฝาก)ได้จริงไหม
--
-- วิธีใช้:
--   1) รันตัวนี้
--   2) ★ ถือไข่อยู่ในมือก่อน (เก็บไข่มาถือ) — ตัวไหนก็ได้ ใกล้ก็ได้
--   3) พิมพ์ SAE_PLACE()  → ดูว่าไข่ลงฐาน(ฝาก)ไหม
--   SAE_HELD() = ดูว่าตอนนี้ถือไข่อะไร (Uid)
-- ============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local ENV = (type(getgenv)=="function" and getgenv()) or _G
local function log(t) print("[PLACE] "..tostring(t)) end

local NET = RS:FindFirstChild("Packages"); NET = NET and NET:FindFirstChild("Networking")
local AskPlaceEgg = NET and NET:FindFirstChild("RF/EggWorld/AskPlaceEgg")
log("AskPlaceEgg remote = "..(AskPlaceEgg and "✅ เจอ" or "❌ ไม่เจอ (path อาจต่าง)"))

-- หาไข่ที่ถืออยู่ (Tool ในตัว/backpack ที่มี attribute UID หรือชื่อมี egg)
local function heldEggs()
    local out={}
    for _,src in ipairs({player.Character, player:FindFirstChild("Backpack")}) do
        if src then for _,it in ipairs(src:GetChildren()) do
            if it:IsA("Tool") then
                local uid = it:GetAttribute("UID") or it:GetAttribute("Uid")
                local itype = it:GetAttribute("ItemType")
                if uid or itype=="AssetEgg" or it.Name:lower():find("egg") then
                    out[#out+1]={tool=it, uid=uid, name=it.Name, itype=itype}
                end
            end
        end end
    end
    return out
end

ENV.SAE_HELD=function()
    local e=heldEggs()
    log("ถืออยู่ "..#e.." ชิ้น:")
    for i,x in ipairs(e) do log(("  #%d %s | Uid=%s ItemType=%s"):format(i, x.name, tostring(x.uid), tostring(x.itype))) end
    if #e==0 then log("  (ไม่ได้ถือไข่ — เก็บไข่มาถือก่อนแล้ว SAE_PLACE())") end
end

ENV.SAE_PLACE=function()
    if not AskPlaceEgg then log("❌ ไม่เจอ remote AskPlaceEgg") return end
    local e=heldEggs()
    if #e==0 then log("❌ ไม่ได้ถือไข่ — เก็บไข่มาถือก่อน") return end
    for _,x in ipairs(e) do
        local uid = x.uid
        if uid then
            log(("→ ยิง AskPlaceEgg: %s Uid=%s"):format(x.name, tostring(uid)))
            local ok, ret = pcall(function() return AskPlaceEgg:InvokeServer({ LocalCFrame = CFrame.new(0,0,0), Uid = uid }) end)
            log("   ผล: ok="..tostring(ok).." ret="..tostring(ret))
        else
            log("⚠️ "..x.name.." ไม่มี attribute UID — ลองยิงด้วยชื่อแทน")
            local ok, ret = pcall(function() return AskPlaceEgg:InvokeServer({ LocalCFrame = CFrame.new(0,0,0), Uid = x.name }) end)
            log("   ผล(ชื่อ): ok="..tostring(ok).." ret="..tostring(ret))
        end
    end
    task.wait(0.5)
    log("เช็ค: ยังถือไข่อยู่ไหม? → "..(#heldEggs().." ชิ้น (ถ้า 0 = ฝากลงฐานแล้ว!)"))
end

pcall(function() for _,n in ipairs({"SAE_HELD","SAE_PLACE"}) do _G[n]=ENV[n] end end)
log("✅ พร้อม — ถือไข่ก่อน → SAE_HELD() ดูว่าถืออะไร → SAE_PLACE() ฝาก")
