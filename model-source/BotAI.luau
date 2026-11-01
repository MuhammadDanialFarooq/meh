local BotAI = {}
BotAI.__index = BotAI

function BotAI.new(cfg)
    return setmetatable({cfg = cfg, rng = Random.new()}, BotAI)
end

function BotAI:Plan(e, world)
    local rng = self.rng
    local home = world.grid:FindNearestOwned(e.id, e.pos)
    if home then e.home = home end
    local angle = rng:NextNumber(-math.pi, math.pi)
    local forward = Vector2.new(math.cos(angle), math.sin(angle))
    local side = Vector2.new(-forward.Y, forward.X)
    local base = e.personality == "Greedy" and 74
        or e.personality == "Defensive" and 35 or 51
    local reach = base * rng:NextNumber(0.82, 1.15)
    local lateral = reach * rng:NextNumber(0.75, 1.05)
    if rng:NextNumber() < 0.5 then lateral = -lateral end
    local bound = world.grid.maskRadius - 14
    local function clamp(v)
        if v.Magnitude > bound then return v.Unit * bound end
        return v
    end
    e.waypoints = {
        clamp(e.home + forward * reach),
        clamp(e.home + forward * reach + side * lateral),
        e.home,
    }
    e.waypoint = 1
    e.aiState = "Expand"
    e.aiStuck = 0
    e.aiLastPosition = e.pos
end

function BotAI:Update(e, world, dt)
    e.aiTimer -= dt
    if e.aiTimer > 0 then return end
    e.aiTimer = self.rng:NextNumber(0.08, 0.15)

    if not e.waypoints or #e.waypoints == 0 then self:Plan(e, world) end
    if world.grid:GetOwnerAt(e.home) ~= e.id then
        local home = world.grid:FindNearestOwned(e.id, e.pos)
        if home then
            e.home = home
            e.waypoints[3] = home
        end
    end

    local target = e.waypoints[e.waypoint]
    if (target - e.pos).Magnitude < 8 then
        e.waypoint += 1
        if e.waypoint > #e.waypoints then
            self:Plan(e, world)
        end
        target = e.waypoints[e.waypoint]
    end
    if e.drawing and e.outsideDistance > 205 then
        e.waypoint = 3
        e.aiState = "Return"
        target = e.home
    end
    if e.drawing and e.waypoint == 3 and world.grid:GetOwnerAt(e.home) ~= e.id then
        target = world.grid:FindNearestOwned(e.id, e.pos) or Vector2.zero
    end

    if not e.drawing and e.waypoint == 3 then
        self:Plan(e, world)
        target = e.waypoints[1]
    end

    if e.personality == "Aggressive" or e.personality == "Opportunist" then
        -- Opportunistic targeting is brief; otherwise triangle loop behavior
        -- produces more believable territory growth than endless chasing.
        if not e.drawing and self.rng:NextNumber() < 0.04 then
            local nearest, distance = nil, 42
            for _, other in ipairs(world.entities) do
                if other.alive and other.id ~= e.id and other.drawing then
                    local d = (other.pos - e.pos).Magnitude
                    if d < distance then nearest, distance = other, d end
                end
            end
            if nearest then target = nearest.pos end
        end
    end

    local off = world.grid.maskRadius - 15
    if e.pos.Magnitude > off then
        target = Vector2.zero
    end
    local dir = target - e.pos
    if dir.Magnitude > 0.5 then
        e.targetHeading = math.atan2(dir.Y, dir.X)
    end

    if (e.pos - e.aiLastPosition).Magnitude < 1 then
        e.aiStuck += e.aiTimer
        if e.aiStuck > 2 then self:Plan(e, world) end
    else
        e.aiStuck = 0
    end
    e.aiLastPosition = e.pos
end

return BotAI
