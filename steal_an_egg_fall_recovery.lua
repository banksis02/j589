local stuck=(function()
-- Detect sustained unsupported Freefall with almost no vertical progress.
local function stuck(samples)
 if #samples<20 then return false end
 local low,high=math.huge,-math.huge
 local falling=0
 for _,s in ipairs(samples) do
  if not s.air or s.ground or s.seated or s.health<=0 or s.state~='Freefall' then return false end
  low=math.min(low,s.y);high=math.max(high,s.y)
  if s.vy < -5 then falling+=1 end
 end
 return high-low<5 and falling>=16
end
return stuck

end)()

local env=getgenv and getgenv() or _G
if game.PlaceId~=107778070777162 then return end
if env.SAE_FALL_STOP then env.SAE_FALL_STOP() end
local active=true
env.SAE_FALL_STOP=function()active=false end
local Players=game:GetService('Players')
local Teleport=game:GetService('TeleportService')
local player=Players.LocalPlayer
local lastAttempt=-math.huge
local samples={}
local character
local readyAt=os.clock()+60
local connection=Teleport.TeleportInitFailed:Connect(function(who)
 if who==player then warn('[SAE FALL] Rejoin failed; waiting before another attempt') end
end)
env.SAE_FALL_STOP=function()active=false;connection:Disconnect() end
task.spawn(function()
 while active do
  task.wait(1)
  local char=player.Character
  if char~=character then character=char;samples={};readyAt=os.clock()+60 end
  local root=char and char:FindFirstChild('HumanoidRootPart')
  local hum=char and char:FindFirstChildOfClass('Humanoid')
  if root and hum and os.clock()>=readyAt then
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char}
   local hit=workspace:Raycast(root.Position,Vector3.new(0,-500,0),params)
   samples[#samples+1]={air=hum.FloorMaterial==Enum.Material.Air,ground=hit~=nil,seated=hum.SeatPart~=nil,health=hum.Health,state=hum:GetState().Name,y=root.Position.Y,vy=root.AssemblyLinearVelocity.Y}
   if #samples>20 then table.remove(samples,1) end
   if stuck(samples) and os.clock()-lastAttempt>=180 then
    lastAttempt=os.clock();samples={};readyAt=os.clock()+180
    warn('[SAE FALL] Unsupported Freefall stuck for 20 seconds; rejoining current server')
    local ok,err=pcall(function()Teleport:TeleportToPlaceInstance(game.PlaceId,game.JobId,player)end)
    if not ok then warn('[SAE FALL] '..tostring(err)) end
   end
  else samples={} end
 end
end)
print('[SAE FALL] Recovery loaded; 60s spawn grace, 20s confirmation')
