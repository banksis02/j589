-- Apply once per server. Keep the first three equipped pets in ActivePets UI order.
return function()
 if game.PlaceId~=107778070777162 then return end
 local env=getgenv and getgenv() or _G
 if env.SAE_PERFORMANCE_JOB==game.JobId then return end
 env.SAE_PERFORMANCE_JOB=game.JobId
 task.spawn(function()
  local ok,err=pcall(function()
   local R=game:GetService('ReplicatedStorage')
   local P=game:GetService('Players').LocalPlayer
   local Save=require(R.Shared.Save)
   local Settings=require(R.Shared.SettingsCmds)
   local Roster=require(R.Client.AssetRoster)
   local function equipped()
    local d=Save.Get();assert(d and type(d.EquippedAssets)=='table','equipment not ready')
    local ids,n={},0;for _,id in pairs(d.EquippedAssets) do id=tostring(id);if not ids[id] then ids[id]=true;n+=1 end end
    return ids,n
   end
   local function plan()
    local ids,n=equipped()
    local ui=P.PlayerGui:FindFirstChild('ActivePets')
    local frame=ui and ui:FindFirstChild('Frame')
    local list=frame and frame:FindFirstChild('ScrollingFrame')
    if not list then return end
    local rows,orders={},{}
    for _,row in ipairs(list:GetChildren()) do
     local id=row.Name:match('^Pet_(.+)$')
     if id and ids[id] then
      local order=row.LayoutOrder
      if orders[order] then return end
      orders[order]=true;rows[#rows+1]={id=id,order=order}
     end
    end
    if #rows~=n then return end
    table.sort(rows,function(a,b)return a.order<b.order end)
    local signature='';for _,row in ipairs(rows) do signature..=row.id..':'..row.order..';' end
    return rows,signature
   end
   local rows,last,stable
   for _=1,60 do
    task.wait(1)
    local current,sig=plan()
    if current and sig==last then stable=(stable or 0)+1 else stable=0 end
    last=sig
    if current and stable>=2 then rows=current;break end
   end
   assert(rows,'ActivePets order not ready; no pets removed')
   for key,value in pairs({HideSelfPets=true,HideOtherPets=true}) do
    local data=Save.Get()
    if not data.Settings or data.Settings[key]~=value then Settings.Write(key,value) end
   end
   local keep={};for i=1,math.min(3,#rows) do keep[rows[i].id]=true end
   for i=#rows,4,-1 do
    local ids,n=equipped()
    if n<=3 then break end
    for id in pairs(keep) do assert(ids[id],'retained pet changed; stopping') end
    local id=rows[i].id
    if ids[id] then
     local result=Roster.DoffAsset(id)
     assert(result~=false,'game rejected unequip')
     local removed=false
     for _=1,20 do task.wait(.25);local now=equipped();if not now[id] then removed=true;break end end
     assert(removed,'unequip not confirmed; stopping')
    end
   end
   local _,n=equipped()
   print('[SAE PERFORMANCE] Hidden pets; equipped remaining: '..n)
  end)
  if not ok then warn('[SAE PERFORMANCE] '..tostring(err)) end
 end)
end
