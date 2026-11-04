local testTime=10
local env=setmetatable({workspace={GetServerTimeNow=function() return testTime end},task=taskDouble},
    {__index=getfenv(factories.UIController)})
setfenv(factories.MultiplayerClient,env);cache.MultiplayerClient=nil
local Client=loadModule("MultiplayerClient")
local created,changed,won=0,0,nil
local walletSeen,abilitySeen,abilityState=nil,nil,nil
local nc=Client.new(netCfg,{onWorld=function() created+=1 end,onChanged=function() changed+=1 end,
    onVictory=function(id) won=id end,onWallet=function(data) walletSeen=data end,
    onAbility=function(id,actor) abilitySeen={id,actor} end,onAbilityState=function(data) abilityState=data end})
local sw=MW.new(netCfg,function() end,{},3)
sw:AddPlayer(1,21,"Remote",1);sw:AddPlayer(2,22,"Local",2)
local function packet(sequence,full)
    local es={};for i,e in ipairs(sw.entities) do es[i]=Protocol.Entity(e,true) end
    return {version=Protocol.Version,roomId="ROOMABC",roundId=1,sequence=sequence,time=testTime,simulationTime=testTime,
        playerEntityId=2,full=full,owners=table.clone(sw.grid.owners),mask=table.clone(sw.grid.mask),
        size=sw.grid.size,playableTotal=sw.grid.playableTotal,counts=table.clone(sw.grid.counts),entities=es,deltas={},state="running"}
end
nc:ApplySnapshot(packet(1,true))
local abilitySent
nc.ready=true;nc.abilityRemote={FireServer=function(_,msg) abilitySent=msg end}
nc:UseAbility("Dash");assert(abilitySent and abilitySent.id=="Dash","Ability intent wasn't sent")
nc:Receive({kind="ability",actorId=2,id="Dash",duration=.65,multiplier=2.25})
assert(abilitySeen[1]=="Dash" and abilitySeen[2]==1 and nc.predicted.dashRemaining==.65,"Dash acknowledgement failed to map local actor/boost")
nc:Receive({kind="abilityState",equipped="Dash",charge=35,required=100,ready=false})
assert(abilityState.charge==35 and nc.world.entities[1].equippedAbility=="Dash","Server charge didn't reach UI callback")
assert(created==1 and nc.world.entities[1].userId==22 and nc.world.entities[2].userId==21,"Local slot remapping failed")
for i,owner in ipairs(sw.grid.owners) do
    assert(nc.world.grid.owners[i]==(owner==2 and 1 or owner==1 and 2 or owner),"Owner remapping failed")
end
local sent={};nc.ready=true;nc.inputRemote={FireServer=function(_,msg) sent[#sent+1]=msg end}
local original=nc.world.entities[1].pos
for _=1,6 do testTime+=1/60;nc:Update(1/60,function() return .3 end) end
assert(#sent>=1 and #sent<=3 and (nc.world.entities[1].pos-original).Magnitude>0,"Prediction/input cadence broken")
local next=packet(2,false);next.entities[2].x-=5
local before=nc.world.entities[1].pos
nc:ApplySnapshot(next)
assert((nc.world.entities[1].pos-before).Magnitude<1e-6,"Normal correction snapped local player")
testTime+=1/60;nc:Update(1/60,function() return .3 end)
assert((nc.world.entities[1].pos-before).Magnitude<3,"Correction failed to blend")
local index=sw.grid:At(sw.entities[2].pos);next=packet(3,false);next.deltas={{index,1}}
nc:ApplySnapshot(next);assert(nc.world.grid.owners[index]==2 and changed>0,"Delta mapping failed")
assert(nc.predicted.dashRemaining==0,"Authoritative snapshot didn't clear expired Dash")
next=packet(2,false);next.deltas={{index,2}};nc:ApplySnapshot(next)
assert(nc.world.grid.owners[index]==2,"Stale packet overwrote newer owner")
next=packet(4,false);next.state="completed";next.winnerId=2;nc:ApplySnapshot(next)
assert(won==1 and nc.world.completed,"Mapped local victory missing")
nc.accepting=false;nc:Receive({kind="wallet",coins=55,gems=1,loaded=true})
assert(walletSeen and walletSeen.coins==55,"Menu ignored wallet update after leaving a match")
nc:Destroy()
print("[Paintland V41 TEST PASS] Replica slot/owner mapping, prediction cadence, blended corrections, deltas/stale packet guard, mapped victory")
