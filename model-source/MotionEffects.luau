-- Lightweight local-player motion feedback: breathing halo + tiny dust specks.
-- No parts, no physics, no TweenService or per-frame instance creation.
local MotionEffects = {}
MotionEffects.__index = MotionEffects

local function rounded(gui)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = gui
end

local function frame(parent, name, z)
    local obj = Instance.new("Frame")
    obj.Name = name
    obj.BackgroundTransparency = 1
    obj.BorderSizePixel = 0
    obj.AnchorPoint = Vector2.new(0.5, 0.5)
    obj.ZIndex = z
    obj.Parent = parent
    return obj
end

function MotionEffects.new(renderer, cfg)
    local layer = frame(renderer.screen, "MotionEffectsLayer", 7)
    layer.AnchorPoint = Vector2.zero
    layer.Size = UDim2.fromScale(1, 1)
    layer.Active = false
    layer.ClipsDescendants = true
    local halo = frame(layer, "PlayerHalo", 7)
    rounded(halo)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1.8
    stroke.Transparency = 0.7
    stroke.Parent = halo
    local dust = {}
    for i = 1, (cfg.MotionDustPool or 14) do
        local dot = frame(layer, "Drift" .. i, 7)
        rounded(dot)
        dot.Visible = false
        dust[i] = {gui = dot, age = 999, lifetime = 1}
    end
    return setmetatable({
        renderer = renderer, cfg = cfg,
        layer = layer, halo = halo, stroke = stroke, dust = dust,
        nextDust = 1, accumulated = 0, time = 0, rng = Random.new(),
    }, MotionEffects)
end

function MotionEffects:Clear()
    self.halo.Visible = false
    self.accumulated = 0
    for _, p in ipairs(self.dust) do
        p.age = 999
        p.gui.Visible = false
    end
end

function MotionEffects:Update(dt, entity, camera, enabled)
    dt = math.clamp(dt or 0, 0, 0.07)
    self.time += dt
    local cfg = self.cfg
    if cfg.MotionEffectsEnabled == false or cfg.ReducedMotion or not enabled or not entity or not entity.alive then
        self:Clear()
        return
    end
    local viewport = self.renderer.viewport.AbsoluteSize
    local scale = self.renderer.pixelScale
    local screenPos = viewport * 0.5 + (entity.pos - camera) * scale
    local haloSize = (7.2 * scale) + 13 + math.sin(self.time * 4.5) * 2
    self.halo.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
    self.halo.Size = UDim2.fromOffset(haloSize, haloSize)
    self.halo.Visible = true
    self.stroke.Color = entity.color:Lerp(Color3.new(1, 1, 1), 0.35)
    self.stroke.Transparency = entity.drawing and 0.44 or 0.76

    if entity.drawing then
        self.accumulated += dt
        local interval = cfg.MotionDustInterval or 0.095
        if self.accumulated > interval then
            self.accumulated %= interval
            local p = self.dust[self.nextDust]
            self.nextDust = self.nextDust % #self.dust + 1
            p.age = 0
            p.lifetime = self.rng:NextNumber(0.27, 0.52)
            local behind = Vector2.new(math.cos(entity.heading), math.sin(entity.heading))
            p.pos = entity.pos - behind * self.rng:NextNumber(4, 7)
            p.wind = Vector2.new(-behind.Y, behind.X) * self.rng:NextNumber(-16, 16)
            p.size = self.rng:NextNumber(2.5, 4.2)
            p.gui.BackgroundColor3 = entity.color:Lerp(Color3.new(1,1,1), 0.4)
            p.gui.Visible = true
        end
    else
        self.accumulated = 0
    end

    for _, p in ipairs(self.dust) do
        if p.age < p.lifetime then
            p.age += dt
            if p.age >= p.lifetime then
                p.gui.Visible = false
            else
                local t = p.age / p.lifetime
                local loc = viewport * 0.5 + (p.pos - camera) * scale
                    + p.wind * p.age + Vector2.new(0, -17) * p.age
                local size = p.size * (1 - t * 0.6)
                p.gui.Position = UDim2.fromOffset(loc.X, loc.Y)
                p.gui.Size = UDim2.fromOffset(size, size)
                p.gui.BackgroundTransparency = math.clamp(0.25 + t * 0.75, 0, 1)
            end
        end
    end
end

function MotionEffects:Destroy()
    self.layer:Destroy()
end

return MotionEffects
