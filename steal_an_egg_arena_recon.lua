-- STEAL AN EGG — ARENA RECON (รันข้างในห้องบอส) อ่านล้วน
-- จับ: หิน CrystalTowers(ตียังไง) + counter(5/5,15/15) + สถานะบอสล้ม + วิธีตี
local Players=game:GetService("Players"); local WS=game:GetService("Workspace")
local player=Players.LocalPlayer
local out={}; local function add(s) out[#out+1]=tostring(s) end
local function save() local t=table.concat(out,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"arena_recon.txt",t) end print(t) end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local function pos(o) if o:IsA("BasePart") then return o.Position end if o:IsA("Model") then local ok,pp=pcall(function() return o.PrimaryPart end) if ok and pp then return pp.Position end end local b=o:FindFirstChildWhichIsA("BasePart",true) return b and b.Position end
local h=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
add("════ ARENA RECON ════ เรา@"..P(h and h.Position))
local ar=WS:FindFirstChild("BossArena")
if not ar then add("❌ ไม่อยู่ใน BossArena (เข้าห้องบอสก่อนแล้วรัน)"); save(); return end

-- ① CrystalTowers (หินที่ต้องตี)
add("── CrystalTowers (หิน) ──")
local ct=ar:FindFirstChild("CrystalTowers")
if ct then
    add("จำนวนลูก = "..#ct:GetChildren())
    local n=0
    for _,c in ipairs(ct:GetDescendants()) do
        -- หา "แกนหิน" = Model/Part ที่มี Humanoid(HP) หรือ ProximityPrompt/ClickDetector/Health
        if n<12 and (c:IsA("Model") or (c:IsA("BasePart") and c.Name:lower():find("crystal")) ) then
            local hu=c:IsA("Model") and c:FindFirstChildOfClass("Humanoid")
            local intr={}
            for _,d in ipairs((c:IsA("Model") and c:GetDescendants()) or {c}) do
                if d:IsA("ProximityPrompt") then intr[#intr+1]="Prompt('"..(d.ActionText or "").."')"
                elseif d:IsA("ClickDetector") then intr[#intr+1]="Click"
                elseif d:IsA("TouchTransmitter") then intr[#intr+1]="Touch" end
            end
            local at={} pcall(function() for k,v in pairs(c:GetAttributes()) do at[#at+1]=k.."="..tostring(v) end end)
            if c:IsA("Model") or #intr>0 or #at>0 then
                n=n+1
                add(("   %s [%s] @%s HP=%s เข้า=%s attr{%s}"):format(c.Name, c.ClassName, P(pos(c)),
                    hu and (math.floor(hu.Health).."/"..math.floor(hu.MaxHealth)) or "-",
                    #intr>0 and table.concat(intr,",") or "-", table.concat(at,",")))
            end
        end
    end
else add("   (ไม่มี CrystalTowers)") end

-- ② Boss state (ล้ม/vulnerable)
add("── Boss state ──")
local boss=ar:FindFirstChild("Boss")
if boss then
    add("Boss @"..P(pos(boss)))
    local hu=boss:FindFirstChildOfClass("Humanoid")
    add("   Humanoid="..(hu and (math.floor(hu.Health).."/"..math.floor(hu.MaxHealth)) or "ไม่มี"))
    local at={} pcall(function() for k,v in pairs(boss:GetAttributes()) do at[#at+1]=k.."="..tostring(v) end end)
    add("   attr{"..table.concat(at,",").."} (ดู field ที่บอก ล้ม/vulnerable/downed/stunned)")
    for _,c in ipairs(boss:GetChildren()) do add("      └ "..c.Name.." ("..c.ClassName..")") end
end

-- ③ counter UI (5/5, 15/15)
add("── counter/UI (5/5,15/15) ──")
local pg=player:FindFirstChild("PlayerGui")
if pg then for _,d in ipairs(pg:GetDescendants()) do
    if d:IsA("TextLabel") then local ok,tx=pcall(function() return d.Text end)
        if ok and type(tx)=="string" and (tx:match("%d+%s*/%s*%d+") or tx:upper():find("CRYSTAL") or tx:upper():find("PHASE") or tx:upper():find("STAGE")) then
            add("   "..d:GetFullName():gsub("^.-PlayerGui%.","").." = '"..tx.."'") end end
end end
add("════ จบ วาง output มา ════"); save()
