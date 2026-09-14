-- STEAL AN EGG — BOSS RECON (ตอนบอส active) อ่านล้วน ไม่ยิง remote
local Players=game:GetService("Players"); local WS=game:GetService("Workspace"); local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local out={}; local function add(s) out[#out+1]=tostring(s) end
local function save() local t=table.concat(out,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"boss_recon.txt",t) end print(t) end
local function P(v) return v and ("(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z) or "?" end
local h=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local function pos(o) if o:IsA("BasePart") then return o.Position end local p=o:FindFirstChild("HumanoidRootPart") or o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart") return p and p.Position end
add("════ BOSS RECON (active) ════"); add("เรา @"..P(h and h.Position))

-- ★★ 0) หา "ประตู RIFT" (BOSS FIGHT RIFT) ที่ต้องเข้าก่อน + วิธีเข้า ★★
add("── ประตู RIFT (ต้องเข้าก่อน) ──")
local myPos=(h and h.Position) or Vector3.new()
local KW_RIFT={"rift","Rift","portal","Portal","boss","Boss","fight","Fight","tear","Tear","monsterevent","MonsterEvent"}
local seen={}
for _,d in ipairs(WS:GetDescendants()) do
    local nm=d.Name:lower()
    local hit=false
    for _,k in ipairs({"rift","portal","boss","fight","tear"}) do if nm:find(k,1,true) then hit=true break end end
    -- หรือ BillboardGui/TextLabel ที่มีข้อความ BOSS FIGHT RIFT
    if not hit and (d:IsA("TextLabel") or d:IsA("BillboardGui")) then local ok,tx=pcall(function() return d.Text end) if ok and type(tx)=="string" and tx:upper():find("RIFT") then hit=true end end
    if hit and (d:IsA("BasePart") or d:IsA("Model") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("TextLabel")) then
        local pp=pos(d) or (d:FindFirstAncestorWhichIsA("Model") and pos(d:FindFirstAncestorWhichIsA("Model")))
        local dist=(pp and h) and (pp-myPos).Magnitude or -1
        if pp and dist<300 and not seen[d:GetFullName()] then
            seen[d:GetFullName()]=true
            local intr={}
            local scan=(d:IsA("Model") and d) or d.Parent
            if scan then for _,c in ipairs(scan:GetDescendants()) do
                if c:IsA("ProximityPrompt") then intr[#intr+1]="Prompt('"..(c.ActionText or "").."/"..(c.ObjectText or "").."')"
                elseif c:IsA("ClickDetector") then intr[#intr+1]="Click"
                elseif c:IsA("TouchTransmitter") then intr[#intr+1]="Touch" end
            end end
            local txt=""; if d:IsA("TextLabel") then local ok,t2=pcall(function() return d.Text end) if ok then txt=" '"..tostring(t2).."'" end end
            add(("   %s [%s]%s @%s ห่าง%.0f เข้า=%s"):format(d.Name, d.ClassName, txt, P(pp), dist, #intr>0 and table.concat(intr,",") or "-(เดินชน?)"))
        end
    end
end

-- 1) ชื่อบอสจาก UI
local pg=player:FindFirstChild("PlayerGui")
local bui=pg and pg:FindFirstChild("BossFightUI")
if bui then pcall(function()
    local nm=bui:FindFirstChild("BossHPBar",true) and bui.BossHPBar:FindFirstChild("BossName")
    add("BossFightUI.BossName = '"..(nm and tostring(nm.Text) or "?").."' | UI visible="..tostring(bui.Enabled))
    for _,d in ipairs(bui:GetDescendants()) do if d:IsA("TextLabel") and #d.Text>0 and #d.Text<40 then add("   UI: "..d.Name.."='"..d.Text.."'") end end
end) end

-- 2) หา boss model ใน Workspace (Humanoid + MaxHealth เยอะ / ชื่อ boss)
add("\n── Boss model ในแมพ ──")
local found=0
for _,d in ipairs(WS:GetDescendants()) do
    if found<8 and d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
        local hu=d:FindFirstChildOfClass("Humanoid")
        local nm=d.Name:lower()
        if hu.MaxHealth>=1000 or nm:find("boss") or nm:find("overlord") or nm:find("abyss") or nm:find("titan") or nm:find("monster") then
            found=found+1
            local isP=Players:GetPlayerFromCharacter(d)
            if not isP then
                add(("   %s @%s ห่าง%.0f HP=%.0f/%.0f"):format(d:GetFullName():gsub("Workspace%.",""), P(pos(d)), (h and pos(d)) and (pos(d)-h.Position).Magnitude or -1, hu.Health, hu.MaxHealth))
                -- interact + attributes
                local at={} pcall(function() for k,v in pairs(d:GetAttributes()) do at[#at+1]=k.."="..tostring(v) end end)
                if #at>0 then add("      attr{"..table.concat(at,",").."}") end
                for _,c in ipairs(d:GetDescendants()) do if c:IsA("ProximityPrompt") then add("      Prompt('"..(c.ActionText or "").."')") elseif c:IsA("ClickDetector") then add("      Click") end end
            end
        end
    end
end
if found==0 then add("   (ไม่เจอ Model+Humanoid ที่เป็นบอส — บอสอาจเป็นโครงสร้างอื่น/ใน folder เฉพาะ)") end

-- 3) โฟลเดอร์ BossEvent/MonsterEvent/Rift ใน Workspace (บอสอาจอยู่ในนี้)
add("\n── folder event ในแมพ ──")
for _,d in ipairs(WS:GetChildren()) do local n=d.Name:lower()
    if n:find("boss") or n:find("monster") or n:find("event") or n:find("rift") or n:find("arena") then
        add("   "..d.Name.." ("..d.ClassName..") children="..#d:GetChildren())
        for _,c in ipairs(d:GetChildren()) do add("      └ "..c.Name.." ("..c.ClassName..") @"..P(pos(c) )) end
    end
end

-- 4) อาวุธ/tool ที่เรามี (ใช้ตีบอส)
add("\n── อาวุธ/tool ที่เรามี ──")
for _,src in ipairs({player.Character, player:FindFirstChild("Backpack")}) do
    if src then for _,it in ipairs(src:GetChildren()) do if it:IsA("Tool") then
        add(("   %s (%s) ItemType=%s"):format(it.Name, src.Name, tostring(it:GetAttribute("ItemType")))) end end end
end

-- 5) BossEvent attributes (state) — จาก workspace/RS ที่ชื่อ BossEvent
add("\n── BossEvent state (attributes อ่านล้วน) ──")
for _,root in ipairs({WS, RS}) do pcall(function()
    for _,d in ipairs(root:GetDescendants()) do
        if (d.Name=="BossEvent" or d.Name=="MonsterEvent" or d.Name:find("Boss") ) and not d:IsA("RemoteEvent") and not d:IsA("RemoteFunction") then
            local at={} for k,v in pairs(d:GetAttributes()) do at[#at+1]=k.."="..tostring(v) end
            if #at>0 then add("   "..d:GetFullName():gsub("ReplicatedStorage","RS"):gsub("Workspace","WS").." {"..table.concat(at,",").."}") end
        end
    end
end) end
add("════ จบ วาง output มา ════"); save()
