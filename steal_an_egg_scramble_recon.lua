-- ============================================================================
-- Steal An Egg — RECON: อีเวนต์ตีบอทในแมพ (Dr. Scramble / Monster Event)
-- อ่านอย่างเดียว 100% (ไม่ hook / ไม่ยิง remote) — ปลอดภัยกับ AC
-- auto-copy clipboard + probe_scramble.txt
-- วิธีใช้: อยู่ในแมพอีเวนต์ที่มีบอท (ยืนใกล้บอทตัวหนึ่ง) แล้วรันไฟล์นี้
-- ============================================================================
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local out={}
local function w(...)
    local t={}
    for _,v in ipairs({...}) do t[#t+1]=tostring(v) end
    out[#out+1]=table.concat(t," ")
end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
    if type(writefile)=="function" then pcall(writefile,"probe_scramble.txt",text) end
end
local function fn(o)
    local ok,n=pcall(function() return o:GetFullName() end)
    return ok and n or "?"
end
local function posOf(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o.Position end
    local p=o:FindFirstChildWhichIsA("BasePart",true)
    return p and p.Position or nil
end
local function vec(v) return v and string.format("(%.0f, %.0f, %.0f)",v.X,v.Y,v.Z) or "nil" end

local char=plr.Character
local hrp=char and char:FindFirstChild("HumanoidRootPart")
local myPos=hrp and hrp.Position
w("=== SAE MONSTER/SCRAMBLE COMBAT RECON ===")
w("player:",plr.Name,"| myPos:",vec(myPos))
w("")

-- [1] หาบอท: model ที่มี TextLabel รูปแบบ 'X/Y' (HP) หรือชื่อ Scramble/Experiment/Monster
w("--- [1] บอทในแมพ (จากป้าย HP 'X/Y' หรือชื่อ) ---")
local found={}
local seen={}
local function consider(model, why)
    if not model or seen[model] then return end
    if model==workspace then return end
    seen[model]=true
    found[#found+1]={model=model, why=why}
end
local ok1=pcall(function()
    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local txt=d.Text or ""
            local a,b=txt:match("(%d[%d,]*)%s*/%s*(%d[%d,]*)")
            local up=txt:upper()
            if a or up:find("SCRAMBLE") or up:find("EXPERIMENT") then
                local m=d:FindFirstAncestorWhichIsA("Model")
                consider(m, "hpText='"..txt.."'")
            end
        elseif d:IsA("Model") then
            local n=d.Name:upper()
            if n:find("SCRAMBLE") or n:find("EXPERIMENT") or n:find("NIBBLE") then
                consider(d, "name")
            end
        end
    end
end)
if not ok1 then w("   (scan error)") end
-- เรียงจากใกล้สุด
table.sort(found,function(x,y)
    local px,py=posOf(x.model),posOf(y.model)
    if myPos and px and py then return (px-myPos).Magnitude<(py-myPos).Magnitude end
    return false
end)
w("พบ",#found,"เป้า")
for i,e in ipairs(found) do
    if i>10 then w("   ...(อีก",#found-10,")"); break end
    local mp=posOf(e.model)
    local dist=(myPos and mp) and string.format("%.0f",(mp-myPos).Magnitude) or "?"
    w(("[%d] %s | dist=%s | pos=%s | %s"):format(i,fn(e.model),dist,vec(mp),e.why))
end
w("")

-- [2] เป้าใกล้สุด: โครงสร้าง + วิธีทำดาเมจ
w("--- [2] เป้าใกล้สุด: ตี/interact ยังไง ---")
local near=found[1] and found[1].model
if near then
    w("model:",fn(near))
    local hum=near:FindFirstChildOfClass("Humanoid")
    if hum then w("   Humanoid: Health="..tostring(hum.Health).."/"..tostring(hum.MaxHealth)) else w("   Humanoid: none") end
    w("   PrimaryPart:",near.PrimaryPart and near.PrimaryPart.Name or "none")
    local pp,cd,touch
    for _,d in ipairs(near:GetDescendants()) do
        if not pp and d:IsA("ProximityPrompt") then pp=d end
        if not cd and d:IsA("ClickDetector") then cd=d end
        if not touch and d:IsA("BasePart") and d:FindFirstChildOfClass("TouchTransmitter") then touch=d end
    end
    w("   ProximityPrompt:",pp and (pp.ActionText.." @ "..fn(pp)) or "no")
    w("   ClickDetector:",cd and "YES" or "no")
    w("   TouchTransmitter part:",touch and touch.Name or "no")
    w("   attributes:")
    for k,v in pairs(near:GetAttributes()) do w("      -",k,"=",tostring(v)) end
    w("   children (name : class):")
    for _,c in ipairs(near:GetChildren()) do w("      -",c.Name,":",c.ClassName) end
else
    w("(ไม่พบบอท — ต้องอยู่ในแมพอีเวนต์ตอนบอทเกิด แล้วยืนใกล้ๆ)")
end
w("")

-- [3] container ในแมพ (ที่เกิดบอท/บอส)
w("--- [3] workspace containers น่าสน ---")
local ok3=pcall(function()
    for _,c in ipairs(workspace:GetChildren()) do
        local n=c.Name:upper()
        if n:find("MONSTER") or n:find("EVENT") or n:find("SCRAMBLE") or n:find("EXPERIMENT")
           or n:find("BOSS") or n:find("SPAWN") or n:find("ENEM") or n:find("MOB") then
            w(("   * %s : %s (children=%d)"):format(c.Name,c.ClassName,#c:GetChildren()))
        end
    end
end)
if not ok3 then w("   (error)") end
w("")

-- [4] remotes ที่ชื่อเกี่ยวข้อง (อ่านชื่อเฉยๆ)
w("--- [4] remotes keyword (scramble/monster/event/boss/damage/hit/enter) ---")
local KW={"scramble","experiment","monster","event","boss","damage","hit","attack","enter","nibble"}
local roots={RS}
local net=RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
if net then roots[#roots+1]=net end
local rc=0
pcall(function()
    for _,rt in ipairs(roots) do
        for _,d in ipairs(rt:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local ln=d.Name:lower()
                for _,k in ipairs(KW) do
                    if ln:find(k) then w("   ",d.ClassName,":",d.Name); rc=rc+1; break end
                end
            end
        end
    end
end)
if rc==0 then w("   (ไม่พบชื่อตรง keyword)") end
w("")

-- [5] อาวุธผู้เล่น
w("--- [5] tools/weapon ---")
local function tools(holder,label)
    if not holder then return end
    for _,t in ipairs(holder:GetChildren()) do
        if t:IsA("Tool") then
            w(("   [%s] %s | ItemType=%s | GearName=%s | IsBat=%s"):format(
                label,t.Name,tostring(t:GetAttribute("ItemType")),tostring(t:GetAttribute("GearName")),tostring(t:GetAttribute("IsBat"))))
        end
    end
end
tools(char,"equipped")
tools(plr:FindFirstChild("Backpack"),"backpack")
w("")
w("=== END (ก๊อปข้อความนี้ / ไฟล์ probe_scramble.txt) ===")

local text=table.concat(out,"\n")
save(text)
print(text)
