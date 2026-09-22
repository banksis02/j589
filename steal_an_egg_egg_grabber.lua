-- ============================================================================
-- Steal An Egg — GRABBER: capture รูปไข่+สัตว์ทั้งหมด (private) มา host เอง
-- CreateEditableImageAsync + ReadPixelsBuffer → ย่อ 128x128 → ส่ง backend encode PNG
-- รันครั้งเดียว (เครื่องไหนก็ได้ที่อยู่ในเกม) — จะข้ามรูปที่ upload แล้ว
-- ============================================================================
local AssetService=game:GetService("AssetService")
local HttpService=game:GetService("HttpService")
local BASE="https://overload-backend-production.up.railway.app"
local TW,TH=128,128

local httpReq=(syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
local function GET(url) if httpReq then local ok,r=pcall(httpReq,{Url=url,Method="GET"}); if ok and r then return r.Body or r.body end end
    local ok2,body=pcall(function() return game:HttpGet(url) end); return ok2 and body or nil end
local function POST(url,tbl)
    if not httpReq then return false,"no request fn" end
    local ok,r=pcall(httpReq,{Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode(tbl)})
    if not ok then return false,tostring(r) end
    local code=r and (r.StatusCode or r.status_code) or 0
    return code>=200 and code<300, tostring(code).." "..tostring(r and (r.Body or r.body) or "")
end

-- base64 (binary-safe): ลอง encoder ของ executor ก่อน แล้ว fallback pure-lua
local b64enc
for _,c in ipairs({(crypt and crypt.base64encode),(crypt and crypt.base64 and crypt.base64.encode),base64_encode,(base64 and base64.encode),(Base64 and Base64.encode)}) do
    if type(c)=="function" then b64enc=c; break end
end
if not b64enc then
    local B='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    b64enc=function(data)
        return ((data:gsub('.',function(x) local r,b='',x:byte() for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end return r end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(x) if #x<6 then return '' end local c=0 for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end return B:sub(c+1,c+1) end)..({'','==','='})[#data%3+1])
    end
end

-- รวม asset id ทั้งหมด (ไข่+สัตว์) จากแคตตาล็อก
local catRaw=GET(BASE.."/api/egg-catalog")
if not catRaw then warn("[GRAB] โหลดแคตตาล็อกไม่ได้"); return end
local cat=HttpService:JSONDecode(catRaw)
local ids,seen={},{}
for _,grp in ipairs({"eggs","pets"}) do
    for _,e in pairs(cat[grp] or {}) do
        if e.icon and not seen[e.icon] then seen[e.icon]=true; ids[#ids+1]=e.icon end
    end
end
-- ข้ามที่ upload แล้ว
local haveRaw=GET(BASE.."/api/egg-image-have")
local have={}
if haveRaw then local ok,h=pcall(function() return HttpService:JSONDecode(haveRaw) end); if ok and h and h.ids then for _,x in ipairs(h.ids) do have[tostring(x)]=true end end end

print(("[GRAB] รวม %d รูป | มีแล้ว %d | จะทำ %d"):format(#ids, (function() local c=0 for _ in pairs(have) do c=c+1 end return c end)(), #ids))

local done,fail,skip=0,0,0
for i,id in ipairs(ids) do
    if have[tostring(id)] then skip=skip+1 else
        local ok,err=pcall(function()
            local src=AssetService:CreateEditableImageAsync("rbxassetid://"..id)
            if not src then error("no editable image") end
            local sw,sh=math.floor(src.Size.X),math.floor(src.Size.Y)
            if sw<1 or sh<1 then error("bad size") end
            local sbuf=src:ReadPixelsBuffer(Vector2.new(0,0),src.Size)
            local out=buffer.create(TW*TH*4)
            for ty=0,TH-1 do
                local sy=math.floor(ty*sh/TH)
                for tx=0,TW-1 do
                    local sx=math.floor(tx*sw/TW)
                    local si=(sy*sw+sx)*4
                    local di=(ty*TW+tx)*4
                    buffer.writeu8(out,di,  buffer.readu8(sbuf,si))
                    buffer.writeu8(out,di+1,buffer.readu8(sbuf,si+1))
                    buffer.writeu8(out,di+2,buffer.readu8(sbuf,si+2))
                    buffer.writeu8(out,di+3,buffer.readu8(sbuf,si+3))
                end
            end
            local b64=b64enc(buffer.tostring(out))
            local sok,msg=POST(BASE.."/api/upload-egg-image",{id=tostring(id),w=TW,h=TH,rgba=b64})
            if not sok then error("upload: "..msg) end
        end)
        if ok then done=done+1 else fail=fail+1; warn(("[GRAB] %s ล้มเหลว: %s"):format(id,tostring(err))) end
        task.wait(0.25)
    end
    if i%20==0 then print(("[GRAB] %d/%d (ok=%d skip=%d fail=%d)"):format(i,#ids,done,skip,fail)) end
end
print(("[GRAB] ✅ เสร็จ — upload สำเร็จ %d | ข้าม %d | ล้มเหลว %d จากทั้งหมด %d"):format(done,skip,fail,#ids))
