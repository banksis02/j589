-- ============================================================
-- STEAL AN EGG — GUARD OFF  (ปิดระบบยาม client + หยุด guard)
-- รันทับ LEAN: ตัด loop ยาม client + destroy สคริปต์ยาม + anchor/หยุด guard
-- ปลอดภัย: แค่ disconnect/destroy/anchor instance (ไม่ hook) เหมือนตอนปิด ObbyAntiTP
-- ============================================================

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local WS         = game:GetService("Workspace")
local player     = Players.LocalPlayer
local function say(t) print("[GUARD-OFF] "..t) end

-- 1) ตัด connection ของ client guard AI ที่กำลังรันอยู่ (ตัวที่สั่งไล่/ตี/knockback)
local cut = 0
if type(getconnections) == "function" and type(debug) == "table" and type(debug.info) == "function" then
    local sigs = { RunService.Heartbeat, RunService.Stepped, RunService.RenderStepped }
    pcall(function() sigs[#sigs+1] = RunService.PreSimulation end)
    pcall(function() sigs[#sigs+1] = RunService.PostSimulation end)
    for _, sig in ipairs(sigs) do
        pcall(function()
            for _, c in ipairs(getconnections(sig)) do
                local ok, src = pcall(function() return debug.info(c.Function, "s") end)
                if ok and type(src) == "string" and src:lower():find("guard") then
                    pcall(function() c:Disconnect() end); cut = cut + 1
                end
            end
        end)
    end
end
say("ตัด guard loop (Heartbeat/Stepped/etc) = " .. cut .. " เส้น")

-- 2) destroy สคริปต์ยาม client (กันรัน/require รอบใหม่)
local function killGuardScripts(root, label)
    if not root then return end
    local n = 0
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and d.Name:lower():find("guard") then
                pcall(function() d.Enabled = false end)
                pcall(function() d:Destroy() end)
                n = n + 1
            end
        end
    end)
    say("destroy guard scripts (" .. label .. ") = " .. n)
end
killGuardScripts(player:FindFirstChild("PlayerScripts"), "PlayerScripts")

-- 3) neuter functions ใน gc ที่คุมยาม (knockback/catch/punish) — เผื่อ closure ยังค้าง
if type(getgc) == "function" and type(debug) == "table" and type(debug.info) == "function" then
    local neutered = 0
    pcall(function()
        for _, f in ipairs(getgc(false)) do
            if type(f) == "function" then
                local ok, src = pcall(function() return debug.info(f, "s") end)
                if ok and type(src) == "string" then
                    local s = src:lower()
                    if s:find("guardcomponent") or s:find("forestguardruntime")
                       or s:find("guardeggretrieval") or s:find("guardchase") then
                        local okn, nm = pcall(function() return debug.info(f, "n") end)
                        if okn and type(nm) == "string" then
                            local n = nm:lower()
                            if n:find("chase") or n:find("catch") or n:find("knock")
                               or n:find("hit") or n:find("retriev") or n:find("punish")
                               or n:find("grab") or n:find("update") or n:find("step") or n:find("tick") then
                                pcall(function()
                                    if type(replaceclosure) == "function" then
                                        replaceclosure(f, function() end)
                                    elseif type(hookfunction) == "function" then
                                        hookfunction(f, function() end)
                                    end
                                    neutered = neutered + 1
                                end)
                            end
                        end
                    end
                end
            end
        end
    end)
    say("neuter guard functions ใน gc = " .. neutered)
end

-- 4) anchor + หยุด guard ทุกตัวใน Workspace (client) + watcher (guard stream/respawn)
getgenv().__SAE_GUARDOFF = true
local function neuter(model)
    pcall(function()
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then p.Anchored = true end
            if p:IsA("Humanoid") then p.WalkSpeed = 0; p.JumpPower = 0; p.JumpHeight = 0 end
            if p:IsA("ProximityPrompt") then p.Enabled = false end
        end
    end)
end
local function sweep()
    local g = WS:FindFirstChild("_Guards")
    if g then for _, m in ipairs(g:GetDescendants()) do if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then neuter(m) end end end
    local a = WS:FindFirstChild("__OBJECTS")
    a = a and a:FindFirstChild("Areas"); a = a and a:FindFirstChild("GuardAreas")
    if a then for _, m in ipairs(a:GetDescendants()) do if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then neuter(m) end end end
end
task.spawn(function()
    while getgenv().__SAE_GUARDOFF do pcall(sweep); task.wait(1) end
end)
say("anchor+หยุด guard models + watcher เปิด (ปิด: getgenv().__SAE_GUARDOFF=false)")

say("✅ GUARD OFF แล้ว — ลองฟาม 1 รอบ ดูว่ายังโดนตี/ยังเฟลไหม")
