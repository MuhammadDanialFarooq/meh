-- V39: illustrated main menu and responsive gameplay HUD.
local Fonts=require(script.Parent.Fonts)
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local MinimapController=require(script.Parent.MinimapController)
local LeaderboardService=require(script.Parent.LeaderboardService)
local HUDCanvas=require(script.Parent.HUDCanvas)
local LeaderboardController=require(script.Parent.LeaderboardController)
local ButtonEffects=require(script.Parent.ButtonEffects)
local MainMenu=require(script.Parent.MainMenu)
local ResultsScreen=require(script.Parent.ResultsScreen)
local WalletHUD=require(script.Parent.WalletHUD)
local AbilityHUD=require(script.Parent.AbilityHUD)
local LoadoutMenu=require(script.Parent.LoadoutMenu)
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
        BackgroundTransparency=1,BorderSizePixel=0,FontFace=Fonts.Bold,
        ZIndex=z or 44,TextTruncate=Enum.TextTruncate.AtEnd})
end
local function button(parent,name,value,color,z)
    local b=make(parent,"TextButton",name,{Text=value,TextSize=16,FontFace=Fonts.Bold,
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
    self.wallet=WalletHUD.new(screen,cfg)
    self.abilities=AbilityHUD.new(screen,cfg,function(id) if callbacks.onAbility then callbacks.onAbility(id) end end)
    self.loadout=LoadoutMenu.new(screen,cfg,function(action,id) if callbacks.onLoadout then callbacks.onLoadout(action,id) end end)
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
        BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=40})
    make(self.overlay,"UIGradient","Atmosphere",{Rotation=35,
        Color=ColorSequence.new(Color3.fromRGB(45,154,218),Color3.fromRGB(75,86,194))})
    self.menu=MainMenu.new(self.overlay,cfg,function(index) self.skin=index end,function()
        if not self.loadout.root.Visible and self.wallet.loaded and (self.mode=="menu" or self.mode=="win") and callbacks.onPlay then callbacks.onPlay(self.skin) end
    end,function(action)
        if self.loadout.root.Visible then return end
        if action=="loadout" then self.loadout:Show();return end
        if not self.wallet.loaded then return end
        if self.mode=="menu" and callbacks.onRooms then callbacks.onRooms(action) end
    end)
    self.card=self.menu.root
    for _,key in ipairs({"title","subtitle","badge","skinTitle","skins","play","help"}) do self[key]=self.menu[key] end
    self.results=ResultsScreen.new(screen,cfg,{
        onPlay=function() if self.mode=="defeat" and callbacks.onPlay then callbacks.onPlay(self.skin) end end,
        onMainMenu=function()
            if self.mode~="defeat" then return end
            if callbacks.onMainMenu then callbacks.onMainMenu() end
            self:SetMode("menu")
        end,
    })
    self.defeatOverlay=self.results.root
    self.replay=self.results.play;self.returnMenu=self.results.menuButton
    self.result=self.results.percentLabel;self.defeatDetails=self.results.details
    self.soundButton=button(screen,"ToggleSound","SOUND: OFF",PANEL,150)
    self.soundButton.TextColor3=MUTED;self.soundButton.TextSize=11
    self.soundButton.AnchorPoint=Vector2.new(.5,.5)
    self.soundButton.Position=UDim2.new(1,-84,1,-40)
    ButtonEffects.SetSize(self.soundButton,UDim2.fromOffset(132,44))
    edge(self.soundButton)
    self.soundButton.Activated:Connect(function()
        if cfg.SoundEnabled==false then return end
        self.muted=not self.muted
        if callbacks.onSoundToggle then callbacks.onSoundToggle(self.muted) end
        self:UpdateSoundLabel()
    end)
    for _,view in ipairs(self.skins) do ButtonEffects.Bind(view.button,cfg) end
    ButtonEffects.Bind(self.play,cfg,{play=true,depth=self.menu.playBase})
    for _,b in ipairs({self.soundButton}) do ButtonEffects.Bind(b,cfg) end
    self:UpdateSoundLabel()
    self.resize=renderer.viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Resize() end)
    self:Resize()
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
    self.killCard.Position=UDim2.fromOffset(narrow and 12 or 18,s.Y<350 and 124 or (s.Y<500 and 132 or (narrow and 168 or 56)))
    self.killCard.Size=UDim2.fromOffset(narrow and 116 or 142,60)
    self.killCounter.Size=UDim2.new(1,-24,0,28)
    self.wallet:Resize(s,self.mode)
    self.abilities:Resize(s)
    self.loadout:Resize(s)
    self.menu:Resize(s)
    self.results:Resize(s)
    self.toast.Size=UDim2.fromOffset(math.min(s.X-24,320),30)
    self.toast.Position=UDim2.new(.5,0,0,s.Y<500 and 184 or 132)
    self.soundButton.Position=UDim2.new(1,-78,1,-34)
    ButtonEffects.SetSize(self.soundButton,UDim2.fromOffset(132,44))
end
function UI:NewRun()
    self.best=0;self.defeatStats=nil;self.progress:Reset()
end
function UI:SetMode(mode)
    self.mode=mode
    if mode~="menu" then self.loadout:Hide() end
    self.wallet.root.Visible=mode=="menu" or mode=="playing" or mode=="win"
    self.abilities:SetActive(mode=="playing")
    self.overlay.Visible=mode=="menu" or mode=="win"
    if mode~="defeat" then self.results:Hide() end
    self.hud.Visible=mode~="menu" and mode~="win" and mode~="defeat" and mode~="lobby"

    self.soundButton.Visible=mode~="revive" and mode~="defeat" and mode~="lobby"
    self.title.Text=mode=="win" and "ALL YOURS!" or "PAINTLAND"
    self.menu.titleShadow.Text=self.title.Text
    self.badge.Text=mode=="win" and "100% CONQUERED" or "THE ARENA IS YOUR CANVAS"
    self.subtitle.Text=mode=="win" and "Every last tile. All yours." or "Small trail. Big takeover."
    self.play.Text=mode=="win" and "PAINT AGAIN   →" or "PLAY NOW   →"
    if not self.wallet.loaded then self.play.Text="LOADING CHARACTER…" end
    self.play.Active=self.wallet.loaded
    self.menu:Show(mode=="menu" or mode=="win")
    self:Resize()
end
-- Snapshot at death, before any revive choice or delayed HUD update.
function UI:RecordDefeat(world)
    local player=world.entities[1]
    local count=world.grid.counts[1] or 0
    local total=world.grid.playableTotal
    self.defeatStats={count=count,percent=count/math.max(1,total)*100,
        kills=player and player.kills or 0,color=player and player.color or MINT,
        size=world.grid.size or 1,mask={},cells={}}
    for index=1,(world.grid.total or 0) do
        self.defeatStats.mask[index]=world.grid.mask[index]==true
        self.defeatStats.cells[index]=world.grid.owners[index]==1
    end
end
function UI:ShowDefeat(world)
    if not self.defeatStats then self:RecordDefeat(world) end
    self:SetMode("defeat")
    self.results:Show(self.defeatStats)
end
function UI:SetWallet(data)
    self.wallet:Set(data);self.loadout:SetWallet(data)
    self.play.Active=self.wallet.loaded
    self.play.Text=not self.wallet.loaded and "LOADING CHARACTER…" or (self.mode=="win" and "PAINT AGAIN   →" or "PLAY NOW   →")
    for _,b in ipairs(self.menu.roomButtons) do b.Active=b.Name=="Loadout" or self.wallet.loaded end
end
function UI:SetAbilityState(data)
    self.abilities:SetState(data)
    if data.accepted==false and data.reason then self:Toast(data.reason,Color3.fromRGB(255,225,175)) end
end
function UI:UpdatePresentation(dt)
    self.wallet:Update(dt)
    self.abilities:Update(dt)
    self.loadout:Update(dt)
    self.results:Update(dt)
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
    self.wallet:Destroy()
    self.abilities:Destroy()
    self.loadout:Destroy()
    self.menu:Destroy()
    self.hud:Destroy();self.overlay:Destroy();self.results:Destroy();self.soundButton:Destroy()
end
return UI
