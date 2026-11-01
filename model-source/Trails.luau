local Trails = {}
Trails.__index = Trails

function Trails.new(grid, cfg)
    return setmetatable({grid = grid, cfg = cfg, buckets = {}}, Trails)
end

function Trails:Clear(e)
    for _, index in ipairs(e.trailCells) do
        local bucket = self.buckets[index]
        if bucket then
            bucket[e.id] = nil
            if not next(bucket) then self.buckets[index] = nil end
        end
    end
    e.trailCells = {}
    e.trailSet = {}
    e.nodes = {}
    e.drawing = false
    e.outsideDistance = 0
    e.visualVersion += 1
    e.trailGeneration = (e.trailGeneration or 0) + 1
end

function Trails:Begin(e, point)
    e.drawing = true
    e.nodes = {point}
    e.outsideDistance = 0
    e.visualVersion += 1
    e.trailGeneration = (e.trailGeneration or 0) + 1
end

function Trails:Register(e, index, p, time)
    if not index or e.trailSet[index] then return end
    e.trailSet[index] = true
    e.trailCells[#e.trailCells + 1] = index
    local bucket = self.buckets[index]
    if not bucket then
        bucket = {}
        self.buckets[index] = bucket
    end
    bucket[e.id] = {point = p, time = time}
end

function Trails:HitList(e, point, time)
    local gx, gy = self.grid:Coords(point)
    local result = {}
    local radiusSquared = self.cfg.HitRadius^2
    for y = gy - 1, gy + 1 do
        for x = gx - 1, gx + 1 do
            local index = self.grid:Index(x, y)
            local bucket = index and self.buckets[index]
            if bucket then
                for owner, sample in pairs(bucket) do
                    if (owner ~= e.id or (self.cfg.SelfTrailKills and time - sample.time > 0.8))
                        and (sample.point - point):Dot(sample.point - point) <= radiusSquared then
                        result[owner] = true
                    end
                end
            end
        end
    end
    return result
end

-- Sample more densely than one territory cell, and bridge diagonal corners
-- to make the flood-filled closed boundary watertight.
function Trails:Advance(e, from, to, time, onSample, onClosed)
    local length = (to - from).Magnitude
    local steps = math.max(1, math.ceil(length / (self.cfg.Cell * 0.23)))
    local last = from
    for n = 1, steps do
        if not e.alive then return end
        local point = from:Lerp(to, n / steps)
        if onSample(point, time) == false then return end
        local index = self.grid:At(point)
        if index then
            if self.grid.owners[index] == e.id then
                if e.drawing then
                    if #e.trailCells >= 3 then
                        onClosed(e)
                    else
                        self:Clear(e)
                    end
                    -- CRITICAL: a closed loop ends this movement sweep.
                    -- Continuing to sample can cause another collision/death
                    -- AFTER World has awarded victory.
                    return
                end
            else
                if not e.drawing then self:Begin(e, last) end
                e.outsideDistance += (point - last).Magnitude
                local ax, ay = self.grid:Coords(last)
                local bx, by = self.grid:Coords(point)
                if ax ~= bx and ay ~= by then
                    self:Register(e, self.grid:Index(bx, ay), point, time)
                    self:Register(e, self.grid:Index(ax, by), point, time)
                end
                self:Register(e, index, point, time)
                local anchor = e.nodes[#e.nodes]
                if (point - anchor).Magnitude >= self.cfg.TrailSpacing then
                    e.nodes[#e.nodes + 1] = point
                    e.visualVersion += 1
                end
            end
        end
        last = point
    end
end

return Trails
