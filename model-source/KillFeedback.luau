-- Runtime-generated kill-streak callouts. No TweenService churn per kill:
-- just two critically damped springs and a short fade updated each frame.
local KillFeedback = {}
KillFeedback.__index = KillFeedback

local STAGES = {"ELIMINATED", "DOUBLE KILL", "TRIPLE KILL", "QUADRA KILL", "ACE!"}

local INK = Color3.fromRGB(36, 46, 61)
local WHITE = Color3.fromRGB(255, 255, 255)
local YELLOW = Color3.fromRGB(255, 214, 105)

local function make(parent, class, name, properties)
    local inst = Instance.new(class)
    inst.Name = name
    for key, value in pairs(properties) do inst[key] = value end
    inst.Parent = parent
    return inst
end

local function text(parent, name, textValue, size, color, weight, z)
    return make(parent, "TextLabel", name, {
        BackgroundTransparency = 1,
        Text = textValue,
        TextColor3 = color,
        TextStrokeColor3 = INK,
        TextStrokeTransparency = 0.42,
        Font = weight or Enum.Font.GothamBlack,
        TextScaled = false,
        TextSize = size,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = z,
    })
end

local function spring(x, velocity, target, omega, dt)
    local decay = math.exp(-omega * dt)
    local delta = x - target
    local impulse = (velocity + delta * omega) * dt
    return target + (delta + impulse) * decay,
        (velocity - impulse * omega) * decay
end

function KillFeedback.new(screen, cfg)
    local self = setmetatable({}, KillFeedback)
    self.cfg = cfg
    self.age = 0
    self.clock, self.lastKill, self.combo = 0, -math.huge, 0
    self.alive = false
    self.scaleValue = 1
    self.scaleVelocity = 0
    self.offset = 0
    self.offsetVelocity = 0
    self.streak = 0

    self.layer = make(screen, "Frame", "KillFeedbackLayer", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 60,
        Active = false,
    })
    self.group = make(self.layer, "Frame", "KillAnnouncement", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.25, 0),
        Size = UDim2.fromOffset(390, 136),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 61,
    })
    self.scale = make(self.group, "UIScale", "PopSpring", {Scale = 1})
    self.shadow = text(self.group, "TypeShadow", "ELIMINATED", 34, INK,
        Enum.Font.GothamBlack, 62)
    self.shadow.Position = UDim2.fromOffset(3, 5)
    self.shadow.Size = UDim2.new(1, 0, 0, 66)
    self.shadow.TextStrokeTransparency = 1
    self.shadow.TextTransparency = 0.82

    self.primary = text(self.group, "Callout", "ELIMINATED", 34, WHITE,
        Enum.Font.GothamBlack, 63)
    self.primary.Size = UDim2.new(1, 0, 0, 66)
    self.primary.TextStrokeTransparency = 0.08
    self.primary.TextStrokeColor3 = INK

    self.subtitle = text(self.group, "Streak", "1ST KILL", 17, YELLOW,
        Enum.Font.GothamBlack, 63)
    self.subtitle.Position = UDim2.fromOffset(0, 62)
    self.subtitle.Size = UDim2.new(1, 0, 0, 28)

    self.victim = text(self.group, "Victim", "", 13,
        Color3.fromRGB(241, 249, 245), Enum.Font.GothamBold, 63)
    self.victim.Position = UDim2.fromOffset(0, 89)
    self.victim.Size = UDim2.new(1, 0, 0, 25)

    local function sparkle(name, x, y, symbol)
        local obj = text(self.group, name, symbol, 24, YELLOW,
            Enum.Font.GothamBlack, 62)
        obj.Position = UDim2.new(0.5, x, 0, y)
        obj.Size = UDim2.fromOffset(25, 25)
        obj.Visible = false
        return obj
    end
    self.sparks = {
        sparkle("SparkA", -158, 4, "✦"),
        sparkle("SparkB", 147, 18, "✦"),
        sparkle("SparkC", -134, 75, "✧"),
        sparkle("SparkD", 128, 80, "✧"),
    }
    return self
end

function KillFeedback:Reset()
    self.alive = false
    self.streak = 0
    self.combo, self.lastKill = 0, -math.huge
    self.age = 0
    self.group.Visible = false
end

function KillFeedback:OnKill(victim, killer)
    local count = killer.killStreak or 1
    self.combo = self.clock-self.lastKill <= (self.cfg.KillComboWindowSeconds or 3)
        and (self.combo+1) or 1
    self.lastKill=self.clock
    self.streak = count
    self.age = 0
    self.alive = true
    self.scaleValue = 0.42
    self.scaleVelocity = 16
    self.offset = 35
    self.offsetVelocity = -480

    self.primary.Text = STAGES[self.combo] or "UNSTOPPABLE!"
    self.shadow.Text = self.primary.Text
    self.primary.TextColor3 = (count >= 5 and YELLOW)
        or (count >= 3 and Color3.fromRGB(255, 177, 113))
        or WHITE
    self.subtitle.Text = string.format("%d KILL STREAK", count)
    self.victim.Text = "ELIMINATED  " .. tostring(victim.name)
    self.group.Visible = true
    for _, obj in ipairs(self.sparks) do obj.Visible = count >= 2 end
    self:ApplyOpacity(0)
end

function KillFeedback:ApplyOpacity(fade)
    self.primary.TextTransparency = fade
    self.primary.TextStrokeTransparency = 0.08 + fade * 0.92
    self.shadow.TextTransparency = 0.82 + 0.18 * fade
    self.subtitle.TextTransparency = fade
    self.subtitle.TextStrokeTransparency = 0.35 + fade * 0.65
    self.victim.TextTransparency = fade
    self.victim.TextStrokeTransparency = 0.5 + fade * 0.5
    for _, obj in ipairs(self.sparks) do obj.TextTransparency = fade end
end

function KillFeedback:Update(dt)
    self.clock += math.max(0, dt)
    if not self.alive then return end
    dt = math.clamp(dt, 0, 0.05)
    self.age += dt
    local speed = self.cfg.KillPopupSpring or 17
    self.scaleValue, self.scaleVelocity = spring(self.scaleValue,
        self.scaleVelocity, 1, speed, dt)
    self.offset, self.offsetVelocity = spring(self.offset,
        self.offsetVelocity, 0, speed * 0.8, dt)
    self.scale.Scale = self.cfg.ReducedMotion and 1 or math.clamp(self.scaleValue, 0.35, 1.25)
    self.group.Position = UDim2.new(0.5, 0, 0.235, self.cfg.ReducedMotion and 0 or self.offset)

    local duration = self.cfg.KillPopupDuration or 1.65
    if self.age > duration then
        local alpha = math.clamp((self.age - duration) / 0.35, 0, 1)
        self:ApplyOpacity(alpha)
        if alpha >= 1 then
            self.alive = false
            self.group.Visible = false
        end
    end
    local size = self.layer.AbsoluteSize
    self.scale.Scale *= math.clamp(math.min(size.X / 420, size.Y / 460), 0.56, 1)
end

function KillFeedback:Destroy()
    if self.layer then self.layer:Destroy() end
end

return KillFeedback
