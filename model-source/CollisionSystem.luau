local CollisionSystem = {}

-- Sweep sampling is performed by Trails.Advance. This module only resolves
-- victims in nearby grid buckets, including optional old self-trail hits.
function CollisionSystem.Check(world, mover, position, time)
    if world.completed then return false end
    local victims = world.trails:HitList(mover, position, time)
    for id, hit in pairs(victims) do
        local victim = world.entities[id]
        if victim and victim.alive then
            if victim.id == mover.id then
                world:Eliminate(mover, mover, "self-trail")
                return false
            end
            world:Eliminate(victim, mover, "trail", nil, {index=hit.index,position=position})
        end
    end
    return mover.alive
end

return CollisionSystem
