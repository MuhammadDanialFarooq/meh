-- V41: bright victory presentation with native-size actions on phones.
local Fonts=require(script.Parent.Fonts)
local TweenService=game:GetService("TweenService")
local ButtonEffects=require(script.Parent.ButtonEffects)
local Controller={}
Controller.__index=Controller
local INK=Color3.fromRGB(29,34,102)
local WHITE=Color3.new(1,1,1)
local LIME=Color3.fromRGB(153,246,65)
local COLORS={Color3.fromRGB(255,209,79),Color3.fromRGB(80,240,192),Color3.fromRGB(255,125,172),Color3.fromRGB(157,119,255)}
local function make(parent,class,name,props)
    local o=Instance.new(class);o.Name=name
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent;return o
end
local function frame(parent,name,props)
    props.BorderSizePixel=0;props.Active=false;props.Selectable=false
    return make(parent,"Frame",name,props)
end
local function round(o,r) make(o,"UICorner","Corner",{CornerRadius=UDim.new(0,r)}) end
local function stroke(o,c,w) make(o,"UIStroke","Outline",{Color=c,Thickness=w,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,size,color,regular)
    return make(parent,"TextLabel",name,{BackgroundTransparency=1,BorderSizePixel=0,
        FontFace=regular and Fonts.Regular or Fonts.Bold,Text=value,TextSize=size,TextColor3=color or WHITE,
        TextStrokeColor3=INK,TextStrokeTransparency=regular and .6 or 0,Active=false,Selectable=false,ZIndex=206})
end
function Controller.new(screen,cfg,onReplay)
    local self=setmetatable({cfg=cfg,onReplay=onReplay,active=false,confetti={},elapsed=0,tweens={},rng=Random.new()},Controller)
    self.overlay=frame(screen,"VictoryOverlay",{Size=UDim2.fromScale(1,1),Visible=false,BackgroundColor3=WHITE,
        BackgroundTransparency=.06,ZIndex=200})
    self.overlay.Active=true
    make(self.overlay,"UIGradient","BlueSky",{Rotation=40,Color=ColorSequence.new(Color3.fromRGB(20,92,230),Color3.fromRGB(5,204,222))})
    self.confettiLayer=frame(self.overlay,"ConfettiLayer",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=201})
    self.card=frame(self.overlay,"VictoryContent",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(460,480),BackgroundTransparency=1,ZIndex=205})
    self.stars=text(self.card,"Stars","★    ★    ★",35,Color3.fromRGB(255,224,99))
    self.title=text(self.card,"VictoryTitle","ARENA CONQUERED!",34)
    self.title.TextScaled=true
    make(self.title,"UITextSizeConstraint","FitTitle",{MinTextSize=18,MaxTextSize=36})
    self.subtitle=text(self.card,"VictorySubtitle","EVERY LAST TILE. ALL YOURS.",12,WHITE,true)
    self.medallion=frame(self.card,"TerritoryMedallion",{AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=Color3.fromRGB(11,109,185),
        Size=UDim2.fromOffset(220,180),ZIndex=205})
    round(self.medallion,80);stroke(self.medallion,INK,4)
    make(self.medallion,"UIGradient","Aqua",{Rotation=90,Color=ColorSequence.new(WHITE,Color3.fromRGB(95,218,237))})
    self.percent=text(self.medallion,"VictoryPercent","100%",72,WHITE)
    self.percent.Size=UDim2.fromScale(1,.68);self.percent.Position=UDim2.fromScale(0,.05)
    self.percent.TextScaled=true
    make(self.percent,"UITextSizeConstraint","FitPercent",{MinTextSize=24,MaxTextSize=76})
    self.caption=text(self.medallion,"TerritoryLabel","TERRITORY CLAIMED",11,Color3.fromRGB(193,255,237),true)
    self.caption.Position=UDim2.fromScale(0,.72);self.caption.Size=UDim2.fromScale(1,.18)
    self.results=text(self.card,"MatchStats","0 KILLS  •  0 BEST STREAK",12,WHITE,true)
    self.play=make(self.card,"TextButton","PlayAgain",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(300,60),
        Text="PLAY AGAIN",TextSize=23,TextColor3=INK,FontFace=Fonts.Bold,AutoButtonColor=false,
        BackgroundColor3=LIME,BorderSizePixel=0,Active=true,Selectable=true,ZIndex=207})
    round(self.play,18);stroke(self.play,INK,3)
    make(self.play,"UIGradient","ButtonShine",{Rotation=90,Color=ColorSequence.new(WHITE,Color3.fromRGB(169,223,98))})
    ButtonEffects.Bind(self.play,cfg,{play=true})
    self.play.Activated:Connect(function() if self.active and self.onReplay then self.onReplay() end end)
    self.sizeConnection=self.overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Resize(self.overlay.AbsoluteSize) end)
    self:Resize(self.overlay.AbsoluteSize or Vector2.new(1280,720))
    return self
end
function Controller:StopTweens()
    for _,t in ipairs(self.tweens) do t:Cancel() end
    table.clear(self.tweens)
end
function Controller:Resize(viewport)
    if not viewport or viewport.X<1 or viewport.Y<1 then return end
    self:StopTweens()
    self.viewport=viewport
    local wide=viewport.X>=568 and viewport.X/viewport.Y>1.4
    local w=math.min(wide and 720 or 460,viewport.X-32)
    local h=math.min(wide and 320 or 480,viewport.Y-32)
    self.card.Size=UDim2.fromOffset(w,h);self.card.Position=UDim2.fromScale(.5,.5)
    self.stars.Visible=not wide
    self.stars.Position=UDim2.fromOffset(0,0);self.stars.Size=UDim2.new(1,0,0,44)
    self.title.Position=UDim2.fromOffset(0,wide and 0 or 48);self.title.Size=UDim2.new(1,0,0,48)
    self.subtitle.Position=UDim2.fromOffset(0,wide and 49 or 98);self.subtitle.Size=UDim2.new(1,0,0,24)
    if wide then
        local diameter=math.min(180,h-106)
        self.medallion.Size=UDim2.fromOffset(diameter,diameter)
        self.medallion.Position=UDim2.new(.25,0,0,76+diameter/2)
        self.results.Position=UDim2.new(.5,0,0,100);self.results.Size=UDim2.new(.5,0,0,42)
        ButtonEffects.SetSize(self.play,UDim2.new(.5,-16,0,60))
        self.play.Position=UDim2.new(.75,0,0,h-62)
    else
        local diameter=math.min(220,w-48,h-230)
        self.medallion.Size=UDim2.fromOffset(diameter,diameter*.86)
        self.medallion.Position=UDim2.new(.5,0,0,132+diameter*.43)
        self.results.Position=UDim2.new(0,0,1,-113);self.results.Size=UDim2.new(1,0,0,30)
        ButtonEffects.SetSize(self.play,UDim2.new(1,-24,0,60))
        self.play.Position=UDim2.new(.5,0,1,-40)
    end
end
function Controller:Show(world)
    if self.active then return end
    self.active=true;self.elapsed=0;self.overlay.Visible=true
    self:Resize(self.overlay.AbsoluteSize or self.viewport or Vector2.new(1280,720))
    local e=world and world.entities and world.entities[1]
    self.results.Text=string.format("%d KILLS  •  %d BEST STREAK",e and e.kills or 0,e and e.bestKillStreak or 0)
    self.percent.Text="100%"
    if not self.cfg.ReducedMotion then
        self.card.Position=UDim2.new(.5,0,.5,12)
        local t=TweenService:Create(self.card,TweenInfo.new(.3,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.fromScale(.5,.5)})
        table.insert(self.tweens,t);t:Play()
        local count=(self.viewport and self.viewport.X<730) and (self.cfg.VictoryConfettiCountMobile or 20) or (self.cfg.VictoryConfettiCount or 34)
        for i=1,math.clamp(count,0,48) do
            local p=frame(self.confettiLayer,"VictoryConfetti",{BackgroundColor3=COLORS[(i-1)%#COLORS+1],
                Size=UDim2.fromOffset(self.rng:NextInteger(5,9),self.rng:NextInteger(9,17)),ZIndex=201})
            table.insert(self.confetti,{gui=p,x=self.rng:NextNumber(.02,.98),y=self.rng:NextNumber(-.7,-.06),
                vy=self.rng:NextNumber(.18,.4),vx=self.rng:NextNumber(-.035,.035),rot=self.rng:NextNumber(0,360),spin=self.rng:NextNumber(-180,180)})
        end
    end
end
function Controller:Update(dt)
    if not self.active then return end
    dt=math.clamp(dt or 0,0,.1);self.elapsed+=dt
    for _,p in ipairs(self.confetti) do
        p.y+=p.vy*dt;p.x+=p.vx*dt;p.rot+=p.spin*dt
        if p.y>1.15 then p.y=-.12;p.x=self.rng:NextNumber(.02,.98) end
        p.gui.Position=UDim2.fromScale(p.x,p.y);p.gui.Rotation=p.rot
    end
end
function Controller:Hide()
    self.active=false;self.overlay.Visible=false;self:StopTweens()
    for _,p in ipairs(self.confetti) do p.gui:Destroy() end
    table.clear(self.confetti)
end
function Controller:Destroy()
    self:Hide();if self.sizeConnection then self.sizeConnection:Disconnect() end
    self.overlay:Destroy()
end
return Controller
