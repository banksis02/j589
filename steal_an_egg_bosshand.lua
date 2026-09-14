-- STEAL AN EGG — หา "มือ/แขนบอส" ตอนล้ม (รันตอนบอสยื่นแขนมาให้ตี) อ่านล้วน
local Players=game:GetService("Players"); local WS=game:GetService("Workspace")
local player=Players.LocalPlayer
local out={}; local function add(s) out[#out+1]=tostring(s) end
local function save() local t=table.concat(out,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"bosshand.txt",t) end print(t) end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local h=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local myPos=(h and h.Position) or Vector3.new()
add("════ BOSS HAND RECON ════ เรา@"..P(myPos))
local ar=WS:FindFirstChild("BossArena"); local b=ar and ar:FindFirstChild("Boss")
if not b then add("❌ ไม่เจอ BossArena.Boss (เข้า arena + ตอนบอสล้มยื่นแขน)"); save(); return end
add("Boss @"..P((b.PrimaryPart and b.PrimaryPart.Position)).." attr Attacking="..tostring(b:GetAttribute("Attacking")))
-- ทุก BasePart เรียงตามใกล้เราสุด (แขน/มือ = อันที่ยื่นมาใกล้/ต่ำ)
local parts={}
for _,d in ipairs(b:GetDescendants()) do if d:IsA("BasePart") then
    parts[#parts+1]={name=d.Name, pos=d.Position, dist=(d.Position-myPos).Magnitude, y=d.Position.Y, size=d.Size, canq=d.CanQuery, can=d.CanCollide}
end end
table.sort(parts,function(a,b) return a.dist<b.dist end)
add("── BasePart เรียงใกล้เราสุด (แขน/มือ=ใกล้+Y ต่ำ) ──")
for i=1,math.min(#parts,20) do local x=parts[i]
    add(("  #%d %s @%s ห่าง%.0f Y=%.0f size=%.0f,%.0f,%.0f canCollide=%s"):format(i,x.name,P(x.pos),x.dist,x.y,x.size.X,x.size.Y,x.size.Z,tostring(x.can)))
end
-- ลูกที่ชื่อเกี่ยวมือ/แขน
add("── part ชื่อเกี่ยว hand/arm/fist/hit/weak/core ──")
for _,d in ipairs(b:GetDescendants()) do local n=d.Name:lower()
    if n:find("hand") or n:find("arm") or n:find("fist") or n:find("hit") or n:find("weak") or n:find("core") or n:find("target") then
        add("  "..d.Name.." ("..d.ClassName..") @"..P(d:IsA("BasePart") and d.Position)) end
end
add("════ จบ วาง output ════"); save()
