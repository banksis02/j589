-- ============================================================================
-- Steal An Egg — RECON: หาค่าเงินอีเวนต์ Dr. Scramble (ขวดเขียว "97")
-- อ่านอย่างเดียว 100% — auto-copy clipboard + probe_currency.txt
-- วิธีใช้: เปิดร้าน DR SCRAMBLE's EXPERIMENTS ค้างไว้ แล้วรันไฟล์นี้
-- ============================================================================
local Players=game:GetService("Players")
local plr=Players.LocalPlayer
local out={}
local function w(...) local t={} for _,v in ipairs({...}) do t[#t+1]=tostring(v) end out[#out+1]=table.concat(t," ") end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
    if type(writefile)=="function" then pcall(writefile,"probe_currency.txt",text) end
end
local function fn(o) local ok,n=pcall(function() return o:GetFullName() end); return ok and n or "?" end

w("=== SAE SCRAMBLE CURRENCY RECON ===")
w("player:",plr.Name)
w("")

-- 1) leaderstats ทั้งหมด (ค่าเงินอีเวนต์อาจอยู่ที่นี่) --------------------------
w("--- [1] leaderstats ---")
local ls=plr:FindFirstChild("leaderstats")
if ls then for _,s in ipairs(ls:GetChildren()) do w("   ",s.Name,"=",tostring(s.Value),"("..s.ClassName..")") end
else w("   (ไม่มี leaderstats)") end
-- โฟลเดอร์ค่าอื่นที่ผู้เล่นถือ (Currency/Data/Values ฯลฯ)
for _,c in ipairs(plr:GetChildren()) do
    if c:IsA("Folder") or c:IsA("Configuration") then
        local n=c.Name:lower()
        if n~="leaderstats" and (n:find("stat")or n:find("data")or n:find("value")or n:find("currenc")or n:find("event")or n:find("scramble")) then
            w("   folder",c.Name..":")
            for _,v in ipairs(c:GetChildren()) do if v:IsA("ValueBase") then w("      -",v.Name,"=",tostring(v.Value)) end end
        end
    end
end
w("")

-- 2) attributes บนผู้เล่น ที่ชื่อเกี่ยวกับ scramble/experiment/flask/event -------
w("--- [2] player attributes (keyword) ---")
for k,v in pairs(plr:GetAttributes()) do
    local lk=k:lower()
    if lk:find("scramble")or lk:find("experiment")or lk:find("flask")or lk:find("event")or lk:find("token")or lk:find("currenc") then
        w("   ",k,"=",tostring(v))
    end
end
w("")

-- 3) หา ScreenGui ใน PlayerGui ที่ชื่อเกี่ยวกับ scramble/experiment/event/shop ---
w("--- [3] PlayerGui: ร้าน/หน้าอีเวนต์ + label ที่เป็นตัวเลข ---")
local pg=plr:FindFirstChild("PlayerGui")
if pg then
    for _,g in ipairs(pg:GetChildren()) do
        local n=g.Name:lower()
        if n:find("scramble")or n:find("experiment")or n:find("event")or n:find("shop") then
            w("   ScreenGui:",g.Name,"(Enabled="..tostring(g.Enabled)..")")
            -- dump label ที่เป็นเลขล้วน (น่าจะเป็นค่าเงิน) + label ที่มีคำ currency/amount/flask
            for _,d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local txt=d.Text or ""
                    local num=txt:gsub(",",""):match("^%s*(%d+)%s*$")
                    local ln=d.Name:lower()
                    if num or ln:find("amount")or ln:find("currenc")or ln:find("flask")or ln:find("cost")or ln:find("balance") then
                        w("      ["..d.Name.."] = '"..txt.."'  @ "..fn(d))
                    end
                end
            end
        end
    end
else w("   (ไม่มี PlayerGui)") end
w("")

-- 4) เทียบ: path BossMastery currency ปัจจุบัน (ที่ report.lua ใช้อยู่) ----------
w("--- [4] อ้างอิง BossMastery GUI (มีไหม/ค่าอะไร) ---")
if pg then
    local bm=pg:FindFirstChild("BossMastery")
    w("   BossMastery ScreenGui:",bm and "YES" or "no")
    local function peek(names)
        local o=pg; for _,x in ipairs(names) do o=o and o:FindFirstChild(x) end
        return o and (o:IsA("TextLabel")or o:IsA("TextButton")) and ("'"..o.Text.."'") or "nil"
    end
    w("   BossMastery.Frame.InfoHolder.MasteryLabel =",peek({"BossMastery","Frame","InfoHolder","MasteryLabel"}))
    w("   BossMastery.Frame.Header.CurrencyHolder.Amount =",peek({"BossMastery","Frame","Header","CurrencyHolder","Amount"}))
end
w("")
w("=== END (ก๊อปข้อความนี้ / ไฟล์ probe_currency.txt) ===")

local text=table.concat(out,"\n")
save(text)
print(text)
