-- ============================================================
-- STEAL AN EGG — REMOTE SPY (ดักว่าสคริปที่ใช้ได้ยิง remote อะไรไป server)
-- ⚠️ ใช้ __namecall hook — เกมนี้เคยเตะ (Error 267) ตอน hook. เสี่ยง! ลองไอดีฟาร์ม
-- วิธี: รัน spy นี้ก่อน → รันสคริปที่ใช้ได้ → เก็บ/ฝากไข่ 1-2 รอบ → SAE_SPYSTOP() → วาง log
-- ============================================================
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

if type(hookmetamethod)~="function" or type(getnamecallmethod)~="function" then
    warn("[SPY] executor ไม่มี hookmetamethod/getnamecallmethod — ใช้ไม่ได้"); return
end

local logs={}
local t0=os.clock()
local function T() return ("%6.2f"):format(os.clock()-t0) end
local function push(l) logs[#logs+1]=l; print(l) end
local function save()
    local txt=table.concat(logs,"\n")
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do if type(fn)=="function" and pcall(fn,txt) then break end end
    if type(writefile)=="function" then pcall(writefile,"egg_remotespy.txt",txt) end
end
local function ppos() local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart") if h then local p=h.Position return ("(%.0f,%.0f,%.0f)"):format(p.X,p.Y,p.Z) end return "?" end
local function ser(v,depth)
    depth=depth or 0
    local t=typeof(v)
    if t=="Instance" then return "<"..v.ClassName..">"..v.Name
    elseif t=="string" then return #v>60 and ('%q'):format(v:sub(1,60).."..") or ('%q'):format(v)
    elseif t=="CFrame" then local p=v.Position return ("CF(%.0f,%.0f,%.0f)"):format(p.X,p.Y,p.Z)
    elseif t=="Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X,v.Y,v.Z)
    elseif t=="table" then
        if depth>2 then return "{...}" end
        local parts={} for k,vv in pairs(v) do parts[#parts+1]=tostring(k).."="..ser(vv,depth+1) end
        return "{"..table.concat(parts,", ").."}"
    else return tostring(v) end
end
local function argstr(...) local a={} local n=select("#",...) for i=1,n do a[i]=ser((select(i,...))) end return table.concat(a,", ") end

_G.SAE_SPY_ON = true
-- คำที่เกี่ยวกับเก็บ/ฝากไข่ (กรอง noise)
local KW = {"egg","Egg","carry","Carry","field","Field","redeem","Redeem","claim","Claim","deposit","Deposit","steal","Steal","place","Place","area","Area","rig","Rig"}
local function want(full)
    for _,k in ipairs(KW) do if full:find(k,1,true) then return true end end
    return false
end

local old
old = hookmetamethod(game, "__namecall", function(self, ...)
    if _G.SAE_SPY_ON then
        local ok,m = pcall(getnamecallmethod)
        if ok and (m=="FireServer" or m=="InvokeServer") then
            local okc = pcall(function() return self:IsA("RemoteEvent") or self:IsA("RemoteFunction") end)
            if okc then
                local full = self:GetFullName()
                if want(full) then
                    local short = full:gsub("Players%..-%.","P."):gsub("ReplicatedStorage%.","RS."):gsub("Packages%.Networking%.","NET.")
                    push(("[%s] %s  %s(%s)  @%s"):format(T(), m, short, argstr(...), ppos()))
                    save()
                end
            end
        end
    end
    return old(self, ...)
end)

push("════════ REMOTE SPY เปิด (__namecall hook) ════════")
push("รันสคริปที่ใช้ได้ → เก็บ/ฝากไข่ 1-2 รอบ → SAE_SPYSTOP()")
push("(ถ้าโดนเตะ Error 267 = เกมจับ hook ได้ → เลิกใช้วิธีนี้)")
save()

function SAE_SPYSTOP()
    _G.SAE_SPY_ON = false
    save()
    push("🛑 STOP — copy แล้ว วางมาให้ ("..#logs.." บรรทัด)")
    save()
end
pcall(function() getgenv().SAE_SPYSTOP=SAE_SPYSTOP; _G.SAE_SPYSTOP=SAE_SPYSTOP end)
