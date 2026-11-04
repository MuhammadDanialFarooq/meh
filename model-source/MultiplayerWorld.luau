-- Server adapter: the original capture, collision and movement modules remain authoritative.
local World=require(script.Parent.World)
local SpawnService=require(script.Parent.SpawnService)
local TrailMerge=require(script.Parent.TrailMerge)
local MultiplayerWorld={}
MultiplayerWorld.__index=function(_,key) return MultiplayerWorld[key] or World[key] end
function MultiplayerWorld.new(cfg,changed,events,capacity)
    local self=setmetatable(World.new(cfg,changed,events),MultiplayerWorld)
    self.defeats={}
    for id=1,capacity do
        local e=self:NewEntity(id,"",cfg.Colors[(id-1)%#cfg.Colors+1],"Human")
        e.isHuman=true;e.connected=false;e.respawnAt=math.huge
    end
    return self
end
function MultiplayerWorld:AddPlayer(id,userId,name,colorIndex)
    local e=self.entities[id]
    if not e or e.connected then return false end
    self.defeats[id]=nil
    e.userId=userId;e.name=name;e.color=self.cfg.Colors[colorIndex] or self.cfg.Colors[(id-1)%#self.cfg.Colors+1]
    e.darkColor=Color3.new(e.color.R*.79,e.color.G*.79,e.color.B*.79)
    e.connected=true;e.isHuman=true;e.kills=0;e.killStreak=0;e.bestKillStreak=0
    e.equippedAbility="";e.abilityCharge=0;e.characterId="Slime";e.dashRemaining=0;e.dashMultiplier=1
    if not self:Spawn(e) then e.connected=false;e.respawnAt=math.huge;return false end
    return true
end
function MultiplayerWorld:RemovePlayer(id)
    local e=self.entities[id];if not e then return end
    self.defeats[id]=nil
    e.alive=false;e.connected=false;e.respawnAt=math.huge
    e.dashRemaining=0
    self.trails:Clear(e);self.grid:TransferAll(id,0)
end
-- Preserve the contact route before the core clears the victim trail. Land stays
-- reserved during the revive window; only an exhausted/declined life transfers it.
function MultiplayerWorld:Eliminate(victim,killer,cause,claimContext,hit)
    if self.completed or not victim or not victim.alive then return end
    local record={}
    if killer and killer~=victim and killer.alive and killer.connected then
        record.killerId=killer.id;record.killerUserId=killer.userId;record.killerSpawnRevision=killer.spawnRevision
        if cause=="trail" then record.route=TrailMerge.Route(self.grid,killer,victim,hit) end
    end
    self.defeats[victim.id]=record
    return World.Eliminate(self,victim,killer,cause,claimContext,hit)
end
function MultiplayerWorld:CheckVictory()
    if self.completed then return true end
    local total=self.grid.playableTotal
    for _,e in ipairs(self.entities) do
        if e.connected and e.alive and total>0 and (self.grid.counts[e.id] or 0)>=total then
            self.grid:Recount()
            if (self.grid.counts[e.id] or 0)>=total then
                self.completed=true;self.winnerId=e.id
                for _,actor in ipairs(self.entities) do self.trails:Clear(actor) end
                if self.events.onVictory then self.events.onVictory(e,self) end
                return true
            end
        end
    end
    return false
end
-- Normal revival returns to surviving territory. Never overwrite another player
-- when no safe spawn exists; report failure while retaining the server credit.
function MultiplayerWorld:RevivePlayer(id)
    if self.completed then return false end
    local e=self.entities[id]
    if not e or not e.connected or e.alive then return false end
    local point=self.grid:FindNearestOwned(id,e.pos)
    if not point then point=SpawnService.Choose(self,e) end
    if not point then return false end
    self.defeats[id]=nil
    self.trails:Clear(e)
    e.pos=point;e.home=point;e.alive=true;e.respawnAt=math.huge;e.spawnRevision+=1
    e.dashRemaining=0
    if self.grid:GetOwnerAt(point)~=id then self.grid:SpawnLand(id,point) end
    e.heading=self.rng:NextNumber(-math.pi,math.pi);e.targetHeading=e.heading
    if self.events.onSpawn then self.events.onSpawn(e) end
    return true
end
function MultiplayerWorld:ReleaseTerritory(id)
    local e=self.entities[id]
    if not e or e.alive then return end
    local record=self.defeats[id];self.defeats[id]=nil
    local killer=record and record.killerId and self.entities[record.killerId]
    if killer and killer.connected and killer.alive and killer.userId==record.killerUserId
        and killer.spawnRevision==record.killerSpawnRevision and not self.completed then
        local cells,count,_,affected=self.grid:AbsorbDefeatedLand(id,killer.id,record.route)
        -- Never erase a newer, still-exposed trail after the four-second choice.
        if killer.drawing then
            local consumed=true
            for _,index in ipairs(killer.trailCells) do if self.grid.owners[index]~=killer.id then consumed=false;break end end
            if consumed then self.trails:Clear(killer) end
        end
        self:ResolveClaims(killer,cells,affected)
        if count>0 and self.events.onAbsorb then self.events.onAbsorb(killer,count,cells) end
        self:CheckVictory()
    else self.grid:TransferAll(id,0) end
end
return MultiplayerWorld
