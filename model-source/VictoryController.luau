-- V24: exclusive win screen; independent from the main menu / revive UI.
-- A complete round stays visible behind the overlay until PLAY AGAIN is pressed.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Controller = {}
Controller.__index = Controller
local INK = Color3.fromRGB(34, 38, 92)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 204, 64)
local COLORS = {
    Color3.fromRGB(255, 205, 72), Color3.fromRGB(48, 210, 186),
    Color3.fromRGB(160, 105, 255), Color3.fromRGB(255, 107, 166),
    Color3.fromRGB(92, 178, 255),
}
local function create(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function label(parent, text, size, color, font)
    return create("TextLabel", parent, {
        BackgroundTransparency=1, Text=text, Font=font or Enum.Font.GothamBlack,
        TextSize=size, TextColor3=color, TextStrokeTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Center,
    })
end

function Controller.new(screen, cfg, onReplay)
    local self = setmetatable({}, Controller)
    self.cfg, self.onReplay = cfg, onReplay
    self.active, self.confetti, self.elapsed = false, {}, 0
    self.rng = Random.new()
    local overlay = create("Frame", screen, {
        Name="VictoryOverlay", Visible=false, Active=true, ZIndex=90,
        BackgroundColor3=Color3.fromRGB(13, 20, 53), BackgroundTransparency=0.26,
        Size=UDim2.fromScale(1,1), BorderSizePixel=0,
    })
    self.overlay=overlay
    self.confettiLayer=create("Frame",overlay,{
        Name="ConfettiLayer", BackgroundTransparency=1, Size=UDim2.fromScale(1,1),
        ClipsDescendants=true, ZIndex=91, Active=false,
    })
    local card=create("CanvasGroup",overlay,{
        Name="VictoryResult", AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.50), Size=UDim2.fromOffset(384,360),
        BackgroundColor3=WHITE, BorderSizePixel=0, ZIndex=96,
        GroupTransparency=0,
    })
    self.card=card
    create("UICorner",card,{CornerRadius=UDim.new(0,24)})
    create("UIStroke",card,{Color=Color3.fromRGB(61,68,157),Thickness=3})
    create("UIGradient",card,{Rotation=90,Color=ColorSequence.new(
        Color3.fromRGB(255,255,255),Color3.fromRGB(236,245,255))})
    self.scale=create("UIScale",card,{Scale=.72})
    local stripe=create("Frame",card,{
        Name="CelebrationStripe",Size=UDim2.new(1,0,0,14),BorderSizePixel=0,
        BackgroundColor3=Color3.fromRGB(69,210,188),ZIndex=97,
    })
    create("UIGradient",stripe,{Color=ColorSequence.new(
        Color3.fromRGB(54,204,242),Color3.fromRGB(170,88,247))})
    local star=label(card,"✦  ★  ✦",39,GOLD)
    star.Name="VictoryStars";star.Position=UDim2.fromOffset(20,28);star.Size=UDim2.new(1,-40,0,47);star.ZIndex=99
    local title=label(card,"ARENA CONQUERED!",31,INK)
    title.Name="VictoryTitle";title.Position=UDim2.fromOffset(13,73);title.Size=UDim2.new(1,-26,0,44);title.ZIndex=99
    local subtitle=label(card,"YOU OWN THE ENTIRE MAP",14,Color3.fromRGB(79,84,132),Enum.Font.GothamBold)
    subtitle.Position=UDim2.fromOffset(20,118);subtitle.Size=UDim2.new(1,-40,0,24);subtitle.ZIndex=99
    local percent=label(card,"100%",65,Color3.fromRGB(17,174,153))
    percent.Name="VictoryPercent";percent.Position=UDim2.fromOffset(18,149);percent.Size=UDim2.new(1,-36,0,83);percent.ZIndex=99
    percent.TextStrokeColor3=WHITE;percent.TextStrokeTransparency=.35
    self.percent=percent
    local result=label(card,"0 KILLS  •  0 BEST STREAK",14,INK,Enum.Font.GothamBold)
    result.Name="MatchStats";result.Position=UDim2.fromOffset(20,239);result.Size=UDim2.new(1,-40,0,26);result.ZIndex=99
    self.results=result
    local replay=create("TextButton",card,{
        Name="PlayAgain",Text="PLAY AGAIN",Font=Enum.Font.GothamBlack,TextSize=23,
        TextColor3=INK,BackgroundColor3=GOLD,BorderSizePixel=0,
        Position=UDim2.fromOffset(41,283), Size=UDim2.new(1,-82,0,56),
        AutoButtonColor=true,ZIndex=100,
    })
    create("UICorner",replay,{CornerRadius=UDim.new(0,15)})
    create("UIStroke",replay,{Color=Color3.fromRGB(173,117,34),Thickness=2})
    replay.Activated:Connect(function()
        if self.active and self.onReplay then self.onReplay() end
    end)
    self.sizeConnection=overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Resize(overlay.AbsoluteSize)
    end)
    self:Resize(overlay.AbsoluteSize)
    return self
end

function Controller:Resize(viewport)
    if not viewport or viewport.X<=0 or viewport.Y<=0 then return end
    local s=math.clamp(math.min((viewport.X-24)/384,(viewport.Y-28)/360),.48,1)
    if UserInputService.TouchEnabled then s=math.min(s,.91) end
    self.baseScale=s
    if self.active then self.scale.Scale=s end
end

function Controller:Show(world)
    if self.active then return end
    -- Self-heal if another UI layer changed visibility.
    self.overlay.Visible = true
    self.active=true
    self.elapsed=0
    self.overlay.Visible=true
    self.overlay.ZIndex=200
    self.card.ZIndex=206
    self.overlay.BackgroundTransparency=1
    self.card.GroupTransparency=1
    self.scale.Scale=(self.baseScale or 1)*.72
    local e=world.entities[1]
    self.results.Text=string.format("%d KILLS    •    %d BEST STREAK",
        e and e.kills or 0, e and e.bestKillStreak or 0)
    self.percent.Text="100%"
    TweenService:Create(self.overlay,TweenInfo.new(.30,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {BackgroundTransparency=.26}):Play()
    TweenService:Create(self.card,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {GroupTransparency=0}):Play()
    TweenService:Create(self.scale,TweenInfo.new(.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Scale=self.baseScale or 1}):Play()
    for _, item in ipairs(self.confetti) do item.gui:Destroy() end
    table.clear(self.confetti)
    local vp=self.overlay.AbsoluteSize
    local mobile=UserInputService.TouchEnabled or vp.X<730
    local count=mobile and (self.cfg.VictoryConfettiCountMobile or 20)
        or (self.cfg.VictoryConfettiCount or 34)
    if self.cfg.ReducedMotion then count=math.floor(count*.4) end
    for i=1,count do
        local color=COLORS[(i-1)%#COLORS+1]
        local part=create("Frame",self.confettiLayer,{
            Name="VictoryConfetti",BackgroundColor3=color,BorderSizePixel=0,
            Size=UDim2.fromOffset(self.rng:NextInteger(5,9),self.rng:NextInteger(9,17)),
            ZIndex=92,
        })
        table.insert(self.confetti,{gui=part,
            x=self.rng:NextNumber(.02,.98),y=self.rng:NextNumber(-.7,-.06),
            vy=self.rng:NextNumber(.18,.4),vx=self.rng:NextNumber(-.035,.035),
            rot=self.rng:NextNumber(0,360),spin=self.rng:NextNumber(-180,180)})
    end
end

function Controller:Update(dt)
    if not self.active then return end
    self.elapsed+=math.min(dt or 0,.05)
    for _,p in ipairs(self.confetti) do
        p.y+=p.vy*dt
        p.x+=p.vx*dt
        p.rot+=p.spin*dt
        if p.y>1.15 then p.y=-.12;p.x=self.rng:NextNumber(.02,.98) end
        p.gui.Position=UDim2.fromScale(p.x,p.y)
        p.gui.Rotation=p.rot
    end
end

function Controller:Hide()
    self.active=false
    self.overlay.Visible=false
    for _,p in ipairs(self.confetti) do p.gui:Destroy() end
    table.clear(self.confetti)
end

return Controller
