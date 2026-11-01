local Grid = {}
Grid.__index = Grid

function Grid.new(cfg, onChange)
    local self = setmetatable({}, Grid)
    self.cfg = cfg
    self.size = cfg.Grid
    self.cell = cfg.Cell
    self.total = cfg.Grid * cfg.Grid
    self.half = cfg.Grid * cfg.Cell / 2
    self.radius = cfg.ArenaRadius or (self.half - self.cell * 2)
    self.maskRadius = self.radius - (cfg.ArenaBoundaryMargin or self.cell * 0.85)
    self.mask = table.create(self.total, false)
    self.owners = table.create(self.total, -1)
    self.playableTotal = 0
    for y = 1, self.size do
        for x = 1, self.size do
            local index = (y - 1) * self.size + x
            local center = self:Center(x, y)
            if center:Dot(center) <= self.maskRadius * self.maskRadius then
                self.mask[index] = true
                self.owners[index] = 0
                self.playableTotal += 1
            end
        end
    end
    self.counts = {}
    self.changed = onChange
    return self
end

function Grid:Index(x, y)
    if x < 1 or x > self.size or y < 1 or y > self.size then return nil end
    local index = (y - 1) * self.size + x
    return self.mask[index] and index or nil
end

function Grid:Coords(p)
    return math.floor((p.X + self.half) / self.cell) + 1,
        math.floor((p.Y + self.half) / self.cell) + 1
end

-- A point can lie inside the round arena while its square grid cell's
-- CENTER falls outside the playable mask. Snap to the nearest valid rim cell.
-- Otherwise the last edge cells are impossible to step on or claim.
function Grid:At(p)
    local x, y = self:Coords(p)
    local exact = self:Index(x, y)
    if exact then return exact end
    if p.Magnitude > self.radius + self.cell * 0.25 then return nil end

    local nearest, nearestDist
    for dy = -2, 2 do
        for dx = -2, 2 do
            local i = self:Index(x + dx, y + dy)
            if i then
                local c = self:Center(x + dx, y + dy)
                local delta = c - p
                local d = delta:Dot(delta)
                if not nearestDist or d < nearestDist then
                    nearest, nearestDist = i, d
                end
            end
        end
    end
    return nearest
end

function Grid:Center(x, y)
    return Vector2.new(-self.half + (x - 0.5) * self.cell,
        -self.half + (y - 0.5) * self.cell)
end

function Grid:GetOwnerAt(p)
    local i = self:At(p)
    return i and self.owners[i] or -1
end

function Grid:Set(index, owner)
    if not index or not self.mask[index] then return false end
    local old = self.owners[index]
    if old == owner then return false end
    self.owners[index] = owner
    if old and old > 0 then self.counts[old] = (self.counts[old] or 0) - 1 end
    if owner > 0 then self.counts[owner] = (self.counts[owner] or 0) + 1 end
    if self.changed then self.changed(index) end
    return true
end

-- Recalculate territory counts from the actual ownership array. Called
-- at end-of-match checks; never trusts HUD or visuals as source of truth.
function Grid:Recount()
    local actual = {}
    for i = 1, self.total do
        if self.mask[i] then
            local owner = self.owners[i]
            if owner and owner > 0 then
                actual[owner] = (actual[owner] or 0) + 1
            end
        end
    end
    local mismatch = false
    for id, count in pairs(actual) do
        if count ~= (self.counts[id] or 0) then mismatch = true; break end
    end
    if not mismatch then
        for id, count in pairs(self.counts) do
            if count ~= (actual[id] or 0) then mismatch = true; break end
        end
    end
    if mismatch then
        warn("[Paintland V26] Grid counters disagreed with ownership; repaired cached counts")
        self.counts = actual
    end
end

-- An owner must have exactly one connected landmass. If an enemy cuts
-- through their land, keep the 4-connected component below their head.
-- If their head is currently OUTSIDE their territory, keep the closest
-- component instead (the one they can realistically return to).
-- Removed pieces become unclaimed, NOT killer-owned islands.
-- All edits use Set() so counts, minimap and renderer stay in sync.
function Grid:RemoveDetachedLand(id, headPosition)
    if (self.counts[id] or 0) <= 0 then return 0 end
    if not headPosition then return 0 end

    local sx, sy = self:Coords(headPosition)
    local seed = self:Index(sx, sy)
    if not seed or self.owners[seed] ~= id then
        -- When the head is drawing an exposed trail, it may be outside
        -- its own territory. Select the closest OWNED cell to its head.
        local bestDistance = math.huge
        seed = nil
        for index = 1, self.total do
            if self.owners[index] == id then
                local x = (index - 1) % self.size + 1
                local y = math.floor((index - 1) / self.size) + 1
                local dx, dy = x - sx, y - sy
                local distance = dx * dx + dy * dy
                if distance < bestDistance then
                    bestDistance = distance
                    seed = index
                end
            end
        end
    end
    if not seed then return 0 end

    local seen = table.create(self.total, false)
    local queue = {seed}
    seen[seed] = true
    local head, tail = 1, 1
    local width = self.size

    local function include(other)
        if self.owners[other] ~= id or seen[other] then return end
        tail += 1
        queue[tail] = other
        seen[other] = true
    end

    while head <= tail do
        local index = queue[head]
        head += 1
        local x = (index - 1) % width + 1
        local y = math.floor((index - 1) / width) + 1
        if x > 1 then include(index - 1) end
        if x < width then include(index + 1) end
        if y > 1 then include(index - width) end
        if y < width then include(index + width) end
    end

    -- Fast exit if all cells of this owner are part of the retained landmass.
    if tail >= (self.counts[id] or 0) then return 0 end

    local removed = 0
    for index = 1, self.total do
        if self.owners[index] == id and not seen[index] then
            self:Set(index, 0)
            removed += 1
        end
    end
    return removed
end

function Grid:SpawnLand(id, position)
    local gx, gy = self:Coords(position)
    local radius = self.cfg.SpawnRadiusCells
    local affectedOwners = {}
    for y = gy - radius, gy + radius do
        for x = gx - radius, gx + radius do
            if (x - gx)^2 + (y - gy)^2 <= radius^2 then
                local index = self:Index(x, y)
                if index then
                    local previous = self.owners[index]
                    if previous and previous > 0 and previous ~= id then
                        affectedOwners[previous] = true
                    end
                    self:Set(index, id)
                end
            end
        end
    end
    return affectedOwners
end

-- Boundary-connected regions are exterior candidates. Interior pockets are
-- always enclosed, even when larger than the remaining outside region.
-- For loops dividing the circular wall, retain the largest boundary region.
function Grid:Capture(id, trailCells)
    local claimed = 0
    local changedCells = {}
    local affectedOwners = {}

    local function claim(index)
        if not index or not self.mask[index] then return end
        local old = self.owners[index]
        if old and old > 0 and old ~= id then
            affectedOwners[old] = true
        end
        if self:Set(index, id) then
            claimed += 1
            changedCells[index] = true
        end
    end

    for _, index in ipairs(trailCells) do
        claim(index)
    end

    local n = self.size
    local visited = table.create(self.total, false)
    local components = {}

    for seed = 1, self.total do
        if self.mask[seed] and self.owners[seed] ~= id and not visited[seed] then
            local component = {cells = {}, size = 0, perimeter = 0}
            local queue = {seed}
            local head, tail = 1, 1
            visited[seed] = true

            -- One visitor per component (not thousands of closures per cell).
            local function visit(nx, ny)
                local other = self:Index(nx, ny)
                if not other then
                    component.perimeter += 1
                elseif self.owners[other] ~= id and not visited[other] then
                    visited[other] = true
                    tail += 1
                    queue[tail] = other
                end
            end

            while head <= tail do
                local index = queue[head]
                head += 1
                component.size += 1
                component.cells[#component.cells + 1] = index

                local x = (index - 1) % n + 1
                local y = math.floor((index - 1) / n) + 1
                visit(x-1, y)
                visit(x+1, y)
                visit(x, y-1)
                visit(x, y+1)
            end
            components[#components + 1] = component
        end
    end

    local exterior = nil
    for i, component in ipairs(components) do
        if component.perimeter > 0 then
            local current = exterior and components[exterior]
            if not current or component.size > current.size
                or (component.size == current.size and component.perimeter > current.perimeter) then
                exterior = i
            end
        end
    end
    for i, component in ipairs(components) do
        if i ~= exterior then
            for _, cellIndex in ipairs(component.cells) do claim(cellIndex) end
        end
    end

    -- The playable mask uses cell CENTERS but the player's physical position
    -- follows a perfect circle. Close shallow neutral gaps along the rim when
    -- the INNER side is already owned by the capturing player. This is not an
    -- artificial 100% score: every filled cell is actually assigned to them.
    self:ClaimBoundaryFringe(id, claim)

    return claimed, changedCells, affectedOwners
end

-- Automatically finish the last ~2 cells of a circular wall when their
-- inward neighbour belongs to this player. Avoid stealing rivals' cells.
-- Operates only on neutral cells and runs after a real loop is completed.
function Grid:ClaimBoundaryFringe(id, claim)
    local maxDepth = (self.cfg.BoundaryAssistDepthCells or 2.5) * self.cell
    local reach = (self.cfg.BoundaryAssistInwardCells or 2) * self.cell
    for pass = 1, 2 do
        local pending = {}
        for i = 1, self.total do
            if self.mask[i] and self.owners[i] == 0 then
                local x = (i - 1) % self.size + 1
                local y = math.floor((i - 1) / self.size) + 1
                local center = self:Center(x,y)
                local radius = center.Magnitude
                if radius > 0.001 and self.maskRadius - radius <= maxDepth then
                    local inward = center.Unit * math.max(0, radius - reach)
                    local ix, iy = self:Coords(inward)
                    local innerIndex = self:Index(ix, iy)
                    if innerIndex and self.owners[innerIndex] == id then
                        pending[#pending + 1] = i
                    end
                end
            end
        end
        if #pending == 0 then break end
        for _, i in ipairs(pending) do claim(i) end
    end
end

-- Defeated land transfers without manufacturing thin neutral corridors.
-- Disconnected inherited islands are valid ownership, just like preserved land.
function Grid:AbsorbDefeatedLand(victimId, killerId)
    local taken, claimedCount = {}, 0
    if victimId == killerId then return taken, 0 end
    if not killerId or killerId <= 0 then
        self:TransferAll(victimId, 0)
        return taken, 0
    end
    for i = 1, self.total do
        if self.owners[i] == victimId and self:Set(i, killerId) then
            taken[i] = true
            claimedCount += 1
        end
    end
    return taken, claimedCount
end

function Grid:TransferAll(fromId, toId)
    for i = 1, self.total do
        if self.owners[i] == fromId then self:Set(i, toId) end
    end
end

function Grid:FindNearestOwned(id, position)
    if (self.counts[id] or 0) <= 0 then return nil end
    local ix, iy = self:Coords(position)
    for radius = 0, self.size do
        local best, bestD
        local function consider(x, y)
            local i = self:Index(x, y)
            if i and self.owners[i] == id then
                local p = self:Center(x, y)
                local d = (p - position).Magnitude
                if not bestD or d < bestD then best, bestD = p, d end
            end
        end
        for x = ix - radius, ix + radius do
            consider(x, iy - radius)
            if radius > 0 then consider(x, iy + radius) end
        end
        for y = iy - radius + 1, iy + radius - 1 do
            consider(ix - radius, y)
            if radius > 0 then consider(ix + radius, y) end
        end
        if best then return best end
    end
    return nil
end

return Grid
