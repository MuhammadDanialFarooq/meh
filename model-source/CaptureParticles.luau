-- Cosmetic-only particle system. Spawns from *actual newly owned grid cells*,
-- and attracts toward the capturing actor as the camera moves. GUI is fully runtime-built.
-- Small bounded object pool; no per-particle tweens/connections or physics instances.
local CaptureParticles = {}
CaptureParticles.__index = CaptureParticles

local function makeParticle(parent)
    local body = Instance.new("Frame")
    body.Name = "LandSpark"
    body.AnchorPoint = Vector2.new(0.5, 0.5)
    body.BorderSizePixel = 0
    body.ZIndex = 16
    body.Visible = false
    body.Parent = parent
    local round = Instance.new("UICorner")
    round.CornerRadius = UDim.new(0.28, 0)
    round.Parent = body
    return body
end

function CaptureParticles.new(renderer, cfg)
    local layer = Instance.new("Frame")
    layer.Name = "CaptureParticleLayer"
    layer.BackgroundTransparency = 1
    layer.BorderSizePixel = 0
    layer.Size = UDim2.fromScale(1, 1)
    layer.ClipsDescendants = true
    layer.ZIndex = 15
    layer.Parent = renderer.screen
    return setmetatable({
        cfg = cfg,
        renderer = renderer,
        layer = layer,
        active = {},
        free = {},
        rng = Random.new(),
        total = 0,
    }, CaptureParticles)
end

function CaptureParticles:_get()
    local object = table.remove(self.free)
    if not object and self.total < (self.cfg.CaptureParticlePoolLimit or 96) then
        object = makeParticle(self.layer)
        self.total += 1
    end
    return object
end

function CaptureParticles:_recycle(index)
    local particle = self.active[index]
    particle.gui.Visible = false
    table.insert(self.free, particle.gui)
    local last = #self.active
    self.active[index] = self.active[last]
    self.active[last] = nil
end

function CaptureParticles:Clear()
    for i = #self.active, 1, -1 do self:_recycle(i) end
end

function CaptureParticles:Emit(entity, grid, changedCells, cameraPosition)
    if not self.cfg.CaptureParticlesEnabled or not entity.alive then return end
    if type(changedCells) ~= "table" then return end
    local desired = entity.isHuman
        and (self.cfg.CaptureParticlesPlayerCount or 19)
        or (self.cfg.CaptureParticlesBotCount or 6)
    if desired < 1 then return end

    local maxDistance = self.cfg.CaptureParticleMaxDistance or 100
    local possible = {}
    local visited = 0
    local rng = self.rng
    -- Uniform reservoir sample: fast, capped memory, independent of size of capture.
    for index in pairs(changedCells) do
        local x = (index - 1) % grid.size + 1
        local y = math.floor((index - 1) / grid.size) + 1
        local source = grid:Center(x, y)
        if (source - entity.pos).Magnitude <= maxDistance then
            visited += 1
            if #possible < desired then
                possible[#possible + 1] = source
            else
                local swap = rng:NextInteger(1, visited)
                if swap <= desired then possible[swap] = source end
            end
        end
    end
    if #possible == 0 then return end

    local viewport = self.renderer.viewport
    local size = viewport.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end
    for _, source in ipairs(possible) do
        local screenStart = size * 0.5 + (source - cameraPosition) * self.renderer.pixelScale
        if screenStart.X >= -24 and screenStart.X <= size.X + 24
            and screenStart.Y >= -24 and screenStart.Y <= size.Y + 24 then
            local gui = self:_get()
            if not gui then break end
            local baseSize = rng:NextNumber(4.5, 8)
            gui.BackgroundColor3 = entity.color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0.14, 0.48))
            gui.Rotation = rng:NextInteger(-30, 30)
            gui.BackgroundTransparency = 0.08
            gui.Size = UDim2.fromOffset(baseSize, baseSize)
            gui.Position = UDim2.fromOffset(screenStart.X, screenStart.Y)
            gui.Visible = true
            self.active[#self.active + 1] = {
                gui = gui,
                source = source,
                target = entity,
                age = -rng:NextNumber(0, 0.10),
                duration = rng:NextNumber(0.40, 0.73),
                bend = rng:NextNumber(-21, 21),
                baseSize = baseSize,
            }
        end
    end
end

function CaptureParticles:Update(dt, cameraPosition)
    if #self.active == 0 then return end
    dt = math.clamp(dt, 0, 0.07)
    local viewport = self.renderer.viewport.AbsoluteSize
    local scale = self.renderer.pixelScale
    for i = #self.active, 1, -1 do
        local p = self.active[i]
        p.age += dt
        if p.age > p.duration or not p.target.alive then
            self:_recycle(i)
        elseif p.age >= 0 then
            p.gui.Visible = true
            local t = math.clamp(p.age / p.duration, 0, 1)
            local eased = 1 - (1 - t)^3
            local origin = viewport * 0.5 + (p.source - cameraPosition) * scale
            local destination = viewport * 0.5 + (p.target.pos - cameraPosition) * scale
            local d = destination - origin
            local unitNormal = d.Magnitude > 0.1 and Vector2.new(-d.Y, d.X).Unit or Vector2.zero
            local curved = origin:Lerp(destination, eased) + unitNormal * (math.sin(math.pi * t) * p.bend)
            local particleSize = math.max(1, p.baseSize * (1 - t * 0.82))
            p.gui.Position = UDim2.fromOffset(curved.X, curved.Y)
            p.gui.Size = UDim2.fromOffset(particleSize, particleSize)
            p.gui.BackgroundTransparency = math.clamp(0.1 + t^3 * 0.87, 0, 1)
            p.gui.Rotation += dt * 110
        else
            p.gui.Visible = false
        end
    end
end

function CaptureParticles:Destroy()
    self.active = {}
    self.free = {}
    self.layer:Destroy()
end

return CaptureParticles
