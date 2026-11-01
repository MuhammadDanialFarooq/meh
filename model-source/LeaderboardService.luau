local Leaderboard = {}

function Leaderboard.Get(world)
    local ranked = table.clone(world.entities)
    table.sort(ranked, function(a, b)
        local ac, bc = world.grid.counts[a.id] or 0, world.grid.counts[b.id] or 0
        if ac ~= bc then return ac > bc end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.id < b.id
    end)
    local first = ranked[1]
    local leader = first and first.alive and (world.grid.counts[first.id] or 0) > 0 and first or nil
    return ranked, leader
end

return Leaderboard
