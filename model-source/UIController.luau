-- V29: ink-and-mint arcade UI; responsive, generated, no image dependencies.
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local MinimapController=require(script.Parent.MinimapController)
local LeaderboardService=require(script.Parent.LeaderboardService)
local HUDCanvas=require(script.Parent.HUDCanvas)
local LeaderboardController=require(script.Parent.LeaderboardController)
local UI={}
UI.__index=UI
local INK=Color3.fromRGB(17,27,43)
local PANEL=Color3.fromRGB(25,39,59)
local WHITE=Color3.fromRGB(243,249,255)
local MUTED=Color3.fromRGB(166,187,205)
local MINT=Color3.fromRGB(82,230,186)
local EDGE=Color3.fromRGB(67,91,117)
local function make(parent,class,name,props)
    local obj=Instance.new(class)
    obj.Name=name
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local function round(obj,px)
    make(obj,"UICorner","Round",{CornerRadius=UDim.new(0,px)})
end
local function edge(obj,color,width)
    return make(obj,"UIStroke","Edge",{Color=color or EDGE,Thickness=width or 1})
end
local function text(parent,name,value,size,color,z)
    return make(parent,"TextLabel",name,{Text=value,TextSize=size,TextColor3=color or WHITE,
        BackgroundTransparency=1,BorderSizePixel=0,Font=Enum.Font.GothamBold,
        ZIndex=z or 44,TextTruncate=Enum.TextTruncate.AtEnd})
end
local function button(parent,name,value,color,z)
    local b=make(parent,"TextButton",name,{Text=value,TextSize=16,Font=Enum.Font.GothamBold,
        TextColor3=INK,BackgroundColor3=color or MINT,BorderSizePixel=0,AutoButtonColor=true,
        ZIndex=z or 46})
    round(b,14)
    return b
end
local function tween(obj,goals)
    TweenService:Create(obj,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goals):Play()
end
function UI.new(renderer,cfg,callbacks)
    local self=setmetatable({renderer=renderer,cfg=cfg,callbacks=callbacks,
        mode="menu",skin=1,best=0,toastVersion=0,muted=cfg.SoundMutedByDefault==true},UI)
    local screen=renderer.screen
    self.hud=make(screen,"Frame","HUD",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=20})
    self.progress=HUDCanvas.new(self.hud,cfg)
    self.leaderboard=LeaderboardController.new(self.hud,cfg)
    self.killCard=make(self.hud,"Frame","Eliminations",{Size=UDim2.fromOffset(142,60),
        Position=UDim2.fromOffset(18,56),BackgroundColor3=PANEL,BackgroundTransparency=.06,
        BorderSizePixel=0,ZIndex=32})
    round(self.killCard,16);edge(self.killCard)
    local kLabel=text(self.killCard,"Caption","ELIMINATIONS",9,MUTED,33)
    kLabel.Position=UDim2.fromOffset(12,8);kLabel.Size=UDim2.new(1,-24,0,16)
    kLabel.TextXAlignment=Enum.TextXAlignment.Left
    self.killCounter=text(self.killCard,"Count","0",23,WHITE,33)
    self.killCounter.Position=UDim2.fromOffset(12,24);self.killCounter.Size=UDim2.fromOffset(118,28)
    self.killCounter.TextXAlignment=Enum.TextXAlignment.Left
    self.toast=text(self.hud,"Notice","",14,WHITE,36)
    self.toast.AnchorPoint=Vector2.new(.5,0)
    self.toast.Position=UDim2.new(.5,0,0,132)
    self.toast.Size=UDim2.fromOffset(320,30)
    self.toast.TextStrokeTransparency=.45
    self.toast.TextStrokeColor3=INK
    self.toast.TextTransparency=1
    self.minimap=MinimapController.new(cfg,self.hud,renderer)

    self.overlay=make(screen,"Frame","MenuOverlay",{Size=UDim2.fromScale(1,1),
        BackgroundColor3=INK,BackgroundTransparency=.08,BorderSizePixel=0,ZIndex=40})
    make(self.overlay,"UIGradient","Atmosphere",{Rotation=35,
        Color=ColorSequence.new(Color3.fromRGB(20,47,61),Color3.fromRGB(25,24,52))})
    self.card=make(self.overlay,"Frame","MenuCard",{AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(420,460),
        BackgroundColor3=PANEL,BorderSizePixel=0,ZIndex=41})
    round(self.card,28);edge(self.card,EDGE)
    self.menuScale=make(self.card,"UIScale","AdaptiveScale",{Scale=1})
    local badge=text(self.card,"Eyebrow","PAINT. CAPTURE. REPEAT.",11,MINT)
    badge.Position=UDim2.fromOffset(24,28);badge.Size=UDim2.fromOffset(372,22)
    self.title=text(self.card,"Title","PAINTLAND",43,WHITE)
    self.title.Position=UDim2.fromOffset(20,57);self.title.Size=UDim2.fromOffset(380,60)
    self.title.Font=Enum.Font.GothamBlack
    self.subtitle=text(self.card,"Subtitle","A little color. A lot of territory.",14,MUTED)
    self.subtitle.Position=UDim2.fromOffset(24,120);self.subtitle.Size=UDim2.fromOffset(372,26)
    local divider=make(self.card,"Frame","Divider",{Position=UDim2.fromOffset(36,170),
        Size=UDim2.fromOffset(348,1),BackgroundColor3=EDGE,BorderSizePixel=0,ZIndex=43})
    self.skinTitle=text(self.card,"ChooseColor","MAKE YOUR MARK",11,MUTED)
    self.skinTitle.Position=UDim2.fromOffset(24,194);self.skinTitle.Size=UDim2.fromOffset(372,22)
    self.skins={}
    for i=1,6 do
        local swatch=button(self.card,"Color"..i,i==1 and "✓" or "",cfg.Colors[i])
        swatch.Position=UDim2.fromOffset(49+(i-1)*55,232)
        swatch.Size=UDim2.fromOffset(44,44)
        swatch.TextColor3=INK;swatch.TextSize=20
        local outline=edge(swatch,i==1 and WHITE or cfg.Colors[i],i==1 and 3 or 1)
        self.skins[i]={button=swatch,stroke=outline}
        swatch.Activated:Connect(function()
            self.skin=i
            for j,view in ipairs(self.skins) do
                view.button.Text=j==i and "✓" or ""
                tween(view.stroke,{Thickness=j==i and 3 or 1,Color=j==i and WHITE or cfg.Colors[j]})
            end
        end)
    end
    self.play=button(self.card,"Play","LET'S PAINT  →",MINT)
    self.play.Position=UDim2.fromOffset(36,311);self.play.Size=UDim2.fromOffset(348,58)
    self.play.TextSize=19
    self.play.Activated:Connect(function()
        if (self.mode=="menu" or self.mode=="win") and callbacks.onPlay then callbacks.onPlay(self.skin) end
    end)
    self.help=text(self.card,"Help","Close a loop to claim land.\nCut a rival's trail to take them out.",12,MUTED)
    self.help.Font=Enum.Font.GothamMedium
    self.help.TextWrapped=true
    self.help.Position=UDim2.fromOffset(32,388);self.help.Size=UDim2.fromOffset(356,42)
    self.soundButton=button(screen,"ToggleSound","SOUND: OFF",PANEL,150)
    self.soundButton.TextColor3=MUTED;self.soundButton.TextSize=11
    self.soundButton.AnchorPoint=Vector2.new(1,1)
    self.soundButton.Position=UDim2.new(1,-18,1,-18)
    self.soundButton.Size=UDim2.fromOffset(132,44)
    edge(self.soundButton)
    self.soundButton.Activated:Connect(function()
        if cfg.SoundEnabled==false then return end
        self.muted=not self.muted
        if callbacks.onSoundToggle then callbacks.onSoundToggle(self.muted) end
        self:UpdateSoundLabel()
    end)
    self:UpdateSoundLabel()
    self.resize=renderer.viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Resize() end)
    self:SetMode("menu")
    task.defer(function() if screen.Parent then self:Resize() end end)
    return self
end
function UI:UpdateSoundLabel()
    local disabled=self.cfg.SoundEnabled==false
    self.soundButton.Text=disabled and "SOUND: DISABLED" or (self.muted and "SOUND: OFF" or "SOUND: ON")
    self.soundButton.TextColor3=(self.muted or disabled) and MUTED or MINT
end
function UI:Resize()
    local s=self.renderer.viewport.AbsoluteSize
    if s.X<1 or s.Y<1 then return end
    local narrow=s.X<900
    self.progress:Resize(s);self.leaderboard:Resize(s);self.minimap:Resize(s)
    self.killCard.Position=UDim2.fromOffset(narrow and 12 or 18,narrow and 168 or 56)
    self.killCard.Size=UDim2.fromOffset(narrow and 116 or 142,60)
    self.killCounter.Size=UDim2.new(1,-24,0,28)
    self.menuScale.Scale=math.min(1,(s.X-32)/420,(s.Y-110)/460)
    self.toast.Size=UDim2.fromOffset(math.min(s.X-24,320),30)
    self.soundButton.Position=UDim2.new(1,-12,1,-12)
    self.soundButton.Size=UDim2.fromOffset(132,44)
end
function UI:NewRun()
    self.best=0;self.progress:Reset()
end
function UI:SetMode(mode)
    self.mode=mode
    self.overlay.Visible=mode=="menu" or mode=="win"
    self.hud.Visible=mode~="menu" and mode~="win"
    self.soundButton.Visible=mode~="revive" -- don't cover the revive action area
    if mode=="menu" then
        self.title.Text="PAINTLAND"
        self.subtitle.Text="A little color. A lot of territory."
        self.play.Text="LET'S PAINT  →"
    elseif mode=="win" then
        self.title.Text="ALL YOURS!"
        self.subtitle.Text="100% of the arena. Every last tile."
        self.play.Text="PAINT AGAIN  →"
    end
end
function UI:Toast(message,color)
    self.toastVersion+=1
    local version=self.toastVersion
    self.toast.Text=message;self.toast.TextColor3=color or WHITE;self.toast.TextTransparency=0
    task.delay(1.2,function()
        if version==self.toastVersion and self.toast.Parent then tween(self.toast,{TextTransparency=1}) end
    end)
end
function UI:Update(world)
    local player=world.entities[1]
    if not player then return end
    local value=world.completed and 100 or (world.grid.counts[1] or 0)/math.max(1,world.grid.playableTotal)*100
    self.best=math.max(self.best,value)
    self.progress:Update(value,player.color)
    self.killCounter.Text=tostring(player.kills or 0)
    local ordered,leader=LeaderboardService.Get(world)
    self.renderer:SetLeader(leader and leader.id or nil)
    self.minimap:UpdateStats(world);self.leaderboard:Update(ordered,leader,world)
end
function UI:Destroy()
    self.toastVersion+=1
    if self.resize then self.resize:Disconnect() end
    self.progress:Destroy();self.leaderboard:Destroy();self.minimap:Destroy()
    self.hud:Destroy();self.overlay:Destroy();self.soundButton:Destroy()
end
return UI
