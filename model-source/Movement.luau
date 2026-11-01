-- V23: physics and grid agree on the same circular edge.
-- The old radius ended ~3 studs INSIDE the last valid grid cells.
local Movement = {}

function Movement.Step(entity, dt, cfg, half)
    local diff = math.atan2(
        math.sin(entity.targetHeading - entity.heading),
        math.cos(entity.targetHeading - entity.heading)
    )
    entity.heading += math.clamp(diff, -cfg.TurnRate * dt, cfg.TurnRate * dt)

    local velocity = Vector2.new(math.cos(entity.heading), math.sin(entity.heading))
    local speed = entity.isHuman and cfg.PlayerSpeed or cfg.BotSpeed
    local candidate = entity.pos + velocity * speed * dt

    local physicalRadius = cfg.ArenaRadius or (half - cfg.Cell * 2)
    local maskRadius = physicalRadius - (cfg.ArenaBoundaryMargin or cfg.Cell * 0.85)
    -- Player center may reach every valid rim cell, but stays safely on the disk.
    local edge = math.min(physicalRadius - cfg.Cell * 0.5,
        maskRadius + cfg.Cell * 0.35)

    if candidate.Magnitude <= edge then
        entity.pos = candidate
        return
    end

    -- Smoothly slide ALONG the circle instead of bouncing back before reaching
    -- the actual ownership rim. Don't overwrite the user's target heading.
    local normal = candidate.Unit
    local tangential = velocity - normal * velocity:Dot(normal)
    if tangential.Magnitude < 0.1 then
        local sign = entity.edgeDirection or 1
        tangential = Vector2.new(-normal.Y, normal.X) * sign
    else
        entity.edgeDirection = (tangential:Dot(Vector2.new(-normal.Y, normal.X)) >= 0) and 1 or -1
        tangential = tangential.Unit
    end
    local redirected = (tangential - normal * 0.08).Unit
    entity.heading = math.atan2(redirected.Y, redirected.X)
    entity.pos = normal * edge
end

return Movement
