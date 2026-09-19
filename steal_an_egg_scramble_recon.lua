-- ============================================================================
-- Steal An Egg — RECON: อีเวนต์ตีบอทในแมพ "DR. SCRAMBLE EXPERIMENT"
-- อ่านอย่างเดียว 100% (ไม่ hook / ไม่ยิง remote) — ปลอดภัยกับ AC
-- auto-copy ลง clipboard + probe_scramble.txt
-- วิธีใช้: ยืนใกล้ๆ บอทตัวหนึ่งแล้วรันไฟล์นี้
-- ============================================================================
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local out={}
local function w(...) local t={} for _,v in ipairs({...}) do t[#t+1]=tostring(v) end out[#out+1]=table.concat(t," ") end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
    if type(writefile)=="function" then pcall(writefile,"probe_scramble.txt",text) end
end
local function fullname(o) local ok,n=pcall(function() return o:GetFullName() end); return ok and n or "?" end
local function posOf(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o.Position end
    if o:IsA("Model") then
        if o.PrimaryPart then return o.PrimaryPart.Position end
        local p=o:FindFirstChildWhichIsA("BasePart",true); if p then return p.Position end
    end
end
local function vecStr(v) return v and string.format("(%.1f, %.1f, %.1f)",v.X,v.Y,v.Z) or "nil" end

local char=plr.Character
local hrp=char and char:FindFirstChild("HumanoidRootPart")
local myPos=hrp and hrp.Position
w("=== SAE SCRAMBLE RECON ===")
w("player:",plr.Name,"| userId:",plr.UserId)
w("myPos:",vecStr(myPos))
w("")

-- 1) หาบอทจาก billboard/text ที่เป็น "X/Y HP" หรือมีคำว่า SCRAMBLE/EXPERIMENT ---------
w("--- [1] TARGETS (จาก text billboard 'X/Y' หรือชื่อ Scramble/Experiment) ---")
local seenModels={}
local function ownerModel(inst)
    local m=inst
    while m and m.Parent do
        if m:IsA("Model") and (m:FindFirstChildOfClass("Humanoid") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")) then
            -- ขึ้นไปหา model ที่ดูเป็น "ตัวบอท" (มี Humanoid หรือหลายส่วน) — แต่ไม่ถึง workspace
            local parent=m.Parent
            if parent==workspace or (parent and parent.Parent==workspace) then return m end
        end
        m=m.Parent
        if m==workspace then break end
    end
    return inst:FindFirstAncestorWhichIsA("Model")
end
local matches={}
for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("TextLabel") or d:IsA("TextButton") then
        local txt=d.Text or ""
        local up=txt:upper()
        local a,b=txt:match("(%d[%d,]*)%s*/%s*(%d[%d,]*)")
        if a or up:find("SCRAMBLE") or up:find("EXPERIMENT") then
            local m=ownerModel(d)
            if m and not seenModels[m] then
                seenModels[m]=true
                table.insert(matches,{model=m,label=d,text=txt})
            end
        end
    end
end
-- เผื่อชื่อ model ตรงๆ
for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("Model") then
        local n=d.Name:upper()
        if (n:find("SCRAMBLE") or n:find("EXPERIMENT")) and not seenModels[d] then
            seenModels[d]=true; table.insert(matches,{model=d,label=nil,text=d.Name})
        end
    end
end
w("พบ",#matches,"เป้า")
table.sort(matches,function(x,y)
    local px,py=posOf(x.model),posOf(y.model)
    if myPos and px and py then return (px-myPos).Magnitude<(py-myPos).Magnitude end
    return false
end)
for i,m in ipairs(matches) do
    if i>8 then w("...(อีก",#matches-8,"ตัว)"); break end
    local mp=posOf(m.model)
    local dist=(myPos and mp) and string.format("%.0f",(mp-myPos).Magnitude) or "?"
    w(("[%d] %s | dist=%s | pos=%s"):format(i,fullname(m.model),dist,vecStr(mp)))
    w("     HP text: '"..tostring(m.text).."'"..(m.label and (" @ "..fullname(m.label)) or ""))
    local hum=m.model:FindFirstChildOfClass and m.model:FindFirstChildOfClass("Humanoid")
    if hum then w(("     Humanoid: Health=%s/%s"):format(tostring(hum.Health),tostring(hum.MaxHealth))) end
end
w("")

-- 2) วิธีทำดาเมจ: ตรวจ descendants ของเป้าที่ใกล้สุด (ProximityPrompt/ClickDetector/Touch/Humanoid) ---
w("--- [2] เป้าใกล้สุด: โครงสร้าง + วิธี interact ---")
local near=matches[1] and matches[1].model
if near then
    w("model:",fullname(near),"| class children:")
    local kinds={}
    for _,d in ipairs(near:GetDescendants()) do kinds[d.ClassName]=(kinds[d.ClassName] or 0)+1 end
    local line={}
    for k,v in pairs(kinds) do line[#line+1]=k.."x"..v end
    w("   ",table.concat(line,", "))
    w("   ProximityPrompt:",(#near:GetDescendants()>0) and (near:FindFirstChildWhichIsA("ProximityPrompt",true) and "YES" or "no") or "no")
    w("   ClickDetector:",near:FindFirstChildWhichIsA("ClickDetector",true) and "YES" or "no")
    local touch=false
    for _,d in ipairs(near:GetDescendants()) do if d:IsA("BasePart") and d:FindFirstChildOfClass("TouchTransmitter") then touch=true break end end
    w("   TouchTransmitter(part):",touch and "YES" or "no")
    w("   attributes:")
    for k,v in pairs(near:GetAttributes()) do w("      -",k,"=",tostring(v)) end
    w("   direct children (name : class):")
    for _,c in ipairs(near:GetChildren()) do w("      -",c.Name,":",c.ClassName) end
else
    w("(ไม่พบเป้า — ลองยืนใกล้บอทแล้วรันใหม่ หรือดูว่ามันอยู่ในโฟลเดอร์ชื่ออะไรใน [4])")
end
w("")

-- 3) remotes ที่เกี่ยวข้อง (อ่านชื่อเฉยๆ ไม่ยิง) -----------------------------------
w("--- [3] REMOTES ที่ชื่อเกี่ยวกับ event/scramble/monster/damage ---")
local KW={"scramble","experiment","monster","event","boss","damage","hit","attack","enter"}
local net=RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
local scanRoots={RS}
if net then table.insert(scanRoots,net) end
local rc=0
for _,rootc in ipairs(scanRoots) do
    for _,d in ipairs(rootc:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local ln=d.Name:lower()
            for _,k in ipairs(KW) do
                if ln:find(k) then w("   ",d.ClassName,":",d.Name); rc=rc+1; break end
            end
        end
    end
end
if rc==0 then w("   (ไม่พบ remote ที่ชื่อตรง keyword — เดี๋ยวดูจากโครงสร้างแทน)") end
w("")

-- 4) container ในแมพที่น่าเป็นที่เกิดบอท (โฟลเดอร์ใน workspace + MonsterEventMap) ------
w("--- [4] workspace containers ที่น่าสน ---")
for _,c in ipairs(workspace:GetChildren()) do
    local n=c.Name:upper()
    if n:find("MONSTER") or n:find("EVENT") or n:find("SCRAMBLE") or n:find("EXPERIMENT") or n:find("SPAWN") or n:find("ENEM") or n:find("MOB") then
        w("   *",c.Name,":",c.ClassName,"(children:",#c:GetChildren()..")")
    end
end
w("   MonsterEventMap:",workspace:FindFirstChild("MonsterEventMap") and ("YES ("..#workspace.MonsterEventMap:GetChildren()..")") or "no")
w("")

-- 5) อาวุธ/ทูลของผู้เล่น --------------------------------------------------------
w("--- [5] player tools/weapon ---")
local function dumpTools(holder,label)
    if not holder then return end
    for _,t in ipairs(holder:GetChildren()) do
        if t:IsA("Tool") then
            w(("   [%s] %s | ItemType=%s | GearName=%s | IsBat=%s"):format(
                label,t.Name,tostring(t:GetAttribute("ItemType")),tostring(t:GetAttribute("GearName")),tostring(t:GetAttribute("IsBat"))))
        end
    end
end
dumpTools(char,"equipped")
dumpTools(plr:FindFirstChild("Backpack"),"backpack")
w("")
w("=== END (ก๊อปข้อความนี้ส่งกลับ / ไฟล์: probe_scramble.txt) ===")

local text=table.concat(out,"\n")
save(text)
print(text)
