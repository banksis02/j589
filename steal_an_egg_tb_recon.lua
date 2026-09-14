-- ============================================================
-- STEAL AN EGG — TREADMILL + BOSS RECON (อ่านล้วน ไม่ hook ไม่ยิง remote = ปลอดภัย AC)
-- ดัมพ์โครงสร้างจริง: ลู่วิ่ง(treadmill) + บอส/rift/event เพื่อสร้าง module ให้ตรง
-- รัน → auto-copy clipboard + เซฟไฟล์ → วาง output กลับมา
-- ============================================================
local Players=game:GetService("Players")
local WS=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local out={}
local function add(s) out[#out+1]=tostring(s) end
local function save()
    local txt=table.concat(out,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"tb_recon.txt",txt) end
    print(txt)
end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function partPos(o) if o:IsA("BasePart") then return o.Position end local pp=o:FindFirstChild("HumanoidRootPart") or o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart") return pp and pp.Position end
local function interactables(o)  -- prompt/click/touch บน object (บอกวิธี interact)
    local r={}
    for _,d in ipairs(o:GetDescendants()) do
        if d:IsA("ProximityPrompt") then r[#r+1]="Prompt('"..(d.ActionText or "")..'/'..(d.ObjectText or "").."')"
        elseif d:IsA("ClickDetector") then r[#r+1]="Click"
        elseif d:IsA("TouchTransmitter") then r[#r+1]="Touch" end
    end
    return #r>0 and table.concat(r,",") or "-"
end

add("════════ TREADMILL + BOSS RECON ════════")
local h=hrp(); add("ตำแหน่งเราตอนนี้ = "..P(h and h.Position))

-- ═══ (1) TREADMILL / ลู่วิ่ง ═══
add("\n───── (1) TREADMILL / ลู่วิ่ง ─────")
-- 1a) leaderstats/speed
add("leaderstats:")
local ls=player:FindFirstChild("leaderstats")
if ls then for _,s in ipairs(ls:GetChildren()) do add("   "..s.Name.." = "..tostring(s.Value)) end else add("   (ไม่มี)") end
local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
add("Humanoid.WalkSpeed = "..(hum and tostring(hum.WalkSpeed) or "?"))
-- 1b) treadmill objects ใน Workspace
add("Workspace objects ที่ชื่อเกี่ยว treadmill/train/run/speed:")
local KW_T={"treadmill","Treadmill","Train","train","Running","running","SpeedPad","Belt"}
local cnt=0
for _,d in ipairs(WS:GetDescendants()) do
    if cnt<25 then
        for _,k in ipairs(KW_T) do
            if d.Name:find(k,1,true) and (d:IsA("Model") or d:IsA("BasePart") or d:IsA("ProximityPrompt")) then
                cnt=cnt+1
                local pos=partPos(d)
                local dist=(h and pos) and (pos-h.Position).Magnitude or -1
                add(("   %s [%s] @%s ห่าง%.0f interact=%s"):format(d:GetFullName():gsub("Workspace%.",""), d.ClassName, P(pos), dist, (d:IsA("Model") and interactables(d)) or "-"))
                break
            end
        end
    end
end
if cnt==0 then add("   (ไม่เจอชื่อ treadmill ตรงๆ — ดู remote/GUI ข้างล่าง)") end
-- 1c) Treadmill GUI
local pg=player:FindFirstChild("PlayerGui")
add("PlayerGui ที่เกี่ยว treadmill/speed/train:")
if pg then local g=0 for _,d in ipairs(pg:GetChildren()) do if g<20 and d.Name:lower():find("tread") or d.Name:lower():find("speed") or d.Name:lower():find("train") then g=g+1 add("   "..d.Name.." ("..d.ClassName..") visible="..tostring(d.Enabled)) end end end

-- ═══ (2) BOSS / RIFT / EVENT ═══
add("\n───── (2) BOSS / RIFT / EVENT ─────")
local KW_B={"boss","Boss","rift","Rift","overlord","Overlord","abyss","Abyss","event","Event","raid","Raid","spawn","monster","Monster","enemy","Enemy"}
add("Workspace objects ที่ชื่อเกี่ยว boss/rift/event:")
local cb=0
for _,d in ipairs(WS:GetChildren()) do   -- ชั้นบนก่อน (folder ใหญ่)
    for _,k in ipairs(KW_B) do
        if d.Name:find(k,1,true) then cb=cb+1 add("   [top] "..d.Name.." ("..d.ClassName..") children="..#d:GetChildren()) break end
    end
end
-- ลึกลงไป (Model ที่มี Humanoid = ตัวบอส)
add("Model ที่มี Humanoid (อาจเป็นบอส/มอน) + ชื่อเกี่ยว boss:")
local cm=0
for _,d in ipairs(WS:GetDescendants()) do
    if cm<20 and d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
        local nm=d.Name:lower()
        if nm:find("boss") or nm:find("rift") or nm:find("overlord") or nm:find("abyss") or nm:find("raid") or nm:find("titan") then
            cm=cm+1
            local hp=d:FindFirstChildOfClass("Humanoid")
            local pos=partPos(d)
            add(("   %s @%s ห่าง%.0f HP=%s/%s interact=%s"):format(d:GetFullName():gsub("Workspace%.",""), P(pos), (h and pos) and (pos-h.Position).Magnitude or -1, hp and math.floor(hp.Health) or "?", hp and math.floor(hp.MaxHealth) or "?", interactables(d)))
        end
    end
end
if cb==0 and cm==0 then add("   (ไม่เจอบอส/rift ตอนนี้ — อาจต้องรอ event spawn / บอกผมชื่อบอสที่เห็นในเกม)") end
-- boss GUI/announcement
add("PlayerGui ที่เกี่ยว boss/rift/event:")
if pg then local g=0 for _,d in ipairs(pg:GetDescendants()) do if g<15 then local n=d.Name:lower() if (n:find("boss") or n:find("rift") or n:find("event") or n:find("raid") or n:find("overlord")) and (d:IsA("TextLabel") or d:IsA("ScreenGui") or d:IsA("Frame")) then g=g+1 add("   "..d:GetFullName():gsub("^.-PlayerGui%.","")..(d:IsA("TextLabel") and (" = '"..tostring(d.Text).."'") or "")) end end end end

-- ═══ (3) REMOTES (ชื่ออย่างเดียว ไม่ยิง!) ═══
add("\n───── (3) REMOTES ที่เกี่ยว treadmill/boss/rift/combat (ชื่อล้วน ไม่ยิง) ─────")
local KW_R={"Treadmill","Train","Speed","Boss","Rift","Raid","Event","Attack","Damage","Hit","Combat","Overlord","Abyss","Reward","Claim"}
local cr=0
local function scanRemotes(root,label)
    if not root then return end
    pcall(function() for _,d in ipairs(root:GetDescendants()) do
        if cr<50 and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent")) then
            for _,k in ipairs(KW_R) do if d.Name:find(k,1,true) then cr=cr+1 add("   "..d.ClassName.." "..d:GetFullName():gsub("ReplicatedStorage%.","RS.")) break end end
        end
    end end)
end
scanRemotes(RS)
if cr==0 then add("   (ไม่เจอ — remote อาจชื่ออื่น บอกผมถ้าอยากให้ดัมพ์ remote ทั้งหมด)") end

add("\n════════ จบ — วาง output กลับมา ════════")
save()
