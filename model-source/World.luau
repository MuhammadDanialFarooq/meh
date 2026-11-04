local Grid = require(script.Parent.Grid)
local TrailMerge = require(script.Parent.TrailMerge)
local Trails = require(script.Parent.Trails)
local Movement = require(script.Parent.Movement)
local BotAI = require(script.Parent.BotAI)
local CollisionSystem = require(script.Parent.CollisionSystem)
local TerritorySystem = require(script.Parent.TerritorySystem)
local SpawnService = require(script.Parent.SpawnService)

local World = {}
World.__index = World

local function dark(color)
    return Color3.new(color.R * 0.79, color.G * 0.79, color.B * 0.79)
end

function World.new(cfg, onChanged, events)
    local self = setmetatable({}, World)
    self.cfg = cfg
    self.grid = Grid.new(cfg, onChanged)
    self.trails = Trails.new(self.grid, cfg)
    self.ai = BotAI.new(cfg)
    self.entities = {}
    self.time = 0
    self.events = events or {}
    self.completed = false
    self.rng = Random.new()
    return self
end

function World:NewEntity(id, name, color, style)
    local e = {
        id = id, name = name, color = color, darkColor = dark(color),
        personality = style, isHuman = id == 1,
        pos = Vector2.zero, heading = 0, targetHeading = 0,
        alive = false, drawing = false, trailCells = {}, trailSet = {},
        nodes = {}, visualVersion = 0, trailGeneration = 0, spawnRevision = 0, kills = 0, outsideDistance = 0,
        respawnAt = 0, home = Vector2.zero, aiTimer = 0,
        killStreak = 0, bestKillStreak = 0, lastKillAt = -math.huge,
        abilityReadyAt = {}, dashRemaining = 0, dashMultiplier = 1,
    }
    self.entities[id] = e
    return e
end

function World:ChooseSpawn(entity)
    return SpawnService.Choose(self, entity)
end

function World:Spawn(e)
    if self.completed then return false end
    local spawnPosition = self:ChooseSpawn(e)
    if not spawnPosition then
        -- No contested/random fallback: retry when safe unclaimed space exists.
        e.alive = false
        -- Offset retries to avoid scanning the whole map for every bot in one frame.
        e.respawnAt = self.time + (self.cfg.SpawnRetrySeconds or 2.5) + e.id * 0.18
        return false
    end
    self.trails:Clear(e)
    e.spawnRevision += 1
    e.dashRemaining=0
    e.pos = spawnPosition
    e.heading = self.rng:NextNumber(-math.pi, math.pi)
    e.targetHeading = e.heading
    e.home = e.pos
    e.alive = true
    e.respawnAt = 0
    e.aiTimer = 0
    e.waypoints = nil
    self.grid:SpawnLand(e.id, e.pos)
    if not e.isHuman then self.ai:Plan(e, self) end
    if self.events.onSpawn then self.events.onSpawn(e) end
    return true
end

-- Presentation callbacks must not interrupt ownership, elimination or victory.
local function present(callback, ...)
    if not callback then return end
    local ok, err = xpcall(callback, debug.traceback, ...)
    if not ok then warn("[Paintland V27] Presentation callback: " .. tostring(err)) end
end

-- Used by both closed-loop captures and trail joins. Resolve covered heads and
-- exhausted owners, then keep losing owners' largest landmass. Never prune the winner.
function World:ResolveClaims(actor, claimedCells, affectedOwners)
    if not actor.alive or self.completed then return end
    while true do
        local defeated={}
        for _,opponent in ipairs(self.entities) do
            if opponent.alive and opponent.id~=actor.id then
                local headIndex=self.grid:At(opponent.pos)
                if (headIndex and claimedCells[headIndex])
                    or (self.grid.counts[opponent.id] or 0)<=0 then
                    defeated[#defeated+1]=opponent
                end
            end
        end
        if #defeated==0 then break end
        for _,opponent in ipairs(defeated) do
            self:Eliminate(opponent,actor,"enclosed",claimedCells)
        end
    end
    for ownerId in pairs(affectedOwners or {}) do
        local opponent=self.entities[ownerId]
        if ownerId~=actor.id and opponent and opponent.alive then
            self.grid:RemoveDetachedLand(ownerId,opponent.pos)
            if (self.grid.counts[ownerId] or 0)<=0 then
                self:Eliminate(opponent,actor,"enclosed",claimedCells)
            end
        end
    end
end

function World:Eliminate(victim, killer, cause, claimContext, hit)
    -- End-state is immutable: no late trail hit can kill the winner.
    if self.completed then return end
    if not victim or not victim.alive then return end
    local route
    if cause=="trail" and killer and killer~=victim and killer.alive then
        route=TrailMerge.Route(self.grid,killer,victim,hit)
    end
    victim.alive = false
    victim.dashRemaining=0
    victim.killStreak = 0
    victim.lastKillAt = -math.huge
    -- Human's territory remains reserved for the revive choice, unchanged.
    victim.respawnAt = victim.isHuman and math.huge or (self.time + self.cfg.RespawnDelay)
    self.trails:Clear(victim)

    local absorbed, absorbedCount = {}, 0
    local connected, affectedOwners
    if not victim.isHuman then
        if killer and killer ~= victim and killer.alive then
            absorbed, absorbedCount, connected, affectedOwners = self.grid:AbsorbDefeatedLand(victim.id, killer.id, route)
            if connected then
                -- These trail cells are solid land now, not exposed collision targets.
                self.trails:Clear(killer)
            end

            -- NEVER remove the KILLER's territory here. V25's cleanup
            -- could seed from a tiny newly acquired region under the head and
            -- wipe the original majority of the map, causing ~74% -> 0%.
            -- Inherited territory may contain disconnected islands.
            for index in pairs(absorbed) do
                if self.grid.owners[index] ~= killer.id then
                    absorbed[index] = nil
                    absorbedCount -= 1
                elseif claimContext then
                    claimContext[index] = true
                end
            end
        else
            self.grid:TransferAll(victim.id, 0)
        end
    end

    if killer and killer ~= victim then
        killer.kills += 1
        killer.killStreak += 1
        killer.bestKillStreak = math.max(killer.bestKillStreak, killer.killStreak)
        killer.lastKillAt = self.time
    end
    if absorbedCount > 0 and killer then
        -- Purely visual. All owner changes happened instantly above.
        if self.events.onMerge then
            present(self.events.onMerge, killer, victim, absorbed, hit)
        end
        -- Reward transferred territory and the completed route. The killer's
        -- trail is cleared only when that entire exposed route became land.
        if not claimContext and self.events.onAbsorb then
            present(self.events.onAbsorb, killer, absorbedCount, absorbed)
        end
    end
    if self.events.onEliminate then
        present(self.events.onEliminate, victim, killer, cause, hit)
    end
    if connected and killer and killer.alive then
        self:ResolveClaims(killer,absorbed,affectedOwners)
    end
    -- A final trail elimination may transfer the last enemy cells.
    if killer and killer.isHuman then
        -- The last opponent's land can be absorbed during a normal capture
        -- too. Capture will also check after all claims are finalized.
        if not claimContext then self:CheckVictory() end
    end
end

-- Victory is a WORLD state, never inferred later from a HUD refresh.
-- Once the arena is fully owned, the whole match freezes until explicit replay.
function World:CheckVictory()
    if self.completed then return true end
    local player = self.entities[1]
    local total = self.grid.playableTotal
    if not player or not player.alive or total <= 0 then return false end
    -- Cheap fast path: World:Step checks Victory 60 times/second.
    -- Only do a full ownership audit at the very end of the round.
    if (self.grid.counts[player.id] or 0) < total - 2 then return false end
    self.grid:Recount()
    if (self.grid.counts[player.id] or 0) < total then return false end
    self.completed = true
    -- Clear unfinished trails without disturbing the winning territory.
    for _, entity in ipairs(self.entities) do
        self.trails:Clear(entity)
    end
    if self.events.onVictory then
        local ok, err = xpcall(function()
            self.events.onVictory(player, self)
        end, debug.traceback)
        if not ok then
            warn("[Paintland V25] Victory callback error: " .. tostring(err))
        end
    end
    print(string.format("[Paintland V25] VICTORY LOCKED: %d/%d cells", self.grid.counts[player.id] or 0, total))
    return true
end

function World:Capture(e)
    if self.completed then return end
    return TerritorySystem.Capture(self, e)
end

-- Re-enter safely inside existing land. Don't reuse an unfinished trail.
function World:ReviveHuman()
    if self.completed then return false end
    local e = self.entities[1]
    if not e or e.alive then return false end
    self.trails:Clear(e)
    local safePosition = self.grid:FindNearestOwned(e.id, e.pos)
    if not safePosition then
        safePosition = self:ChooseSpawn(e)
        if not safePosition then
            safePosition = SpawnService.ChooseEmergencyRevive(self, e)
        end
        if not safePosition then return false end
        -- Emergency paid revive may overwrite an enemy's area when the
        -- arena is fully occupied. Clean up any disconnected enemy pieces.
        local affected = self.grid:SpawnLand(e.id, safePosition)
        for ownerId in pairs(affected) do
            local opponent = self.entities[ownerId]
            if opponent and opponent.alive then
                if (self.grid.counts[ownerId] or 0) <= 0
                    or self.grid:GetOwnerAt(opponent.pos) == e.id then
                    self:Eliminate(opponent, nil, "enclosed")
                else
                    self.grid:RemoveDetachedLand(ownerId, opponent.pos)
                end
            end
        end
    end
    e.pos = safePosition
    e.home = e.pos
    e.alive = true
    e.respawnAt = 0
    e.spawnRevision += 1
    e.dashRemaining=0
    e.heading = self.rng:NextNumber(-math.pi, math.pi)
    e.targetHeading = e.heading
    if self.events.onSpawn then self.events.onSpawn(e) end
    return true
end

function World:CollisionCheck(mover, position, now)
    if self.completed then return false end
    return CollisionSystem.Check(self, mover, position, now)
end

function World:Step(dt, getHumanHeading)
    if self.completed then return end
    -- Safety net: even a missed capture callback cannot leave a fully owned
    -- arena running long enough for the winner to be eliminated.
    if self:CheckVictory() then return end
    self.time += dt
    for _, e in ipairs(self.entities) do
        if not e.alive then
            if self.time >= e.respawnAt then self:Spawn(e) end
        else
            if e.isHuman then
                local desired = getHumanHeading(e)
                -- No finger / no valid input = stop turning immediately.
                -- Preserve the current heading rather than a stale target angle.
                if desired ~= nil then
                    e.targetHeading = desired
                else
                    e.targetHeading = e.heading
                end
            else
                self.ai:Update(e, self, dt)
            end
            local from = e.pos
            Movement.Step(e, dt, self.cfg, self.grid.half)
            self.trails:Advance(e, from, e.pos, self.time,
                function(p, time)
                    return self:CollisionCheck(e, p, time)
                end,
                function(actor)
                    self:Capture(actor)
                end
            )
            if self.completed then return end
        end
    end
end

function World:Start(playerName, selectedColor)
    local names = table.clone(self.cfg.BotNames)
    for i = #names, 2, -1 do
        local j = self.rng:NextInteger(1, i)
        names[i], names[j] = names[j], names[i]
    end
    self:NewEntity(1, playerName, self.cfg.Colors[selectedColor], "Human")
    self:Spawn(self.entities[1])
    for n = 1, self.cfg.BotCount do
        local id = n + 1
        local color = self.cfg.Colors[(n % (#self.cfg.Colors - 1)) + 2]
        local personality = self.cfg.BotStyles[((n - 1) % #self.cfg.BotStyles) + 1]
        local e = self:NewEntity(id, names[((n - 1) % #names) + 1], color, personality)
        self:Spawn(e)
    end
end

return World
