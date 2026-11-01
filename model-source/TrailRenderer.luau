-- V20: all exposed trails are anchored 3D Workspace parts, never GUI Frames.
-- Each life/trail gets its own generation; pooled segments cannot survive respawn.
local TrailRenderer = {}
TrailRenderer.__index = TrailRenderer

local TRAIL_Y = 0.51
local TRAIL_HEIGHT = 0.09

local function makeSegment(parent)
    local p = Instance.new("Part")
    p.Name = "TrailStrip"
    p.Anchored = true
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic
    p.Size = Vector3.new(1, TRAIL_HEIGHT, 1)
    p.Transparency = 1
    p.Parent = parent
    return p
end

local function makeCap(parent)
    local p = makeSegment(parent)
    p.Name = "TrailRoundedJoint"
    p.Shape = Enum.PartType.Ball
    return p
end

function TrailRenderer.new(folder, config)
    return setmetatable({folder = folder, cfg = config,
        pools = {}, versions = {}, generations = {}, grid = nil}, TrailRenderer)
end

function TrailRenderer:Clear(id)
    local pool = self.pools[id]
    if pool then
        for _, p in ipairs(pool.segments) do p:Destroy() end
        for _, p in ipairs(pool.caps) do p:Destroy() end
    end
    self.pools[id] = nil
    self.versions[id] = nil
    self.generations[id] = nil
end

function TrailRenderer:Reset()
    for id in pairs(self.pools) do self:Clear(id) end
    self.folder:ClearAllChildren()
    self.pools, self.versions, self.generations = {}, {}, {}
end

local function placeStrip(p, a, b, color, thickness, maxSpan)
    local offset = b - a
    local length = offset.Magnitude
    if length < 0.06 or length > maxSpan then
        p.Transparency = 1
        return
    end
    local start3 = Vector3.new(a.X, TRAIL_Y, a.Y)
    local finish3 = Vector3.new(b.X, TRAIL_Y, b.Y)
    local direction = finish3 - start3
    p.Color = color
    p.Size = Vector3.new(thickness, TRAIL_HEIGHT, length + thickness * 0.12)
    p.CFrame = CFrame.lookAt((start3 + finish3) * 0.5, finish3)
    p.Transparency = 0
end

local function placeCap(p, a, color, thickness)
    p.Color = color
    p.Size = Vector3.new(thickness, TRAIL_HEIGHT + 0.01, thickness)
    p.Position = Vector3.new(a.X, TRAIL_Y, a.Y)
    p.Transparency = 0
end

local function ensure(pool, key, index, folder, factory)
    local part = pool[key][index]
    if not part then
        part = factory(folder)
        pool[key][index] = part
    end
    return part
end

function TrailRenderer:Render(entity)
    local id = entity.id
    if not entity.alive or not entity.drawing or #entity.nodes == 0 or
        (self.grid and self.grid:GetOwnerAt(entity.pos) == id) or
        (not entity.isHuman and self.cfg.ShowBotTrails == false) then
        if self.pools[id] then self:Clear(id) end
        return
    end

    local generation = tostring(entity.spawnRevision or 0) .. ":" .. tostring(entity.trailGeneration or 0)
    if self.generations[id] ~= generation then
        self:Clear(id)
        self.generations[id] = generation
    end
    local pool = self.pools[id]
    if not pool then
        pool = {segments = {}, caps = {}}
        self.pools[id] = pool
    end

    local nodes = entity.nodes
    local needed = #nodes -- static nodes plus the changing endpoint
    local maxSpan = math.max(15, (self.cfg.TrailSpacing or 3.5) * 5)
    local thick = self.cfg.TrailThickness or 3.3
    if self.versions[id] ~= entity.visualVersion then
        for i = 2, #nodes do
            placeStrip(ensure(pool, "segments", i - 1, self.folder, makeSegment),
                nodes[i - 1], nodes[i], entity.darkColor, thick, maxSpan)
            placeCap(ensure(pool, "caps", i - 1, self.folder, makeCap),
                nodes[i - 1], entity.darkColor, thick)
        end
        self.versions[id] = entity.visualVersion
    end
    placeStrip(ensure(pool, "segments", needed, self.folder, makeSegment),
        nodes[#nodes], entity.pos, entity.darkColor, thick, maxSpan)
    placeCap(ensure(pool, "caps", needed, self.folder, makeCap),
        nodes[#nodes], entity.darkColor, thick)

    -- Remove excess parts after a path shrinks or its generation is replaced.
    for i = #pool.segments, needed + 1, -1 do
        pool.segments[i]:Destroy(); pool.segments[i] = nil
    end
    for i = #pool.caps, needed + 1, -1 do
        pool.caps[i]:Destroy(); pool.caps[i] = nil
    end
end

return TrailRenderer
