-- ============================================================
-- STEAL AN EGG — RIGSYNC/PROBESATCHEL SRC (หาว่าเกมยิง ProbeSatchel ยังไง + เลขคืออะไร)
-- อ่าน/decompile อย่างเดียว ไม่ hook = ปลอดภัย
-- เพื่อ replicate anti-cheat heartbeat ที่สคริปที่ใช้ได้ยิง (เราขาด → desync)
-- รัน → ก๊อป output วางมา
-- ============================================================
local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local DEC = (type(decompile)=="function" and decompile) or nil
local out={}
local function add(s) out[#out+1]=s end

-- 1) หา remote ProbeSatchel + ToolTrigger
add("════════ RIGSYNC / TOOLTRIGGER PROBE ════════")
local function findRemote(namePart)
    local hits={}
    pcall(function() for _,d in ipairs(RS:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name:find(namePart,1,true) then hits[#hits+1]=d end
    end end)
    return hits
end
for _,nm in ipairs({"ProbeSatchel","RigSync","ToolTrigger","Satchel"}) do
    local h=findRemote(nm)
    add("remote *"..nm.."*: "..#h)
    for _,r in ipairs(h) do add("   "..r.ClassName.." "..r:GetFullName()) end
end

-- 2) หา client script ที่ "ยิง" ProbeSatchel/ToolTrigger (เพื่อดูว่าส่งอะไร)
add("\n===== หา client script ที่เรียก ProbeSatchel/ToolTrigger (decompile) =====")
local KW={"ProbeSatchel","ToolTrigger","RigSync"}
local scanned=0
local function scanRoot(root,label)
    if not root then return end
    pcall(function()
        for _,d in ipairs(root:GetDescendants()) do
            if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and scanned<40 then
                local src
                local ok,s=pcall(function() return d.Source end); if ok and type(s)=="string" and #s>0 then src=s end
                if not src and DEC then local ok2,s2=pcall(DEC,d); if ok2 then src=s2 end end
                if type(src)=="string" then
                    for _,k in ipairs(KW) do
                        if src:find(k,1,true) then
                            scanned=scanned+1
                            add("\n---- "..d:GetFullName().." (มี "..k..") ----")
                            -- โชว์เฉพาะบรรทัดที่เกี่ยว
                            local shown=0
                            for line in src:gmatch("[^\n]+") do
                                if (line:find("ProbeSatchel",1,true) or line:find("ToolTrigger",1,true) or line:find("Satchel",1,true) or line:find("Probe",1,true)) and shown<25 then
                                    shown=shown+1; add("   "..line:gsub("^%s+",""))
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end
scanRoot(player:FindFirstChild("PlayerScripts"),"PlayerScripts")
scanRoot(RS,"RS")

local txt=table.concat(out,"\n")
for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
if type(writefile)=="function" then pcall(writefile,"rigsync_src.txt",txt) end
print(txt)
print("... (ก๊อปแล้ว วางมาให้)")
