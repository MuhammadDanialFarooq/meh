-- Server-owned territory with cosmetic client prediction and buffered remote motion.
-- No client collision, capture, kill or revive decision is sent to the server.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Protocol=require(script.Parent.NetworkProtocol)
local Grid=require(script.Parent.Grid)
local Movement=require(script.Parent.Movement)
local Client={}
Client.__index=Client
local function angle(a,b,t) return a+math.atan2(math.sin(b-a),math.cos(b-a))*t end
local function color(rgb)
    if typeof(rgb)=="Color3" then return rgb end
    return Color3.new(rgb[1] or 1,rgb[2] or 1,rgb[3] or 1)
end
local function clock() return workspace:GetServerTimeNow() end
function Client.new(cfg,callbacks)
    local self=setmetatable({cfg=cfg,callbacks=callbacks or {},sequence=0,lastSnapshot=-1,
        inputTimer=0,samples={},connections={},ready=false,connecting=false,destroyed=false,
        correction=Vector2.zero,pendingVictory=nil},Client)
    self:Connect()
    return self
end
function Client:Emit(name,...)
    local callback=self.callbacks[name]
    if callback then callback(...) end
end
function Client:Connect()
    if self.ready or self.connecting or self.destroyed then return end
    self.connecting=true
    task.spawn(function()
        local folder=ReplicatedStorage:WaitForChild(Protocol.RemoteFolder,10)
        if self.destroyed then return end
        self.connecting=false
        if not folder then
            self:Emit("onError","Multiplayer server missing. Install PaintlandServer in ServerScriptService.")
            return
        end
        local command=folder:WaitForChild(Protocol.CommandRemote,5)
        local input=folder:WaitForChild(Protocol.InputRemote,5)
        local state=folder:WaitForChild(Protocol.StateRemote,5)
        local ability=folder:WaitForChild(Protocol.AbilityRemote,5)
        if self.destroyed then return end
        if not command or not input or not state or not ability then self:Emit("onError","Server network is incomplete. Try again.");return end
        self.commandRemote=command;self.inputRemote=input;self.abilityRemote=ability;self.ready=true
        self.connections[#self.connections+1]=state.OnClientEvent:Connect(function(message)
            if not self.destroyed then self:Receive(message) end
        end)
        if self.pendingCommand then
            local message=self.pendingCommand;self.pendingCommand=nil;command:FireServer(message)
        else command:FireServer({action="sync"}) end
    end)
end
function Client:Command(action,fields)
    if self.destroyed then return end
    if action=="leave" then self.accepting=false
    elseif action=="quick" or action=="create" or action=="join" or action=="replay" then self.accepting=true end
    local message=table.clone(fields or {});message.action=action
    if self.ready then self.commandRemote:FireServer(message)
    else self.pendingCommand=message;self:Connect() end
end
function Client:MapId(id)
    if id==self.playerEntityId then return 1 end
    if id==1 then return self.playerEntityId end
    return id
end
function Client:UseAbility(id)
    if self.ready and self.accepting~=false and self.world and self.world.roomState=="running"
        and self.world.entities[1] and self.world.entities[1].alive then
        self.abilityRemote:FireServer({id=id})
    end
end
function Client:SnapshotStats(snapshot)
    local result=table.clone(snapshot)
    result.color=color(snapshot.color or {1,1,1})
    return result
end
function Client:Receive(message)
    if type(message)~="table" then return end
    local kind=message.kind
    if kind=="wallet" then self:Emit("onWallet",message);return end
    if self.accepting==false and kind~="left" and kind~="error" then return end
    if kind=="snapshot" then self:ApplySnapshot(message)
    elseif kind=="abilityState" then self:Emit("onAbilityState",message)
    elseif kind=="ability" then
        local id=self:MapId(message.actorId)
        if id==1 and message.id=="Dash" and self.predicted then
            self.predicted.dashRemaining=message.duration;self.predicted.dashMultiplier=message.multiplier
        end
        self:Emit("onAbility",message.id,id,message)
    elseif kind=="lobby" then
        self.lobby=message;self.room=message.code
        if self.world then self.world.roomState=message.state end
        self:Emit("onLobby",message)
    elseif kind=="death" then
        if self.world and self.world.entities[1] then self.world.entities[1].alive=false end
        self.predicted=nil;self.correction=Vector2.zero
        self:Emit("onDeath",self:SnapshotStats(message.snapshot),
            math.max(0,message.deadline and message.deadline-clock() or message.remaining or 4),message.revivesLeft or 0)
    elseif kind=="result" then
        self:Emit("onResult",self:SnapshotStats(message.snapshot))
    elseif kind=="revived" then
        self:Emit("onRevived",message)
    elseif kind=="capture" then
        self:Emit("onCapture",self:MapId(message.actorId),message.count,message.playableTotal)
    elseif kind=="elimination" then
        self:Emit("onElimination",self:MapId(message.victimId),message.killerId and self:MapId(message.killerId),message.cause)
    elseif kind=="victory" then
        -- Wait for the completed ownership snapshot before showing final stats.
        self.pendingVictory=message.winnerId
    elseif kind=="left" then
        self.world=nil;self.room=nil;self.lobby=nil;self.predicted=nil;self.samples={};self.lastSnapshot=-1
        self:Emit("onLeft")
    elseif kind=="joining" then self:Emit("onJoining",message.message)
    elseif kind=="error" then self:Emit("onError",message.message or "Matchmaking failed.") end
end
function Client:ApplySnapshot(packet)
    if packet.version~=Protocol.Version or packet.size~=self.cfg.Grid then
        self:Emit("onError","Client and server versions differ. Rejoin after updating the place.");return
    end
    local fresh=not self.world or self.room~=packet.roomId or self.roundId~=packet.roundId or self.playerEntityId~=packet.playerEntityId
    if not fresh and not packet.full and packet.sequence<=self.lastSnapshot then return end
    if fresh and not packet.full then self:Command("sync");return end
    self.playerEntityId=packet.playerEntityId;self.room=packet.roomId;self.roundId=packet.roundId
    self.lastSnapshot=packet.sequence;self.lastReceive=clock();self.lastServerTime=packet.time
    self.ack=packet.ack or 0
    if fresh then
        local grid=Grid.new(self.cfg,function(index) self:Emit("onChanged",index) end)
        self.world={cfg=self.cfg,grid=grid,entities={},time=packet.simulationTime or 0,completed=false,network=true}
        self.samples={};self.predicted=nil;self.correction=Vector2.zero;self.victoryShown=false
    end
    local world=self.world;local grid=world.grid
    if packet.full then
        grid.mask=table.clone(packet.mask);grid.playableTotal=packet.playableTotal
        for i=1,grid.total do grid.owners[i]=self:MapId(packet.owners[i]) end
        if not fresh then for i=1,grid.total do self:Emit("onChanged",i) end end
    else
        for _,entry in ipairs(packet.deltas or {}) do
            local index,owner=entry[1],self:MapId(entry[2])
            if grid.owners[index]~=owner then grid.owners[index]=owner;self:Emit("onChanged",index) end
        end
    end
    grid.counts={}
    for id,count in pairs(packet.counts) do grid.counts[self:MapId(id)]=count end
    world.time=packet.simulationTime or world.time;world.roomState=packet.state
    world.winnerId=packet.winnerId and self:MapId(packet.winnerId)
    world.roundComplete=packet.state=="completed"
    world.completed=world.roundComplete and world.winnerId==1
    for _,wire in ipairs(packet.entities) do
        local id=self:MapId(wire.id)
        local e=world.entities[id]
        local respawn=not e or e.userId~=wire.userId or e.spawnRevision~=wire.spawnRevision or (not e.alive and wire.alive)
        if not e then
            e={id=id,pos=Vector2.new(wire.x,wire.y),home=Vector2.new(wire.x,wire.y),nodes={},trailCells={},trailSet={}}
            world.entities[id]=e
        end
        e.userId=wire.userId;e.name=wire.name;e.connected=wire.connected;e.isHuman=wire.isHuman==true
        e.color=color(wire.color);e.darkColor=Color3.new(e.color.R*.79,e.color.G*.79,e.color.B*.79)
        e.alive=wire.alive;e.kills=wire.kills or 0;e.killStreak=wire.killStreak or 0;e.bestKillStreak=wire.bestKillStreak or 0
        e.drawing=wire.drawing;e.visualVersion=wire.visualVersion;e.trailGeneration=wire.trailGeneration;e.spawnRevision=wire.spawnRevision
        e.targetHeading=wire.targetHeading;e.heading=e.heading or wire.heading
        e.dashRemaining=wire.dashRemaining or 0;e.dashMultiplier=wire.dashMultiplier or 1
        if wire.nodes then
            e.nodes={};for i,p in ipairs(wire.nodes) do e.nodes[i]=Vector2.new(p[1],p[2]) end
        end
        if wire.trailCells then e.trailCells=table.clone(wire.trailCells) end
        local point=Vector2.new(wire.x,wire.y)
        if id==1 then
            local predicted={pos=point,heading=wire.heading,targetHeading=self.desiredHeading or wire.targetHeading,
                isHuman=true,edgeDirection=e.edgeDirection,dashRemaining=e.dashRemaining,dashMultiplier=e.dashMultiplier}
            if wire.alive and packet.state=="running" then
                -- Re-project the authoritative head only through the measured packet age.
                local horizon=math.clamp(clock()-packet.time,0,.2)
                while horizon>0 do local dt=math.min(horizon,1/60);Movement.Step(predicted,dt,self.cfg,grid.half);horizon-=dt end
            end
            if respawn or fresh then
                self.correction=Vector2.zero;e.pos=predicted.pos;e.heading=wire.heading
                self:Emit("onRespawn",e)
            else self.correction=e.pos-predicted.pos end
            self.predicted=predicted
        else
            local list=self.samples[id] or {};self.samples[id]=list
            if respawn then table.clear(list);e.pos=point;e.heading=wire.heading end
            list[#list+1]={time=packet.time,pos=point,heading=wire.heading}
            while #list>5 do table.remove(list,1) end
        end
        if not wire.alive then e.pos=point end
    end
    if fresh then self:Emit("onWorld",world) end
    self:Emit("onSnapshot",world,packet)
    self:Emit("onAbilityState",{cooldowns=packet.cooldowns or {}})
    if world.roundComplete and not self.victoryShown then
        self.victoryShown=true;self.pendingVictory=nil
        self:Emit("onVictory",world.winnerId,world)
    end
end
function Client:Update(dt,getHeading)
    local world=self.world
    if not world or self.destroyed then return end
    dt=math.clamp(dt,0,.1)
    local localEntity=world.entities[1]
    local running=world.roomState=="running" and localEntity and localEntity.alive
    if running and self.predicted then
        local heading=getHeading and getHeading(localEntity)
        if Protocol.IsFinite(heading) then self.desiredHeading=heading end
        self.predicted.targetHeading=self.desiredHeading or self.predicted.targetHeading
        self.inputTimer+=dt
        if self.inputTimer>=.05 and self.ready then
            self.inputTimer=0;self.sequence+=1
            self.inputRemote:FireServer({seq=self.sequence,heading=self.predicted.targetHeading})
        end
        -- A stalled network freezes presentation after a short grace period.
        -- It never continues predicting captures or moving across an old arena.
        if clock()-(self.lastReceive or 0)<.6 then
            local left=dt
            while left>0 do local step=math.min(left,1/60);Movement.Step(self.predicted,step,self.cfg,world.grid.half);left-=step end
        end
        self.correction*=math.exp(-14*dt)
        localEntity.pos=self.predicted.pos+self.correction
        localEntity.heading=angle(localEntity.heading,self.predicted.heading,1-math.exp(-20*dt))
    end
    local renderTime=clock()-(self.cfg.MultiplayerInterpolationDelay or .12)
    for id,list in pairs(self.samples) do
        local e=world.entities[id]
        if e and e.alive and #list>0 then
            local a,b=list[1],list[#list]
            for i=2,#list do if list[i].time>=renderTime then a=list[i-1];b=list[i];break end end
            local span=b.time-a.time
            local t=span>0 and math.clamp((renderTime-a.time)/span,0,1) or 1
            local point=a.pos:Lerp(b.pos,t)
            if renderTime>b.time and span>0 and world.roomState=="running" then
                point=b.pos+(b.pos-a.pos)*(math.min(renderTime-b.time,.1)/span)
            end
            e.pos=point;e.heading=angle(a.heading,b.heading,t)
        end
    end
end
function Client:GetWorld() return self.world end
function Client:Destroy()
    if self.destroyed then return end
    self.destroyed=true
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    table.clear(self.connections);self.world=nil
end
return Client
