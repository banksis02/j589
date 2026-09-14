-- STEAL AN EGG — หา Plot ของเรา (อ่านล้วน) → รู้ว่าลู่วิ่งอันไหนของเรา
local Players=game:GetService("Players"); local WS=game:GetService("Workspace")
local player=Players.LocalPlayer
local out={}; local function add(s) out[#out+1]=tostring(s) end
local function save() local t=table.concat(out,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,t) then break end end
    if type(writefile)=="function" then pcall(writefile,"plot_recon.txt",t) end print(t) end
local uid=player.UserId; local uname=player.Name
add("UserId="..uid.." Name="..uname)
local h=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
add("ตำแหน่งเรา="..(h and ("(%.0f,%.0f,%.0f)"):format(h.Position.X,h.Position.Y,h.Position.Z) or "?"))
add("═══ แต่ละ Plot ═══")
local plots=WS:FindFirstChild("Plots")
if plots then for _,pl in ipairs(plots:GetChildren()) do
    local info={"Plot "..pl.Name..":"}
    -- attributes
    local at={} pcall(function() for k,v in pairs(pl:GetAttributes()) do at[#at+1]=k.."="..tostring(v) end end)
    if #at>0 then info[#info+1]="attr{"..table.concat(at,",").."}" end
    -- ลูกที่มี UserId/Owner ในชื่อหรือค่า
    pcall(function() for _,d in ipairs(pl:GetDescendants()) do
        local ok,val=pcall(function() return d.Value end)
        if ok and (tostring(val)==tostring(uid) or tostring(val)==uname) then info[#info+1]="["..d.Name.."="..tostring(val).."]" end
        if d:GetAttribute("OwnerUserId")==uid or d:GetAttribute("UserId")==uid or d:GetAttribute("Owner")==uid then info[#info+1]="{attrOwner@"..d.Name.."}" end
        if (d:IsA("TextLabel") or d:IsA("BillboardGui")) then local ok2,txt=pcall(function() return d.Text end) if ok2 and type(txt)=="string" and (txt:find(uname,1,true)) then info[#info+1]="SIGN('"..txt.."')" end end
    end end)
    add(table.concat(info," "))
end end
add("\n═══ ฐานเรา (ClientRenderedAssets) ═══")
local cra=WS:FindFirstChild("ClientRenderedAssets")
if cra then local n=0 for _,d in ipairs(cra:GetChildren()) do if n<3 and d.Name:find(tostring(uid),1,true) then n=n+1
    local pp=d:FindFirstChildWhichIsA("BasePart",true); add("   "..d.Name.." @"..(pp and ("(%.0f,%.0f,%.0f)"):format(pp.Position.X,pp.Position.Y,pp.Position.Z) or "?")) end end end
add("→ Plot ที่ใกล้ฐานเรา = ลู่ของเรา")
save()
