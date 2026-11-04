-- Actual MultiplayerServer with an in-memory RemoteEvent/Heartbeat transport.
local serverTime=100
local packets={}
local playersService=uiInstance.new("Folder")
playersService.PlayerAdded=signal();playersService.PlayerRemoving=signal()
local pA=uiInstance.new("Player");pA.UserId=901;pA.DisplayName="Alpha";pA.Parent=playersService
local pB=uiInstance.new("Player");pB.UserId=902;pB.DisplayName="Beta";pB.Parent=playersService
function pA:GetJoinData() return {} end;function pB:GetJoinData() return {} end
function playersService:GetPlayers() return {pA,pB} end
local replicated=uiInstance.new("Folder")
local heartbeat=signal()
local transportServices={Players=playersService,ReplicatedStorage=replicated,
    RunService={IsStudio=function() return true end,Heartbeat=heartbeat},TeleportService={TeleportInitFailed=signal()}}
local fakeGame={JobId="testjob",PlaceId=1,GetService=function(_,name) return transportServices[name] or {} end}
local transportInstance={new=function(class)
    local o=uiInstance.new(class)
    if class=="RemoteEvent" then
        o.OnServerEvent=signal()
        function o:FireClient(player,message)
            packets[player]=packets[player] or {};table.insert(packets[player],message)
        end
    end
    return o
end}
local oldClose=game.BindToClose;game.BindToClose=function() end
local oldServiceLookup=game.GetService;game.GetService=fakeGame.GetService
local oldInstance=Instance;Instance=transportInstance
local serverEnv=setmetatable({game=fakeGame,workspace={GetServerTimeNow=function() return serverTime end},
    Instance=transportInstance,task=taskDouble},{__index=getfenv(factories.UIController)})
for _,name in ipairs({"CurrencyService","Matchmaking","MultiplayerServer"}) do setfenv(factories[name],serverEnv);cache[name]=nil end
local server=loadModule("MultiplayerServer").Start(netCfg)
local remotes=replicated:FindFirstChild("PaintlandNetwork")
local command=remotes:FindFirstChild("Command").OnServerEvent
local ability=remotes:FindFirstChild("Ability").OnServerEvent
command:Fire(pA,{action="quick",skin=1});command:Fire(pB,{action="quick",skin=2})
local room=server.byPlayer[pA].room
assert(room==server.byPlayer[pB].room and room.state=="running","QuickPlay failed to put two clients inrunningroom")
local secondSlot=server.byPlayer[pB].slot
local actor=room.world.entities[1]
local coinsBefore=server.currency.entries[pA].coins
local ownedBefore=room.world.grid.counts[1]
ability:Fire(pA,{id="Splash",actorId=secondSlot,radius=9999,coins=99999})
local gained=room.world.grid.counts[1]-ownedBefore
assert(gained>0 and gained<200,"Server trusted client radius/actor instead of configured Splash")
local captureReward=5+math.floor(gained/room.world.grid.playableTotal*100*10)
assert(server.currency.entries[pA].coins==coinsBefore+captureReward,"Authoritative Splash capture wasn't rewarded exactly once")
ability:Fire(pA,{id="Splash"})
assert(room.world.grid.counts[1]==ownedBefore+gained and server.currency.entries[pA].coins==coinsBefore+captureReward,
    "Repeated remote call bypassed cooldown or duplicated reward")
ability:Fire(pA,{id="Dash",duration=9999,multiplier=9999})
assert(actor.dashRemaining==netCfg.DashDurationSeconds and actor.dashMultiplier==netCfg.DashSpeedMultiplier,
    "Server trusted client boost settings")
command:Fire(pA,{action="grant",coins=999999,gems=999999})
assert(server.currency.entries[pA].coins==coinsBefore+captureReward and server.currency.entries[pA].gems==0,
    "Forged currency command changed wallet")
room.world:Eliminate(room.world.entities[secondSlot],room.world.entities[1],"trail")
assert(server.currency.entries[pA].coins==coinsBefore+captureReward+25,"Valid kill didn't award 25 coins")
room.world:Eliminate(room.world.entities[secondSlot],room.world.entities[1],"trail")
assert(server.currency.entries[pA].coins==coinsBefore+captureReward+25,"Duplicate death rewarded another kill")
ability:Fire(pB,{id="Dash"})
assert((room.world.entities[secondSlot].dashRemaining or 0)==0,"Dead client activated Dash")
local last=packets[pB][#packets[pB]-1]
local sentDeath=false
for _,message in ipairs(packets[pB]) do if message.kind=="death" and message.revivesLeft==1 then sentDeath=true end end
assert(sentDeath,"Server didn't send authoritative death")
command:Fire(pB,{action="revive"})
assert(room.world.entities[secondSlot].alive and room.credits[secondSlot]==0,"Server revive didn't consume exactlyonecredit")
room.world:Eliminate(room.world.entities[secondSlot],room.world.entities[1],"trail")
command:Fire(pB,{action="revive"})
assert(not room.world.entities[secondSlot].alive,"Client revived without credit")
serverTime+=5;heartbeat:Fire(.1)
local gotResult=false
for _,message in ipairs(packets[pB]) do if message.kind=="result" then gotResult=true end end
assert(gotResult and room.pending[secondSlot]==nil,"Expired revive didn't produce results")
assert(server.currency.entries[pA].coins==coinsBefore+captureReward+50,"Kill inheritance awarded capture coins a second time")
command:Fire(pA,{action="leave"})
assert(server.byPlayer[pA]==nil,"Server did not remove leaving player")
server:Destroy()
game.GetService=oldServiceLookup;Instance=oldInstance;game.BindToClose=oldClose
print("[Paintland V42 TEST PASS] Server transport: two-client flow, ability authority/cooldowns, forged rewards rejected, one reward per capture/kill")
