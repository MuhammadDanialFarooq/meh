-- V41: cream arcade panels, a slime mascot and native-size multiplayer controls.
local Fonts=require(script.Parent.Fonts)
local TweenService=game:GetService("TweenService")
local ButtonEffects=require(script.Parent.ButtonEffects)
local Menu={}
Menu.__index=Menu
local INK=Color3.fromRGB(35,32,65)
local WHITE=Color3.fromRGB(248,252,255)
local MUTED=Color3.fromRGB(80,76,103)
local MINT=Color3.fromRGB(149,244,76)
local NAMES={"MINT","CORAL","SKY","VIOLET","GOLD","PINK"}
local function make(parent,class,name,props)
    local o=Instance.new(class);o.Name=name
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent;return o
end
local function frame(parent,name,props)
    props.BorderSizePixel=0;props.Active=false;props.Selectable=false
    return make(parent,"Frame",name,props)
end
local function round(o,r)
    make(o,"UICorner","Corner",{CornerRadius=UDim.new(0,r)})
end
local function stroke(o,color,thickness,alpha)
    return make(o,"UIStroke","Outline",{Color=color,Thickness=thickness,Transparency=alpha or 0,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function label(parent,name,value,size,color,z)
    return make(parent,"TextLabel",name,{Text=value,TextSize=size,TextColor3=color,
        FontFace=Fonts.Bold,BackgroundTransparency=1,BorderSizePixel=0,
        Active=false,Selectable=false,ZIndex=z or 45})
end
local function gradient(o,a,b,rotation)
    make(o,"UIGradient","ColorWash",{Color=ColorSequence.new(a,b),Rotation=rotation or 90})
end
function Menu.new(parent,cfg,onSkin,onPlay,onRooms)
    local self=setmetatable({cfg=cfg,visible=false,tweens={},accent={},motes={},skin=1},Menu)
    self.root=frame(parent,"MenuComposition",{AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.new(.5,0,.5,-12),Size=UDim2.fromOffset(900,420),BackgroundTransparency=1,ZIndex=41})
    self.hero=frame(self.root,"Brand",{BackgroundTransparency=1,ZIndex=42})
    self.badge=label(self.hero,"Eyebrow","THE ARENA IS YOUR CANVAS",10,WHITE)
    self.badge.TextStrokeColor3=INK;self.badge.TextStrokeTransparency=.15
    self.badge.Size=UDim2.new(1,0,0,22)
    self.titleShadow=label(self.hero,"LogoDepth","PAINTLAND",54,Color3.fromRGB(5,14,29),44)
    self.title=label(self.hero,"Logo","PAINTLAND",54,WHITE,45)
    for _,o in ipairs({self.titleShadow,self.title}) do
        o.FontFace=Fonts.Bold;o.Rotation=-4;o.TextScaled=true
        make(o,"UITextSizeConstraint","LogoSize",{MinTextSize=20,MaxTextSize=64})
    end
    gradient(self.title,Color3.fromRGB(255,251,208),Color3.fromRGB(255,209,93),90)
    self.title.TextStrokeColor3=INK;self.title.TextStrokeTransparency=0
    self.subtitle=label(self.hero,"Tagline","Small trail. Big takeover.",15,WHITE)
    self.subtitle.FontFace=Fonts.Regular
    self.subtitle.TextStrokeColor3=INK;self.subtitle.TextStrokeTransparency=.2
    self.subtitle.Size=UDim2.new(1,0,0,24)
    -- A tiny diorama: raised painted tiles, a square trail, and a block mascot.
    self.art=frame(self.hero,"TerritoryIllustration",{AnchorPoint=Vector2.new(.5,.5),
        Size=UDim2.fromOffset(304,158),BackgroundColor3=Color3.fromRGB(255,250,231),BackgroundTransparency=0,Rotation=-7,ZIndex=42})
    round(self.art,35);stroke(self.art,INK,3)
    self.artScale=make(self.art,"UIScale","FitIllustration",{Scale=1})
    for y=1,5 do for x=1,10 do
        local owned=(x>=2 and x<=5 and y>=2 and y<=4)
        local trail=(x>=5 and x<=9 and y==2) or (x==9 and y>=2 and y<=4)
        local color=(owned or trail) and cfg.Colors[1] or Color3.fromRGB(245,234,207)
        local shadow=frame(self.art,"TileDepth",{Position=UDim2.fromOffset((x-1)*30,(y-1)*28+10),
            Size=UDim2.fromOffset(26,26),BackgroundColor3=Color3.fromRGB(205,185,149),ZIndex=42})
        round(shadow,5)
        local tile=frame(self.art,"PaintTile",{Position=UDim2.fromOffset((x-1)*30,(y-1)*28+4),
            Size=UDim2.fromOffset(26,26),BackgroundColor3=color,BackgroundTransparency=owned and .05 or (trail and .12 or .3),ZIndex=43})
        round(tile,5)
        if owned or trail then table.insert(self.accent,tile) end
    end end
    self.mascot=frame(self.art,"PaintRunner",{AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromOffset(233,91),Size=UDim2.fromOffset(70,64),BackgroundColor3=cfg.Colors[1],ZIndex=46})
    round(self.mascot,32);stroke(self.mascot,INK,2)
    gradient(self.mascot,WHITE,Color3.fromRGB(157,179,192))
    table.insert(self.accent,self.mascot)
    for _,x in ipairs({23,48}) do
        local eye=frame(self.mascot,"Eye",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x,27),
            Size=UDim2.fromOffset(15,22),BackgroundColor3=WHITE,ZIndex=47})
        round(eye,10)
        local pupil=frame(eye,"Pupil",{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(7,12),BackgroundColor3=INK,ZIndex=48})
        round(pupil,5)
    end
    for i=1,5 do
        local p=frame(self.art,"FloatingPaint",{AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromOffset(20+i*49, i%2==0 and -8 or 152),Size=UDim2.fromOffset(i%2==0 and 8 or 6,8),
            Rotation=i*22,BackgroundColor3=cfg.Colors[i],BackgroundTransparency=.12,ZIndex=44})
        round(p,2);self.motes[i]={gui=p,position=p.Position}
    end
    self.panel=frame(self.root,"LaunchPanel",{BackgroundColor3=Color3.fromRGB(255,250,235),
        BackgroundTransparency=0,Size=UDim2.fromOffset(360,264),ZIndex=44})
    round(self.panel,24);stroke(self.panel,INK,3)
    gradient(self.panel,Color3.fromRGB(255,255,255),Color3.fromRGB(245,227,195))
    local edge=frame(self.panel,"TopAccent",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),
        Size=UDim2.new(1,-48,0,3),BackgroundColor3=MINT,ZIndex=45})
    round(edge,2)
    self.skinTitle=label(self.panel,"ChooseColor","CHOOSE YOUR COLOR",11,MUTED)
    self.skinTitle.Position=UDim2.fromOffset(20,19);self.skinTitle.Size=UDim2.new(1,-115,0,22)
    self.skinTitle.TextXAlignment=Enum.TextXAlignment.Left
    self.colorName=label(self.panel,"SelectedColor",NAMES[1],10,INK)
    self.colorName.AnchorPoint=Vector2.new(1,0);self.colorName.Position=UDim2.new(1,-20,0,19)
    self.colorName.Size=UDim2.fromOffset(80,22);self.colorName.TextXAlignment=Enum.TextXAlignment.Right
    self.skins={}
    for i=1,6 do
        local b=make(self.panel,"TextButton","Color"..i,{Text=i==1 and "✓" or "",TextSize=23,
            FontFace=Fonts.Bold,TextColor3=INK,BorderSizePixel=0,AutoButtonColor=false,
            Active=true,Selectable=true,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(44,44),
            BackgroundColor3=cfg.Colors[i],ZIndex=46})
        round(b,22);gradient(b,WHITE,Color3.fromRGB(190,202,225))
        local outline=stroke(b,i==1 and WHITE or cfg.Colors[i],i==1 and 3 or 1)
        self.skins[i]={button=b,stroke=outline}
        b.Activated:Connect(function() self:Select(i);onSkin(i) end)
    end
    self.play=make(self.panel,"TextButton","Play",{Text="PLAY NOW   →",TextSize=23,
        FontFace=Fonts.Bold,TextColor3=INK,BorderSizePixel=0,AutoButtonColor=false,
        Active=true,Selectable=true,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.new(1,-32,0,64),
        BackgroundColor3=MINT,ZIndex=46})
    round(self.play,18);stroke(self.play,INK,3)
    gradient(self.play,WHITE,Color3.fromRGB(170,224,90))
    self.playBase=frame(self.panel,"PlayDepth",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.new(1,-32,0,64),
        BackgroundColor3=Color3.fromRGB(62,111,45),ZIndex=45})
    round(self.playBase,18)
    self.play.Activated:Connect(onPlay)
    self.help=label(self.panel,"HowToPlay","Close a loop. Claim the land.\nCut a trail. Take the lead.",12,MUTED)
    self.help.FontFace=Fonts.Regular;self.help.TextWrapped=true
    self.help.Position=UDim2.fromOffset(16,201);self.help.Size=UDim2.new(1,-32,0,42)
    self.roomButtons={}
    if onRooms and cfg.MultiplayerEnabled~=false then
        self.help.Visible=false
        for i,action in ipairs({"create","join"}) do
            local b=make(self.panel,"TextButton",action=="create" and "CreateRoom" or "JoinRoom",{
                AnchorPoint=Vector2.new(.5,.5),Size=UDim2.new(.5,-24,0,44),
                Position=UDim2.new(i==1 and .25 or .75,i==1 and 4 or -4,0,222),
                BackgroundColor3=i==1 and Color3.fromRGB(151,211,255) or Color3.fromRGB(202,176,255),
                Text=i==1 and "CREATE ROOM" or "JOIN ROOM",FontFace=Fonts.Bold,TextSize=11,
                TextColor3=INK,AutoButtonColor=false,BorderSizePixel=0,Active=true,Selectable=true,ZIndex=46})
            round(b,13);stroke(b,INK,2);ButtonEffects.Bind(b,cfg)
            b.Activated:Connect(function() if self.visible then onRooms(action) end end)
            table.insert(self.roomButtons,b)
        end
    end
    self.footer=label(self.root,"ModeLabel",cfg.MultiplayerEnabled~=false and "QUICK PLAY  /  PRIVATE ROOMS" or "SOLO ARENA  /  ENDLESS COLOR",9,WHITE)
    self.footer.TextStrokeColor3=INK;self.footer.TextStrokeTransparency=.1
    self.footer.FontFace=Fonts.Regular
    self.footer.AnchorPoint=Vector2.new(.5,0);self.footer.Size=UDim2.fromOffset(280,18)
    self:Resize(Vector2.new(1280,720))
    return self
end
function Menu:Select(index)
    self.skin=index
    for i,v in ipairs(self.skins) do
        v.button.Text=i==index and "✓" or ""
        v.stroke.Thickness=i==index and 3 or 1
        v.stroke.Color=i==index and WHITE or self.cfg.Colors[i]
    end
    for _,tile in ipairs(self.accent) do tile.BackgroundColor3=self.cfg.Colors[index] end
    self.colorName.Text=NAMES[index];self.colorName.TextColor3=self.cfg.Colors[index]
end
function Menu:StopMotion()
    for _,t in ipairs(self.tweens) do t:Cancel() end
    table.clear(self.tweens)
    for _,p in ipairs(self.motes) do p.gui.Position=p.position end
end
function Menu:StartMotion()
    if self.cfg.ReducedMotion then return end
    for i,p in ipairs(self.motes) do
        local t=TweenService:Create(p.gui,TweenInfo.new(1.6+i*.13,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
            {Position=UDim2.new(p.position.X.Scale,p.position.X.Offset,p.position.Y.Scale,p.position.Y.Offset-8)})
        table.insert(self.tweens,t);t:Play()
    end
end
function Menu:Show(visible)
    if self.visible==visible then return end
    self.visible=visible;self.root.Visible=visible
    self:StopMotion()
    -- Visibility on the actual button also resets the shared interaction state.
    self.play.Visible=visible
    for _,b in ipairs(self.roomButtons) do b.Visible=visible end
    for _,v in ipairs(self.skins) do v.button.Visible=visible end
    self.hero.Position=self.heroRest or self.hero.Position
    self.panel.Position=self.panelRest or self.panel.Position
    if visible then
        if not self.cfg.ReducedMotion then
            for _,item in ipairs({self.hero,self.panel}) do
                local goal=item.Position
                item.Position=UDim2.new(goal.X.Scale,goal.X.Offset,goal.Y.Scale,goal.Y.Offset+12)
                local t=TweenService:Create(item,TweenInfo.new(.32,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=goal})
                table.insert(self.tweens,t);t:Play()
            end
        end
        self:StartMotion()
    end
end
function Menu:Resize(size)
    if size.X<1 or size.Y<1 then return end
    if self.lastWidth==size.X and self.lastHeight==size.Y then return end
    self.lastWidth=size.X;self.lastHeight=size.Y
    self:StopMotion()
    local wide=size.X>=568 and size.X/size.Y>1.4
    local width=math.min(wide and 900 or 440,size.X-(wide and 40 or 24))
    local height=wide and math.min(420,size.Y-96) or math.min(560,size.Y-96)
    height=math.max(264,height)
    self.root.Size=UDim2.fromOffset(width,height)
    local panelWidth=wide and (size.X<620 and 296 or (size.X<900 and 320 or 360)) or width
    self.panel.Size=UDim2.fromOffset(panelWidth,264)
    local heroWidth=wide and width-panelWidth-24 or width
    local heroHeight=wide and height or height-280
    self.hero.Size=UDim2.fromOffset(heroWidth,heroHeight)
    self.hero.Position=UDim2.fromOffset(0,0)
    self.panel.Position=UDim2.fromOffset(wide and width-panelWidth or 0,wide and (height-264)/2 or height-264)
    self.heroRest=self.hero.Position;self.panelRest=self.panel.Position
    self.badge.Position=UDim2.fromOffset(0,wide and 10 or 0)
    local titleY=wide and 37 or 23
    self.title.Position=UDim2.fromOffset(0,titleY);self.title.Size=UDim2.new(1,0,0,66)
    self.titleShadow.Position=UDim2.fromOffset(0,titleY+5);self.titleShadow.Size=self.title.Size
    self.subtitle.Position=UDim2.fromOffset(0,titleY+70)
    local artTop=titleY+104
    local artHeight=math.max(36,heroHeight-artTop-8)
    self.artScale.Scale=math.min(1.15,(heroWidth-16)/304,artHeight/158)
    self.art.Position=UDim2.new(.5,0,0,artTop+artHeight*.5)
    -- Six 44px targets, distributed with equal spacing even at 320px portrait.
    local gap=(panelWidth-24-6*44)/5
    for i,v in ipairs(self.skins) do v.button.Position=UDim2.fromOffset(12+22+(i-1)*(44+gap),78) end
    self.play.Position=UDim2.new(.5,0,0,150)
    self.playBase.Position=UDim2.new(.5,0,0,156)
    self.footer.Position=UDim2.new(.5,0,1,9)
    self.footer.Visible=size.Y-height>=158 or size.X>=900
    if self.visible then self:StartMotion() end
end
function Menu:Destroy()
    self:StopMotion();self.root:Destroy()
end
return Menu
