-- Find truly empty spawn footprints. NEVER fall back to a random occupied cell.
-- Bots wait until an entire fresh territory fits without overwriting other owners.
local SpawnService = {}

local function isAvailable(world, point, ignoreEntity)
    local grid = world.grid
    local cfg = world.cfg
    local x, y = grid:Coords(point)
    local radius = cfg.SpawnRadiusCells + (cfg.SpawnPaddingCells or 2)
    if x - radius < 1 or y - radius < 1
        or x + radius > grid.size or y + radius > grid.size then
        return false
    end

    -- Leave a clear buffer around the starting territory, not just an empty center.
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                local index = grid:Index(x + dx, y + dy)
                if not index or grid.owners[index] ~= 0 then return false end
                -- An active trail is unsafe even when underlying land is unclaimed.
                if world.trails.buckets[index] then return false end
            end
        end
    end

    local separation = math.max((cfg.SpawnRadiusCells + 3) * cfg.Cell,
        cfg.SpawnMinEntityDistance or 36)
    local distanceSquared = separation * separation
    for _, other in ipairs(world.entities) do
        if other ~= ignoreEntity and other.alive then
            local v = other.pos - point
            if v:Dot(v) < distanceSquared then return false end
        end
    end
    return true
end

function SpawnService.Choose(world, entity)
    local grid, rng = world.grid, world.rng
    local radius = world.cfg.SpawnRadiusCells + (world.cfg.SpawnPaddingCells or 2)
    local minCell, maxCell = radius + 1, grid.size - radius
    if minCell > maxCell then return nil end
    local occupied = 0
    for _, count in pairs(grid.counts) do
        occupied += count
    end
    if grid.playableTotal - occupied < math.pi * world.cfg.SpawnRadiusCells^2 then
        return nil
    end

    for _ = 1, 128 do
        local x = rng:NextInteger(minCell, maxCell)
        local y = rng:NextInteger(minCell, maxCell)
        local candidate = grid:Center(x, y)
        if isAvailable(world, candidate, entity) then return candidate end
    end

    -- Scan the entire arena if random sampling misses a rare empty pocket.
    -- A checkerboard phase offset avoids checking identical centers every retry.
    local stride = 2
    local phaseX, phaseY = rng:NextInteger(0, 1), rng:NextInteger(0, 1)
    for y = minCell + phaseY, maxCell, stride do
        for x = minCell + phaseX, maxCell, stride do
            local candidate = grid:Center(x, y)
            if isAvailable(world, candidate, entity) then return candidate end
        end
    end
    return nil
end

-- Revives already paid for must not silently fail when the arena is fully owned.
-- If the player has no surviving land and the arena has no free pocket, make an
-- explicit NEW protected starting island far away from active opponents.
-- This emergency rule is for HUMAN revive only; bots are never force-spawned.
function SpawnService.ChooseEmergencyRevive(world, entity)
    local grid = world.grid
    local radius = world.cfg.SpawnRadiusCells + 2
    local best, bestDistance = nil, -1
    for y = radius + 1, grid.size - radius, 4 do
        for x = radius + 1, grid.size - radius, 4 do
            local point = grid:Center(x, y)
            local closest = math.huge
            for _, other in ipairs(world.entities) do
                if other ~= entity and other.alive then
                    local d = (other.pos - point).Magnitude
                    if d < closest then closest = d end
                end
            end
            if point.Magnitude <= grid.maskRadius - radius * grid.cell and closest > bestDistance then
                best, bestDistance = point, closest
            end
        end
    end
    return best
end

return SpawnService
