-- ============================================================================
-- Steal An Egg — PROBE: ทดสอบดึงรูปไข่ (PrivateImage) จาก executor
-- เช็คว่า request แนบ auth ดึง assetdelivery ได้ไหม + มี base64 encoder ไหม
-- ไม่ยิง remote เกม (ปลอดภัย) — ยิงแค่ HTTP ไป roblox/backend
-- ============================================================================
local out={}
local function w(...) local t={} for _,v in ipairs({...}) do t[#t+1]=tostring(v) end out[#out+1]=table.concat(t," ") end
local function save(text)
    for _,fn in ipairs({setclipboard,toclipboard,writeclipboard}) do
        if type(fn)=="function" and pcall(fn,text) then break end
    end
end

-- executor http
local httpReq = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
w("=== EGG CAPTURE PROBE ===")
w("request fn:", httpReq and "YES" or "NO")

-- base64 encoders ที่มี
local b64
for _,cand in ipairs({
    (crypt and crypt.base64encode), (crypt and crypt.base64 and crypt.base64.encode),
    (crypt and crypt.base64encode), base64_encode, (base64 and base64.encode),
    (Base64 and Base64.encode), (crypt and crypt.base64_encode)
}) do if type(cand)=="function" then b64=cand; break end end
w("base64 encoder:", b64 and "YES" or "NO")
w("")

local EGG_ID = "140733363307193"   -- Gorilla King Egg (PrivateImage)
local function try(label, url, headers)
    w("--- "..label.." ---")
    if not httpReq then w("  (no request fn)"); return end
    local ok,resp = pcall(httpReq, {Url=url, Method="GET", Headers=headers})
    if not ok then w("  pcall error:", resp); return end
    local code = resp and (resp.StatusCode or resp.status_code or resp.Status)
    local body = resp and (resp.Body or resp.body) or ""
    local ct = resp and resp.Headers and (resp.Headers["content-type"] or resp.Headers["Content-Type"])
    w("  status:", code, "| content-type:", ct, "| bodyLen:", #tostring(body))
    -- magic bytes
    local head = tostring(body):sub(1,16)
    local hex=""; for i=1,math.min(8,#head) do hex=hex..string.format("%02X ",string.byte(head,i)) end
    w("  first bytes:", hex)
    if head:sub(1,8)=="\137PNG\r\n\26\n" then w("  ✅ เป็น PNG!")
    elseif head:find("^<") then w("  = XML/HTML (อาจเป็น Decal/redirect):", tostring(body):sub(1,120))
    elseif head:find("^{") then w("  = JSON:", tostring(body):sub(1,150)) end
end

-- วิธีต่างๆ
try("assetdelivery v1 (auth ผ่าน request?)", "https://assetdelivery.roblox.com/v1/asset/?id="..EGG_ID)
try("assetdelivery v2", "https://assetdelivery.roblox.com/v2/assetId/"..EGG_ID)
try("roblox.com/asset", "https://www.roblox.com/asset/?id="..EGG_ID)
try("rbxthumb (game engine)", "rbxthumb://type=Asset&id="..EGG_ID.."&w=150&h=150")

w("")
w("=== สรุป: ถ้าอันไหนขึ้น 'เป็น PNG' = ใช้ดึงรูปไข่ได้ ===")
local text=table.concat(out,"\n")
save(text); print(text)
