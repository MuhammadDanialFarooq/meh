-- Real server-world and protocol logic; services/transport remain test doubles.
local Protocol=loadModule("NetworkProtocol")
assert(not Protocol.Input({seq=1,heading=0/0},0),"NaN heading accepted")
assert(not Protocol.Input({seq=1,heading=math.huge},0),"Infinite heading accepted")
assert(not Protocol.Input({seq=2.5,heading=0},0),"Fractional sequence accepted")
assert(not Protocol.Input({seq=2,heading=0},2),"Replayed input accepted")
local sequence,heading=Protocol.Input({seq=3,heading=math.pi*6+.5},2)
assert(sequence==3 and math.abs(heading-.5)<1e-6,"Heading normalization failed")
local bucket={};for _=1,8 do assert(Protocol.Allow(bucket,1,20,8)) end
assert(not Protocol.Allow(bucket,1,20,8),"Input flood bypasses token limit")
assert(Protocol.Allow(bucket,1.1,20,8),"Rate limiter did not replenish")
local MW=loadModule("MultiplayerWorld")
local netCfg=table.clone(loadModule("Config"));netCfg.Grid=64;netCfg.ArenaRadius=nil
local netWorld=MW.new(netCfg,function() end,{},4)
assert(netWorld:AddPlayer(1,101,"One",1) and netWorld:AddPlayer(2,102,"Two",2),"Players did not get safe server spawns")
assert(netWorld.entities[2].isHuman,"Second player is treated as bot")
local victim=netWorld.entities[2];local killer=netWorld.entities[1]
local held=netWorld.grid.counts[2]
netWorld:Eliminate(victim,killer,"trail")
assert(not victim.alive and netWorld.grid.counts[2]==held,"Death failed to reserve revive land")
assert(netWorld:RevivePlayer(2) and victim.alive,"Server revive did not restore human2")
assert(netWorld.defeats[2]==nil,"Revive retained deferred inheritance")
netWorld:Eliminate(victim,killer,"trail")
netWorld:ReleaseTerritory(2)
assert((netWorld.grid.counts[2] or 0)==0 and (netWorld.grid.counts[1] or 0)>=held,"Final loss did not inherit land")
netWorld:RemovePlayer(2)
assert(not victim.connected and victim.respawnAt==math.huge,"Leaving player can respawn as bot")
assert(netWorld:AddPlayer(2,103,"Replacement",3),"Vacant slot cannot be reused")
netWorld:Eliminate(killer,netWorld.entities[2],"trail")
netWorld.entities[2].userId=104
netWorld:ReleaseTerritory(1)
assert((netWorld.grid.counts[1] or 0)==0,"Expired land was not released")
local winner=netWorld.entities[2]
for i=1,netWorld.grid.total do if netWorld.grid.mask[i] then netWorld.grid:Set(i,2) end end
assert(netWorld:CheckVictory() and netWorld.winnerId==2,"Non-slot1 human cannot win")
-- Matchmaking same-server registry and host transfer; cloud directory isn't mocked as validated.
local oldStudio=services.RunService.IsStudio;services.RunService.IsStudio=function() return true end
local MM=loadModule("Matchmaking")
local mm=MM.new(netCfg);local p1={UserId=101};local p2={UserId=102}
local room=mm:Create(true,101);assert(room and #room.code==7)
assert(mm:Add(room,p1)==1 and mm:Add(room,p2)==2,"Room slots incorrect")
assert(mm:Find(room.code)==room,"Room code lookup failed")
assert(not mm:Find("bad!"),"Invalid code accepted")
mm:Remove(p1);assert(room.hostId==102 and room.count==1,"Host did not migrate onleave")
mm:Remove(p2);assert(mm.rooms[room.code]==nil,"Empty room leaked")
services.RunService.IsStudio=oldStudio
print("[Paintland V41 TEST PASS] Server2+human lifecycle/inheritance/revive/victory, input validation/rate limits, room membership/host cleanup")
