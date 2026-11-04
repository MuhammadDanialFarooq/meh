-- Start once from ServerScriptService. Clients send only heading + lobby intent.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")
local Protocol=require(script.Parent.NetworkProtocol)
local Matchmaking=require(script.Parent.Matchmaking)
local MultiplayerWorld=require(script.Parent.MultiplayerWorld)
local CurrencyService=require(script.Parent.CurrencyService)
local AbilityService=require(script.Parent.AbilityService)
local Server={}
local started=false
function Server.Start(cfg)
    if started then return nil end
    started=true
    local folder=Instance.new("Folder");folder.Name=Protocol.RemoteFolder;folder.Parent=ReplicatedStorage
    local command=Instance.new("RemoteEvent");command.Name=Protocol.CommandRemote;command.Parent=folder
    local input=Instance.new("RemoteEvent");input.Name=Protocol.InputRemote;input.Parent=folder
    local abilityRemote=Instance.new("RemoteEvent");abilityRemote.Name=Protocol.AbilityRemote;abilityRemote.Parent=folder
    local state=Instance.new("RemoteEvent");state.Name=Protocol.StateRemote;state.Parent=folder
    local registry=Matchmaking.new(cfg)
    local clients={};local connections={};local alive=true
    local function now() return workspace:GetServerTimeNow() end
    local function send(player,message)
        if player.Parent==Players then state:FireClient(player,message) end
    end
    local currency=CurrencyService.new(cfg,send)
    registry.currency=currency
    local abilities=AbilityService.new(cfg)
    local function broadcast(room,message)
        for _,player in pairs(room.players) do send(player,message) end
    end
    local function errorTo(player,message) send(player,{kind="error",message=message}) end
    local function lobby(room)
        local players={}
        for slot,player in pairs(room.players) do players[#players+1]={id=slot,userId=player.UserId,name=player.DisplayName} end
        table.sort(players,function(a,b) return a.id<b.id end)
        broadcast(room,{kind="lobby",code=room.code,private=room.private,hostId=room.hostId,
            capacity=room.capacity,players=players,state=room.state})
    end
    local function deathSnapshot(world,e)
        local cells={};local grid=world.grid
        for i=1,grid.total do cells[i]=grid.owners[i]==e.id end
        return {count=grid.counts[e.id] or 0,percent=(grid.counts[e.id] or 0)/math.max(1,grid.playableTotal)*100,
            kills=e.kills,color={e.color.R,e.color.G,e.color.B},size=grid.size,cells=cells,mask=table.clone(grid.mask)}
    end
    local function initialize(room)
        room.dirty={};room.sequence=(room.sequence or 0)+1;room.roundId=(room.roundId or 0)+1
        room.pending={};room.credits={};room.accumulator=0;room.snapshotTimer=0;room.sentTrails={}
        local world
        world=MultiplayerWorld.new(cfg,function(index) room.dirty[index]=true end,{
            onCapture=function(actor,count)
                local owner=room.players[actor.id]
                if owner then currency:Capture(owner,count,world.grid.playableTotal) end
                broadcast(room,{kind="capture",actorId=actor.id,count=count,playableTotal=world.grid.playableTotal})
            end,
            onAbsorb=function(actor,count)
                broadcast(room,{kind="capture",actorId=actor.id,count=count,playableTotal=world.grid.playableTotal})
            end,
            onEliminate=function(victim,killer,cause)
                if killer and killer~=victim and killer.alive and room.players[killer.id] then
                    currency:Kill(room.players[killer.id])
                end
                local player=room.players[victim.id]
                if player then
                    local snapshot=deathSnapshot(world,victim)
                    local window=(room.credits[victim.id] or 0)>0 and (cfg.ReviveWindowSeconds or 4) or 0
                    room.pending[victim.id]={deadline=now()+window,snapshot=snapshot}
                    send(player,{kind="death",remaining=window,
                        deadline=room.pending[victim.id].deadline,revivesLeft=room.credits[victim.id] or 0,
                        killerName=killer and killer.name or nil,cause=cause,snapshot=snapshot})
                end
                broadcast(room,{kind="elimination",victimId=victim.id,killerId=killer and killer.id or nil,cause=cause})
            end,
            onVictory=function(winner)
                room.state="completed";room.pending={}
                broadcast(room,{kind="victory",winnerId=winner.id})
            end,
        },room.capacity)
        room.world=world
    end
    local function snapshot(room,player,full,deltas)
        local membership=registry.byPlayer[player];if not membership then return end
        local entities={}
        local sent=room.sentTrails[player] or {};room.sentTrails[player]=sent
        for i,e in ipairs(room.world.entities) do
            local version=tostring(e.userId)..":"..e.spawnRevision..":"..e.trailGeneration..":"..e.visualVersion..":"..#e.trailCells
            entities[i]=Protocol.Entity(e,full or sent[i]~=version)
            sent[i]=version
        end
        local grid=room.world.grid
        send(player,{kind="snapshot",version=Protocol.Version,roomId=room.code,roundId=room.roundId,sequence=room.sequence,
            time=now(),simulationTime=room.world.time,playerEntityId=membership.slot,
            ack=clients[player] and clients[player].sequence or 0,full=full==true,
            owners=full and table.clone(grid.owners) or nil,mask=full and table.clone(grid.mask) or nil,
            size=grid.size,counts=table.clone(grid.counts),playableTotal=grid.playableTotal,
            entities=entities,deltas=deltas or {},state=room.state,winnerId=room.world.winnerId,
            cooldowns=abilities:State(room.world,room.world.entities[membership.slot])})
    end
    local function finish(room,slot)
        local pending=room.pending[slot];if not pending then return end
        room.pending[slot]=nil;room.world:ReleaseTerritory(slot)
        local player=room.players[slot]
        if player then send(player,{kind="result",snapshot=pending.snapshot}) end
    end
    local function remove(player,notify)
        local membership=registry.byPlayer[player]
        if membership then
            local room=membership.room
            room.world:RemovePlayer(membership.slot);room.pending[membership.slot]=nil;room.credits[membership.slot]=nil
            room.sentTrails[player]=nil
            registry:Remove(player)
            if room.count>0 then lobby(room) end
        end
        if notify then send(player,{kind="left"}) end
    end
    local function join(player,room,skin)
        local existing=registry.byPlayer[player]
        if existing and existing.room==room then snapshot(room,player,true);lobby(room);return end
        if not room.world then initialize(room) end
        local oldMembership=registry.byPlayer[player]
        if oldMembership and oldMembership.room==room then snapshot(room,player,true);lobby(room);return end
        if room.count>=room.capacity or room.state=="completed" then errorTo(player,"That room is full or finished.");return end
        remove(player,false)
        local slot=registry:Add(room,player)
        if not slot then errorTo(player,"Could not join room.");return end
        if not room.world:AddPlayer(slot,player.UserId,player.DisplayName,skin) then
            registry:Remove(player);errorTo(player,"No safe spawn in this arena; try another room.");return
        end
        room.credits[slot]=math.max(0,math.floor(cfg.MultiplayerFreeRevivesPerRun or 1))
        clients[player].heading=nil;clients[player].lastInput=0
        if not room.private and room.count>=math.max(2,cfg.MultiplayerMinPlayers or 2) then room.state="running" end
        room.sequence+=1;snapshot(room,player,true);lobby(room)
        task.spawn(function() registry:Refresh() end)
    end
    local function teleport(player,destination,code,skin)
        if RunService:IsStudio() then errorTo(player,"Cross-server joins require a published experience.");return end
        if destination.placeId~=game.PlaceId or type(destination.jobId)~="string" then errorTo(player,"Room destination expired.");return end
        if not currency:Flush(player) then errorTo(player,"Saving your wallet; please try joining again shortly.");return end
        local options=Instance.new("TeleportOptions");options.ServerInstanceId=destination.jobId
        options:SetTeleportData({paintlandRoom=code,paintlandQuick=code==nil,paintlandSkin=skin})
        send(player,{kind="joining",message="Joining arena..."})
        local ok=pcall(function() TeleportService:TeleportAsync(game.PlaceId,{player},options) end)
        if not ok then errorTo(player,"Could not reach that server. Try again.") end
    end
    local function process(player,message)
        if type(message)~="table" or type(message.action)~="string" then return end
        local client=clients[player];if not client then return end
        if message.action=="leave" and client.busy then client.cancelRequested=true;return end
        if not Protocol.Allow(client.commands,os.clock(),2,5) or client.busy then return end
        client.busy=true
        local ok,err=pcall(function()
            local action=message.action
            local membership=registry.byPlayer[player]
            local skin=Protocol.IsFinite(message.skin) and math.clamp(math.floor(message.skin),1,#cfg.Colors) or client.skin or 1
            currency:Publish(player)
            if action=="sync" then
                if membership then snapshot(membership.room,player,true) end
            elseif action=="quick" then
                local existing
                for _,candidate in pairs(registry.rooms) do
                    if not candidate.private and candidate.count<candidate.capacity and candidate.state~="completed" then existing=candidate;break end
                end
                if existing then join(player,existing,skin)
                else
                    local destination=registry:QuickDestination()
                    if destination then teleport(player,destination,nil,skin)
                    else local room,why=registry:Quick();if room then join(player,room,skin) else errorTo(player,why) end end
                end
            elseif action=="create" then
                local room,why=registry:Create(true,player.UserId)
                if room then join(player,room,skin) else errorTo(player,why) end
            elseif action=="join" then
                local room,why,destination,code=registry:Find(message.code)
                if room then join(player,room,skin)
                elseif destination then teleport(player,destination,code,skin)
                else errorTo(player,why) end
            elseif action=="leave" then remove(player,true)
            elseif membership then
                local room,slot=membership.room,membership.slot
                if action=="start" then
                    if room.hostId~=player.UserId or room.state~="lobby" then return end
                    if room.count<2 then errorTo(player,"At least two players are needed to start.");return end
                    room.state="running";lobby(room)
                elseif action=="revive" then
                    local pending=room.pending[slot]
                    if not pending or now()>=pending.deadline or (room.credits[slot] or 0)<1 then
                        errorTo(player,"No revive remaining.");return
                    end
                    if room.world:RevivePlayer(slot) then
                        room.credits[slot]-=1;room.pending[slot]=nil
                        send(player,{kind="revived",revivesLeft=room.credits[slot]})
                        room.sequence+=1;snapshot(room,player,true)
                    else errorTo(player,"No safe revive position.") end
                elseif action=="decline" then finish(room,slot)
                elseif action=="replay" then
                    if room.pending[slot] then finish(room,slot) end
                    if room.private then
                        if room.state=="completed" and room.hostId==player.UserId then
                            initialize(room);room.state="lobby"
                            for id,p in pairs(room.players) do
                                if not room.world:AddPlayer(id,p.UserId,p.DisplayName,clients[p].skin or 1) then
                                    errorTo(p,"No safe spawn in this round. Leave and try another arena.")
                                end
                                clients[p].heading=nil;clients[p].lastInput=0
                                room.credits[id]=math.max(0,math.floor(cfg.MultiplayerFreeRevivesPerRun or 1))
                                snapshot(room,p,true)
                            end
                            lobby(room)
                        else errorTo(player,"The host can start a new private round after this round finishes.") end
                    else
                        remove(player,false)
                        local nextRoom,why=registry:Quick()
                        if nextRoom then join(player,nextRoom,skin) else errorTo(player,why) end
                    end
                end
            end
            client.skin=skin
        end)
        client.busy=false
        if client.cancelRequested then client.cancelRequested=false;remove(player,true) end
        if not ok then warn("[Paintland Multiplayer] Command failed: "..tostring(err));errorTo(player,"The action could not be completed. Try again.") end
    end
    connections[#connections+1]=command.OnServerEvent:Connect(process)
    connections[#connections+1]=input.OnServerEvent:Connect(function(player,message)
        local client=clients[player];local membership=registry.byPlayer[player]
        if not client or not membership or membership.room.state~="running" then return end
        if not Protocol.Allow(client.inputs,os.clock(),35,8) then return end
        local seq,heading=Protocol.Input(message,client.sequence)
        if seq then client.sequence=seq;client.heading=heading;client.lastInput=now() end
    end)
    connections[#connections+1]=abilityRemote.OnServerEvent:Connect(function(player,message)
        local client=clients[player];local membership=registry.byPlayer[player]
        if not client or not membership or type(message)~="table" or type(message.id)~="string" then return end
        if not Protocol.Allow(client.abilities,os.clock(),2,4) then return end
        local room=membership.room;local actor=room.world.entities[membership.slot]
        local accepted,result=abilities:Use(room.world,actor,message.id,room.state=="running")
        send(player,{kind="abilityState",id=message.id,accepted=accepted,reason=not accepted and result or nil,
            cooldowns=abilities:State(room.world,actor)})
        if accepted then
            broadcast(room,{kind="ability",actorId=actor.id,id=message.id,x=actor.pos.X,y=actor.pos.Y,
                duration=result.duration,multiplier=result.multiplier,radius=result.radius})
        end
    end)
    local function added(player)
        if clients[player] then return end
        clients[player]={sequence=0,inputs={},commands={},abilities={},skin=1}
        currency:Add(player)
        task.defer(function()
            if player.Parent~=Players then return end
            local ok,joinData=pcall(function() return player:GetJoinData() end)
            local data=ok and joinData.TeleportData
            if type(data)=="table" then
                if type(data.paintlandRoom)=="string" then process(player,{action="join",code=data.paintlandRoom,skin=data.paintlandSkin})
                elseif data.paintlandQuick==true then process(player,{action="quick",skin=data.paintlandSkin}) end
            end
        end)
    end
    connections[#connections+1]=Players.PlayerAdded:Connect(added)
    connections[#connections+1]=Players.PlayerRemoving:Connect(function(player) remove(player,false);clients[player]=nil;currency:Remove(player) end)
    for _,player in ipairs(Players:GetPlayers()) do added(player) end
    connections[#connections+1]=TeleportService.TeleportInitFailed:Connect(function(player)
        if clients[player] then errorTo(player,"Joining the server failed. Please try again.") end
    end)
    local refresh=0
    connections[#connections+1]=RunService.Heartbeat:Connect(function(dt)
        if not alive then return end
        currency:Update(dt)
        refresh+=dt
        if refresh>=35 then refresh=0;task.spawn(function() registry:Refresh() end) end
        for _,room in pairs(registry.rooms) do
            local world=room.world
            if world then
                if room.state=="running" then
                    room.accumulator=math.min(room.accumulator+dt,.25)
                    local steps=0
                    while room.accumulator>=1/60 and steps<12 do
                        room.accumulator-=1/60;steps+=1
                        world:Step(1/60,function(e)
                            local player=room.players[e.id];local client=player and clients[player]
                            if client and now()-(client.lastInput or 0)<1 then return client.heading end
                            return nil
                        end)
                    end
                end
                for slot,pending in pairs(room.pending) do
                    if now()>=pending.deadline then finish(room,slot) end
                end
                room.snapshotTimer+=dt
                if room.snapshotTimer>=1/(cfg.MultiplayerSnapshotRate or 10) then
                    room.snapshotTimer=0;room.sequence+=1
                    local deltas={}
                    for index in pairs(room.dirty) do deltas[#deltas+1]={index,world.grid.owners[index]} end
                    table.clear(room.dirty)
                    for _,player in pairs(room.players) do snapshot(room,player,false,deltas) end
                end
            end
        end
    end)
    game:BindToClose(function() currency:Shutdown() end)
    function registry:Destroy()
        alive=false
        currency:Shutdown()
        for _,connection in ipairs(connections) do connection:Disconnect() end
        for player in pairs(clients) do remove(player,false) end
        folder:Destroy();started=false
    end
    return registry
end
return Server
