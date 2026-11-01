-- Visual-only, pooled impact effects. This never changes territory or kills.
-- Screen-space drawing follows a world-space origin so the camera may keep moving.
local ArcadeEffects = {}
ArcadeEffects.__index = ArcadeEffects

local function makeLayer(parent)
    local f = Instance.new("Frame")
    f.Name = "ArcadeEffectsLayer"
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Size = UDim2.fromScale(1, 1)
    f.ClipsDescendants = true
    f.Active = false
    f.ZIndex = 18
    f.Parent = parent
    return f
end

local function ring(parent)
    local f = Instance.new("Frame")
    f.Name = "ImpactRipple"
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Visible = false
    f.ZIndex = 18
    f.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = f
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 2.3
    stroke.Parent = f
    return {frame = f, stroke = stroke}
end

local function shard(parent)
    local f = Instance.new("Frame")
    f.Name = "ImpactSpark"
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BorderSizePixel = 0
    f.ZIndex = 19
    f.Visible = false
    f.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.32, 0)
    corner.Parent = f
    return f
end

local function easeOut(t)
    return 1 - (1 - t)^3
end

function ArcadeEffects.new(renderer, cfg)
    return setmetatable({
        renderer = renderer,
        cfg = cfg,
        layer = makeLayer(renderer.screen),
        activeRings = {}, activeSparks = {},
        freeRings = {}, freeSparks = {},
        totalRings = 0, totalSparks = 0,
        rng = Random.new(),
    }, ArcadeEffects)
end

function ArcadeEffects:_project(point, camera)
    local size = self.renderer.viewport.AbsoluteSize
    return size * 0.5 + (point - camera) * self.renderer.pixelScale
end

function ArcadeEffects:_visible(point)
    local world = self.renderer.world
    if not world then return false end
    local size = self.renderer.viewport.AbsoluteSize
    local center = self:_project(point, world.entities[1] and
        (self.currentCamera or world.entities[1].pos) or Vector2.zero)
    return center.X > -120 and center.X < size.X + 120
        and center.Y > -120 and center.Y < size.Y + 120
end

function ArcadeEffects:_ring(point, color, width, duration, delay)
    if self.cfg.ImpactEffectsEnabled == false then return end
    local maxRings = self.cfg.ImpactMaxRings or 14
    if #self.activeRings >= maxRings then return end
    if not self:_visible(point) then return end
    local obj = table.remove(self.freeRings)
    if not obj then
        if self.totalRings >= maxRings then return end
        obj = ring(self.layer)
        self.totalRings += 1
    end
    obj.frame.Visible = false
    obj.stroke.Color = color
    obj.stroke.Thickness = 2.4
    self.activeRings[#self.activeRings + 1] = {
        obj = obj, pos = point, age = -(delay or 0),
        duration = duration, radius = width, color = color,
    }
end

function ArcadeEffects:_burst(point, color, amount, strength)
    if self.cfg.ImpactEffectsEnabled == false or self.cfg.ReducedMotion then return end
    if not self:_visible(point) then return end
    local max = self.cfg.ImpactMaxSparks or 64
    local mobile = self.renderer.viewport.AbsoluteSize.X < 700
    local count = math.min(mobile and math.ceil(amount * 0.55) or amount,
        max - #self.activeSparks)
    for _ = 1, count do
        local obj = table.remove(self.freeSparks)
        if not obj then
            if self.totalSparks >= max then break end
            obj = shard(self.layer)
            self.totalSparks += 1
        end
        local angle = self.rng:NextNumber(0, math.pi * 2)
        local length = self.rng:NextNumber(strength * 0.38, strength)
        local velocity = Vector2.new(math.cos(angle), math.sin(angle)) * length
        local size = self.rng:NextNumber(3, 6)
        obj.BackgroundColor3 = color:Lerp(Color3.new(1,1,1), self.rng:NextNumber(0.15, 0.6))
        obj.Size = UDim2.fromOffset(size, size * self.rng:NextNumber(1, 2.1))
        obj.BackgroundTransparency = 0
        obj.Visible = true
        self.activeSparks[#self.activeSparks + 1] = {
            gui = obj, pos = point, velocity = velocity,
            age = 0, lifetime = self.rng:NextNumber(0.32, 0.65),
            rotation = self.rng:NextNumber(-180, 180),
            spin = self.rng:NextNumber(-240, 240),
        }
    end
end

function ArcadeEffects:Capture(entity, count)
    if not entity or not entity.alive or count <= 0 then return end
    if not entity.isHuman and self.cfg.ImpactShowBotCaptures == false then return end
    local magnitude = math.clamp(math.sqrt(count) / 8, 0.6, 2.1)
    self:_ring(entity.pos, entity.color, 36 * magnitude, 0.48, 0)
    if entity.isHuman then
        self:_ring(entity.pos, Color3.new(1, 1, 1), 26 * magnitude, 0.33, 0.10)
        self:_burst(entity.pos, entity.color, math.clamp(math.floor(4 + math.sqrt(count) * 0.5), 6, 15), 68)
    end
end

function ArcadeEffects:Elimination(victim, killer)
    if not victim then return end
    local color = killer and killer.color or victim.color
    self:_ring(victim.pos, color, 95, 0.51, 0)
    self:_ring(victim.pos, Color3.new(1, 1, 1), 57, 0.37, 0.075)
    local humanInvolved = victim.isHuman or (killer and killer.isHuman)
    self:_burst(victim.pos, color, humanInvolved and 19 or 5,
        humanInvolved and 125 or 55)
end

function ArcadeEffects:Merge(killer, cells, grid)
    if not killer or not cells or not grid then return end
    local chosen = {}
    local seen = 0
    -- Reservoir sample is constant-memory even when a huge region is absorbed.
    for index in pairs(cells) do
        seen += 1
        if #chosen < 3 then
            chosen[#chosen + 1] = index
        else
            local j = self.rng:NextInteger(1, seen)
            if j <= 3 then chosen[j] = index end
        end
    end
    for _, index in ipairs(chosen) do
        local x = (index - 1) % grid.size + 1
        local y = math.floor((index - 1) / grid.size) + 1
        self:_ring(grid:Center(x, y), killer.color, 56, 0.55, 0.06)
    end
end

function ArcadeEffects:Spawn(entity)
    if not entity or not entity.isHuman then return end
    self:_ring(entity.pos, entity.color, 52, 0.46, 0)
end

function ArcadeEffects:Update(dt, cameraPosition)
    self.currentCamera = cameraPosition
    dt = math.clamp(dt or 0, 0, 0.07)
    for i = #self.activeRings, 1, -1 do
        local item = self.activeRings[i]
        item.age += dt
        local t = item.age / item.duration
        if t >= 1 then
            item.obj.frame.Visible = false
            table.insert(self.freeRings, item.obj)
            table.remove(self.activeRings, i)
        elseif t >= 0 then
            local p = self:_project(item.pos, cameraPosition)
            local radius = (8 + item.radius * easeOut(t)) * self.renderer.pixelScale / 4
            local obj = item.obj
            obj.frame.Visible = true
            obj.frame.Position = UDim2.fromOffset(p.X, p.Y)
            obj.frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
            obj.stroke.Transparency = math.clamp(0.16 + t^1.8 * 0.84, 0, 1)
            obj.stroke.Thickness = 2.5 * (1 - t * 0.5)
        end
    end
    for i = #self.activeSparks, 1, -1 do
        local item = self.activeSparks[i]
        item.age += dt
        local t = item.age / item.lifetime
        if t >= 1 then
            item.gui.Visible = false
            table.insert(self.freeSparks, item.gui)
            table.remove(self.activeSparks, i)
        else
            local gravity = Vector2.new(0, 30)
            local travel = item.velocity * (item.age * (1 - t * 0.38)) + gravity * (item.age^2 * 0.5)
            local p = self:_project(item.pos, cameraPosition) + travel
            item.gui.Position = UDim2.fromOffset(p.X, p.Y)
            item.gui.Rotation = item.rotation + item.spin * item.age
            item.gui.BackgroundTransparency = math.clamp(t * t, 0, 1)
        end
    end
end

function ArcadeEffects:Clear()
    self.currentCamera = nil
    for i = #self.activeRings, 1, -1 do
        local item = self.activeRings[i]
        item.obj.frame.Visible = false
        table.insert(self.freeRings, item.obj)
        self.activeRings[i] = nil
    end
    for i = #self.activeSparks, 1, -1 do
        local item = self.activeSparks[i]
        item.gui.Visible = false
        table.insert(self.freeSparks, item.gui)
        self.activeSparks[i] = nil
    end
end

function ArcadeEffects:Destroy()
    self:Clear()
    self.layer:Destroy()
end

return ArcadeEffects
