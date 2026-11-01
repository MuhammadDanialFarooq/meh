-- V14 arcade top meter, inspired by the supplied reference.
-- One transparent CanvasGroup + thin gradient track + milestone tokens.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HUD = {}
HUD.__index = HUD

local function add(parent, cls, name, props)
    local obj = Instance.new(cls)
    obj.Name = name
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local BLUE = Color3.fromRGB(91, 90, 232)
local PURPLE = Color3.fromRGB(102, 55, 212)
local INK = Color3.fromRGB(30, 39, 110)
local WHITE = Color3.fromRGB(255,255,255)

local function round(parent, radius)
    return add(parent, "UICorner", "Round", {CornerRadius=UDim.new(0, radius)})
end
local function outline(parent, thickness, color)
    return add(parent, "UIStroke", "Stroke", {Color=color or INK, Thickness=thickness})
end
local function text(parent, name, content, size, z)
    return add(parent, "TextLabel", name, {
        BackgroundTransparency=1, Text=content, TextSize=size,
        Font=Enum.Font.GothamBlack, TextColor3=WHITE,
        TextStrokeColor3=INK, TextStrokeTransparency=0,
        ZIndex=z or 24,
    })
end

function HUD.new(parent, cfg)
    local self = setmetatable({}, HUD)
    self.cfg = cfg
    self.value = 0
    self.tween = nil
    self.width = 290
    self.canvas = add(parent, "CanvasGroup", "ArcadeProgress", {
        BackgroundTransparency=1,
        AnchorPoint=Vector2.new(0.5,0),
        Position=UDim2.new(0.5,0,0,38),
        Size=UDim2.fromOffset(310,58),
        ZIndex=30, GroupTransparency=0,
        Active=false,
    })
    self.track = add(self.canvas, "Frame", "Track", {
        BackgroundColor3=PURPLE, BorderSizePixel=0,
        Position=UDim2.fromOffset(10,18), Size=UDim2.fromOffset(290,19),
        ClipsDescendants=true, ZIndex=31,
    })
    round(self.track, 11)
    outline(self.track, 2, INK)
    add(self.track, "UIGradient", "TrackGradient", {
        Rotation=0,
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,BLUE),
            ColorSequenceKeypoint.new(1,PURPLE),
        }),
    })
    self.fill = add(self.track,"Frame","CapturedFill",{
        BackgroundColor3=Color3.fromRGB(57, 188, 242),
        BorderSizePixel=0, Size=UDim2.fromScale(0,1), ZIndex=32,
    })
    add(self.fill, "UIGradient", "FillGradient", {
        Rotation=0, Color=ColorSequence.new(
            Color3.fromRGB(29,199,249), Color3.fromRGB(55,111,254)
        ),
    })
    self.percent = text(self.canvas,"Percent","0%",12,38)
    self.percent.Position=UDim2.fromOffset(15,18)
    self.percent.Size=UDim2.fromOffset(55,19)
    self.percent.TextXAlignment=Enum.TextXAlignment.Left

    self.milestones={}
    local specs = {
        {0.08,"C",Color3.fromRGB(255,199,45)},
        {0.18,"G",Color3.fromRGB(255,199,45)},
        {0.42,"◆",Color3.fromRGB(238,62,248)},
        {0.60,"◆",Color3.fromRGB(187,83,254)},
        {0.83,"C",Color3.fromRGB(255,199,45)},
        {0.98,"♛",Color3.fromRGB(255,205,57)},
    }
    for i,spec in ipairs(specs) do
        local badge = add(self.canvas,"Frame","Milestone"..i,{
            AnchorPoint=Vector2.new(0.5,0),
            BackgroundColor3=WHITE,
            BorderSizePixel=0,
            Size=UDim2.fromOffset(23,23), ZIndex=40,
        })
        round(badge,8)
        outline(badge,1.5,INK)
        local disc=add(badge,"Frame","Disc",{
            Position=UDim2.fromOffset(3,3), Size=UDim2.new(1,-6,1,-6),
            BackgroundColor3=spec[3], BorderSizePixel=0, ZIndex=41,
        })
        round(disc,6)
        local glyph=text(disc,"Glyph",spec[2],12,42)
        glyph.Size=UDim2.fromScale(1,1)
        glyph.TextStrokeTransparency=0.45
        add(self.canvas,"Frame","Separator"..i,{
            BackgroundColor3=WHITE, BackgroundTransparency=0.25,
            BorderSizePixel=0, Position=UDim2.new(0,0,0,19),
            Size=UDim2.fromOffset(2,17), ZIndex=33,
        })
        self.milestones[i]={badge=badge,x=spec[1]}
    end
    self:Resize(Vector2.new(900,600))
    self:Reset()
    return self
end

function HUD:Resize(viewport)
    local phone=UserInputService.TouchEnabled or viewport.X<750
    self.width = phone and math.clamp(viewport.X-95,205,258) or 335
    local y=phone and 48 or 48
    self.canvas.Size=UDim2.fromOffset(self.width+20,57)
    self.canvas.Position=UDim2.new(0.5,0,0,y)
    self.track.Position=UDim2.fromOffset(10,21)
    self.track.Size=UDim2.fromOffset(self.width,18)
    self.percent.Position=UDim2.fromOffset(16,21)
    self.percent.TextSize=phone and 11 or 13
    for index, milestone in ipairs(self.milestones) do
        local x=10+self.width*milestone.x
        milestone.badge.Position=UDim2.fromOffset(x,0)
        milestone.badge.Size=UDim2.fromOffset(phone and 21 or 24,phone and 21 or 24)
        local separator=self.canvas:FindFirstChild("Separator"..index)
        if separator then separator.Position=UDim2.fromOffset(x,23) end
    end
end

function HUD:Reset()
    if self.tween then self.tween:Cancel() end
    self.value=0
    self.fill.Size=UDim2.fromScale(0,1)
    self.percent.Text="0%"
end

function HUD:Update(percent,_color)
    local value=math.clamp(percent/100,0,1)
    -- Never display 100.0 until World has truly completed the arena.
    local displayed = (percent >= 100) and 100 or math.min(99.9, percent)
    self.percent.Text=string.format("%.1f%%", displayed)
    if math.abs(value-self.value)<0.0001 then return end
    self.value=value
    if self.tween then self.tween:Cancel() end
    self.tween=TweenService:Create(self.fill,
        TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Size=UDim2.fromScale(value,1)})
    self.tween:Play()
end

function HUD:Destroy()
    if self.tween then self.tween:Cancel() end
    self.canvas:Destroy()
end

return HUD
