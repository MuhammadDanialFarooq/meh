-- V22: HUD ONLY. One reusable arcade callout for chained territory captures.
-- Individual +percent rewards live in TerritoryVFX's world BillboardGui.
local TweenService = game:GetService("TweenService")

local ExpandCombo = {}
ExpandCombo.__index = ExpandCombo

local function make(parent, kind, name)
    local inst = Instance.new(kind)
    inst.Name = name
    inst.Parent = parent
    return inst
end

function ExpandCombo.new(screen, cfg)
    local self = setmetatable({}, ExpandCombo)
    self.cfg = cfg
    self.streak = 0
    self.lastCapture = -math.huge
    self.generation = 0
    self.tweens = {}

    local holder = make(screen, "Frame", "ExpandComboHUD")
    holder.BackgroundTransparency = 1
    holder.AnchorPoint = Vector2.new(0.5, 0)
    holder.Position = UDim2.new(0.5, 0, 0.16, 0)
    holder.Size = UDim2.fromOffset(410, 105)
    holder.Visible = false
    holder.ZIndex = 90
    self.holder = holder

    local main = make(holder, "TextLabel", "ExpandCallout")
    main.BackgroundTransparency = 1
    main.AnchorPoint = Vector2.new(0.5, 0)
    main.Position = UDim2.fromScale(0.5, 0)
    main.Size = UDim2.new(1, 0, 0, 61)
    main.Font = Enum.Font.GothamBlack
    main.TextSize = 38
    main.Text = "EXPAND!"
    main.TextColor3 = Color3.new(1, 1, 1)
    main.TextStrokeColor3 = Color3.fromRGB(34, 38, 75)
    main.TextStrokeTransparency = 0.05
    main.TextXAlignment = Enum.TextXAlignment.Center
    main.ZIndex = 91
    self.main = main

    local combo = make(holder, "TextLabel", "ComboCounter")
    combo.BackgroundTransparency = 1
    combo.AnchorPoint = Vector2.new(0.5, 0)
    combo.Position = UDim2.new(0.5, 0, 0, 53)
    combo.Size = UDim2.new(1, 0, 0, 28)
    combo.Font = Enum.Font.GothamBlack
    combo.TextSize = 21
    combo.TextColor3 = Color3.fromRGB(255, 224, 91)
    combo.TextStrokeColor3 = Color3.fromRGB(42, 48, 83)
    combo.TextStrokeTransparency = 0.08
    combo.ZIndex = 92
    self.combo = combo

    self.scale = make(holder, "UIScale", "ExpandSpringScale")
    self.scale.Scale = 1
    return self
end

function ExpandCombo:Reset()
    self.generation += 1
    self.streak = 0
    self.lastCapture = -math.huge
    for _, t in ipairs(self.tweens) do t:Cancel() end
    table.clear(self.tweens)
    self.holder.Visible = false
end

function ExpandCombo:Show(percent, color)
    if percent <= 0 then return end
    local now = time()
    local chainSeconds = self.cfg.ExpandComboWindow or 6
    self.streak = now - self.lastCapture <= chainSeconds and self.streak + 1 or 1
    self.streak = math.min(self.streak, self.cfg.ExpandComboMax or 99)
    self.lastCapture = now
    self.generation += 1
    local version = self.generation
    for _, t in ipairs(self.tweens) do t:Cancel() end
    table.clear(self.tweens)

    local name = "EXPAND!"
    if percent >= 1.2 then name = "MASSIVE EXPAND!"
    elseif percent >= 0.65 then name = "AMAZING EXPAND!"
    elseif percent >= 0.32 then name = "GREAT EXPAND!"
    elseif percent >= 0.12 then name = "NICE EXPAND!" end

    self.holder.Visible = true
    self.main.Text = name
    self.main.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.48)
    self.combo.Text = self.streak >= 2 and ("CHAIN  x" .. self.streak) or "TERRITORY CAPTURED"
    self.main.TextTransparency = 0
    self.combo.TextTransparency = 0
    self.main.TextStrokeTransparency = 0.05
    self.combo.TextStrokeTransparency = 0.08
    self.holder.Position = UDim2.new(0.5, 0, 0.16, 13)
    self.scale.Scale = 0.68

    local spring = TweenService:Create(self.scale,
        TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Scale = 1})
    local rise = TweenService:Create(self.holder,
        TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0.16, 0)})
    self.tweens = {spring, rise}
    spring:Play()
    rise:Play()

    task.delay(0.75, function()
        if version ~= self.generation or not self.holder.Parent then return end
        local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local a = TweenService:Create(self.main, fadeInfo,
            {TextTransparency = 1, TextStrokeTransparency = 1})
        local b = TweenService:Create(self.combo, fadeInfo,
            {TextTransparency = 1, TextStrokeTransparency = 1})
        self.tweens = {a, b}
        a:Play()
        b:Play()
        task.delay(0.3, function()
            if version == self.generation and self.holder.Parent then
                self.holder.Visible = false
            end
        end)
    end)
end

function ExpandCombo:Destroy()
    self:Reset()
    if self.holder then self.holder:Destroy() end
end

return ExpandCombo
