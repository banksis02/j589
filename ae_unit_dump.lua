-- ============================================================
-- AE — UNIT DATA DUMP (อ่าน replica ล้วน — ไม่ hook, ไม่เตะ)
--   ดูว่า GameUnit replica Data มี field อะไรบ้าง (โดยเฉพาะ Priority/Targeting + ตำแหน่ง)
--   วิธีใช้ (ในด่าน): วางยูนิต 1-2 ตัว → ตั้ง Priority (เช่น Boss) → อัพเกรด → รันสคริปต์นี้
-- ============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local out = {}
local function add(t) t=tostring(t); out[#out+1]=t; print("[UDUMP] "..t) end
local function save()
    local text = table.concat(out, "\n")
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn)=="function" and pcall(fn, text) then add(">> copied ✅"); break end
    end
    if type(writefile)=="function" then pcall(writefile, "ae_unit_dump.txt", text) end
end
local function ser(v, d)
    d=d or 0; local t=typeof(v)
    if t=="Instance" then return "<"..v.ClassName..">"..v.Name
    elseif t=="string" then return string.format("%q",v)
    elseif t=="CFrame" then local p=v.Position return ("CFrame(%.1f,%.1f,%.1f)"):format(p.X,p.Y,p.Z)
    elseif t=="Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z)
    elseif t=="table" then
        if d>=4 then return "{..}" end
        local parts,n={},0
        for k,vv in pairs(v) do n=n+1; if n>40 then parts[#parts+1]="..."; break end; parts[#parts+1]="["..tostring(k).."]="..ser(vv,d+1) end
        return "{"..table.concat(parts,", ").."}"
    else return t..":"..tostring(v) end
end

-- setup replica registry (แบบเดียวกับสคริปต์แบก — อ่านล้วน)
local registry
pcall(function()
    local shared = RS:FindFirstChild("Shared")
    local mod = shared and shared:FindFirstChild("ReplicaClient")
    local RC = require(mod)
    for _, up in pairs(debug.getupvalues(RC.FromId)) do
        if type(up)=="table" then
            for kk in pairs(up) do if type(kk)=="number" then registry=up; break end end
            if registry then break end
        end
    end
end)

add("════ UNIT DATA DUMP ════  registry="..(registry and "✅" or "❌"))
if not registry then add("❌ หา replica registry ไม่เจอ (executor ไม่มี debug.getupvalues?)"); save(); return end

-- ตำแหน่งยูนิตจาก workspace.Units (จับคู่ด้วย id ถ้าได้)
local unitPos = {}
pcall(function()
    local u = workspace:FindFirstChild("Units")
    if u then for _, m in ipairs(u:GetChildren()) do
        local ok,p = pcall(function() return m:GetPivot().Position end)
        if ok then unitPos[m.Name] = p end
    end end
end)

local n = 0
for _, rep in pairs(registry) do
    local ok, tok = pcall(function() return rep.Token end)
    if ok and tok == "GameUnit" then
        local okd, d = pcall(function() return rep.Data end)
        if okd and type(d)=="table" then
            n = n + 1
            add(""); add("── GameUnit #"..n.." ──")
            -- dump ทุก field ของ Data
            for k, v in pairs(d) do
                add(("   [%s] = %s"):format(tostring(k), ser(v)))
            end
            -- ตำแหน่งจาก workspace ถ้า id ตรงชื่อโมเดล
            local id = d.ID or d.Id
            if id and unitPos[tostring(id)] then add("   (workspace pos = "..ser(unitPos[tostring(id)])..")") end
        end
    end
end
add(""); add("รวม GameUnit ของทุกคน = "..n.." (ดู field Owner/Priority/Targeting/Upgrade/Asset)")
save()
add(">> เสร็จ — ก๊อป clipboard มาวางให้เดฟ")
