-- ============================================================
-- STEAL AN EGG — DEPOSIT PROBE (หาว่า "ฝากไข่" trigger ยังไง + โซนฝากอยู่ไหน)
-- อ่าน/decompile อย่างเดียว ไม่ hook ไม่ยิง remote = ปลอดภัย
-- ตอบ: ทำไมถึงบ้านแล้วไม่ฝาก (standby ผิดจุด? หรือต้อง Touch?)
-- รัน → ก๊อป output มาให้
-- ============================================================

local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local MYID    = player.UserId

local logs={}
local function push(l) logs[#logs+1]=l; print(l) end
local function save()
    local t=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_deposit_probe.txt",t) end
end
local function P(v) if typeof(v)=="Vector3" then return ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) end return tostring(v) end
local function partPos(m)
    if m:IsA("BasePart") then return m.Position end
    if m:IsA("Model") then local pp=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart") return pp and pp.Position end
    return nil
end

local hrpPos do local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") hrpPos=h and h.Position end
push("════════ DEPOSIT PROBE ════════")
push("ตำแหน่งเรา (ยืนตรงนี้ตอนรัน) = "..P(hrpPos))
push("UserId = "..MYID)

-- decompiler
local DEC = (type(decompile)=="function" and decompile) or nil

-- 1) decompile Client.EggState (carry/redeem logic) — หาว่าฝาก trigger ด้วยอะไร
push("\n===== Client.EggState (หา redeem/safe/deposit/touch) =====")
pcall(function()
    local es = RS:FindFirstChild("Client"); es = es and es:FindFirstChild("EggState")
    if not es then push("[ไม่เจอ Client.EggState]") return end
    local src
    local ok,s = pcall(function() return es.Source end); if ok and type(s)=="string" and #s>0 then src=s end
    if not src and DEC then local ok2,s2=pcall(DEC,es); if ok2 then src=s2 end end
    if not src then push("[decompile ไม่ได้]") return end
    -- โชว์เฉพาะบรรทัดที่เกี่ยว redeem/safe/deposit/touch/zone/homestead
    local hit=0
    for line in src:gmatch("[^\n]+") do
        local L=line:lower()
        if L:find("redeem") or L:find("safe") or L:find("deposit") or L:find("touch")
           or L:find("zone") or L:find("homestead") or L:find("region") or L:find("bounds")
           or L:find("carry") or L:find("crossed") or L:find("verdict") then
            hit=hit+1; if hit<=60 then push("  "..line:gsub("^%s+","")) end
        end
    end
    push("  (เจอบรรทัดเกี่ยวข้อง "..hit..")")
    if type(writefile)=="function" then pcall(writefile,"eggstate_src.txt",src) end
end)

-- 2) หาโซน safe/deposit/homestead ใน Workspace + ระยะจากตัวเรา
push("\n===== โซนใน Workspace (safe/deposit/homestead/base/redeem) =====")
local KW={"safe","deposit","homestead","redeem","dropoff","dropzone","sellzone","base","plot"}
local function kw(n) n=n:lower() for _,k in ipairs(KW) do if n:find(k) then return k end end end
local found=0
pcall(function()
    for _,d in ipairs(WS:GetDescendants()) do
        local k=kw(d.Name)
        if k and (d:IsA("BasePart") or d:IsA("Model") or d:IsA("Folder")) then
            found=found+1
            if found<=50 then
                local pos=partPos(d)
                local dist = (pos and hrpPos) and (pos-hrpPos).Magnitude or -1
                push(("  [%s] <%s> %s | pos=%s | ห่างเรา=%.0f"):format(k,d.ClassName,d:GetFullName(),P(pos),dist))
            end
        end
    end
end)
push("  (รวม "..found.." — ดูตัวที่ห่างเราน้อย = โซนฝากที่ควรไปยืน)")

-- 3) หา "ฐาน/homestead ของเราเอง" (attribute OwnerUserId = MYID)
push("\n===== ฐานที่เป็นของเรา (OwnerUserId="..MYID..") =====")
local mine=0
pcall(function()
    for _,d in ipairs(WS:GetDescendants()) do
        local ok,owner = pcall(function() return d:GetAttribute("OwnerUserId") or d:GetAttribute("UserId") or d:GetAttribute("Owner") end)
        if ok and tostring(owner)==tostring(MYID) then
            mine=mine+1
            if mine<=25 then
                local pos=partPos(d)
                local dist=(pos and hrpPos) and (pos-hrpPos).Magnitude or -1
                push(("  <%s> %s | pos=%s | ห่างเรา=%.0f"):format(d.ClassName,d:GetFullName(),P(pos),dist))
            end
        end
    end
end)
push("  (ฐานเรา รวม "..mine..")")

push("\n════════ จบ — ก๊อปแล้ว วางมาให้ (+ ไฟล์ eggstate_src.txt ถ้ามี) ════════")
save()
