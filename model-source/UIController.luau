-- Paintland V8: purposeful arcade HUD, created entirely at runtime.
-- Tight hierarchy, legible responsive type, restrained motion and no full-screen dashboard cards.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MinimapController = require(script.Parent.MinimapController)
local LeaderboardService = require(script.Parent.LeaderboardService)
local HUDCanvas = require(script.Parent.HUDCanvas)
local LeaderboardController = require(script.Parent.LeaderboardController)

local UI = {}
UI.__index = UI

local INK = Color3.fromRGB(43, 43, 91)
local SECONDARY = Color3.fromRGB(101, 91, 124)
local PAPER = Color3.fromRGB(255, 250, 240)
local WHITE = Color3.fromRGB(255, 255, 255)
local YELLOW = Color3.fromRGB(164, 235, 93)
local LINE = Color3.fromRGB(210, 224, 217)

local function create(parent, kind, name, props)
    local object = Instance.new(kind)
    object.Name = name
    for k,v in pairs(props or {}) do object[k] = v end
    object.Parent = parent
    return object
end
local function box(parent, name, color, opacity, z)
    return create(parent, "Frame", name, {
        BorderSizePixel = 0, BackgroundColor3 = color or PAPER,
        BackgroundTransparency = opacity or 0, ZIndex = z or 21,
    })
end
local function corner(obj, px)
    return create(obj, "UICorner", "Corners", {CornerRadius = UDim.new(0,px)})
end
local function stroke(obj, color, thickness, opacity)
    return create(obj, "UIStroke", "Outline", {
        Color = color or LINE, Thickness = thickness or 1,
        Transparency = opacity or 0,
    })
end
local function label(parent, name, value, font, size, color, z)
    return create(parent, "TextLabel", name, {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = value, Font = font, TextSize = size,
        TextColor3 = color or INK, TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = z or 25,
    })
end
local function action(parent, name, value, color)
    local b = create(parent, "TextButton", name, {
        BorderSizePixel = 0, BackgroundColor3 = color,
        TextColor3 = INK, Text = value,
        Font = Enum.Font.GothamBlack, TextSize = 21,
        AutoButtonColor = true, ZIndex = 46,
    })
    corner(b, 13)
    return b
end
local function animate(instance, duration, goal)
    TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out), goal):Play()
end

function UI.new(renderer, cfg, callbacks)
    local self = setmetatable({}, UI)
    self.renderer, self.cfg, self.callbacks = renderer, cfg, callbacks
    self.mode, self.skin, self.best, self.toastVersion = "menu", 1, 0, 0
    local screen = renderer.screen
    local hud = box(screen, "HUD", WHITE, 1, 20)
    hud.Size = UDim2.fromScale(1, 1)
    self.hud = hud

    -- V13: unobtrusive flat CanvasGroup indicator; no stats card or heavy pill.
    self.progress = HUDCanvas.new(hud, cfg)

    -- Reference-style compact arcade rankings with cached Roblox headshots.
    self.leaderboard = LeaderboardController.new(hud,cfg)
    -- Compact skull / kill score, matching the reference without a stats card.
    self.killCounter = label(hud,"KillCounter","☠  0",Enum.Font.GothamBlack,19,
        Color3.fromRGB(55,45,156),34)
    self.killCounter.Position=UDim2.fromOffset(16,112)
    self.killCounter.Size=UDim2.fromOffset(100,26)
    self.killCounter.TextStrokeColor3=WHITE
    self.killCounter.TextStrokeTransparency=0.08
    self.killCounter.TextXAlignment=Enum.TextXAlignment.Left

    local toastHolder = box(hud, "ToastHolder", WHITE, 1, 35)
    toastHolder.AnchorPoint = Vector2.new(0.5,0)
    toastHolder.Position = UDim2.fromScale(0.5,0.135)
    toastHolder.Size = UDim2.fromOffset(360,45)
    local toast = label(toastHolder,"Notice","",Enum.Font.GothamBlack,19,INK,36)
    toast.Size = UDim2.fromScale(1,1)
    toast.TextStrokeColor3 = WHITE
    toast.TextStrokeTransparency = 0.38
    toast.TextTransparency = 1
    self.toast = toast
    self.minimap = MinimapController.new(cfg,hud,renderer)

    -- Start menu: typography and one clear primary action, not nested dashboards.
    local overlay = box(screen,"MenuOverlay",Color3.fromRGB(42,38,80),0.25,40)
    overlay.Size = UDim2.fromScale(1,1)
    self.overlay = overlay
    local vignette = box(overlay,"Focus",PAPER,0.02,41)
    vignette.AnchorPoint = Vector2.new(0.5,0.5)
    vignette.Position = UDim2.fromScale(0.5,0.49)
    vignette.Size = UDim2.fromOffset(420,349)
    corner(vignette,23)
    stroke(vignette,Color3.fromRGB(94,68,152),3,0)
    create(vignette,"UIGradient","MenuGradient",{
        Rotation=90,
        Color=ColorSequence.new(Color3.fromRGB(255,253,243),Color3.fromRGB(241,230,255))
    })
    self.card = vignette
    local scale = create(vignette,"UIScale","AdaptiveScale",{Scale=1})
    self.menuScale = scale

    local logoShadow = label(vignette,"LogoShadow","PAINTLAND",Enum.Font.GothamBlack,48,Color3.fromRGB(85,67,155),43)
    logoShadow.Position = UDim2.fromOffset(0,28)
    logoShadow.Size = UDim2.new(1,0,0,61)
    local title = label(vignette,"Title","PAINTLAND",Enum.Font.GothamBlack,48,Color3.fromRGB(244,85,132),44)
    title.TextStrokeColor3=Color3.fromRGB(255,255,255)
    title.TextStrokeTransparency=0.1
    title.Position = UDim2.fromOffset(-2,25)
    title.Size = UDim2.new(1,4,0,61)
    self.title,self.titleShadow = title,logoShadow
    local subtitle = label(vignette,"Subtitle","STEAL THE TURF. RULE THE ARENA.",Enum.Font.GothamBold,13,SECONDARY,44)
    subtitle.Position = UDim2.fromOffset(12,89)
    subtitle.Size = UDim2.new(1,-24,0,23)
    self.subtitle = subtitle

    local skinTitle = label(vignette,"ChooseColor","PICK YOUR COLOR",Enum.Font.GothamBold,12,SECONDARY,44)
    skinTitle.Position = UDim2.fromOffset(0,145)
    skinTitle.Size = UDim2.new(1,0,0,20)
    self.skinTitle = skinTitle
    self.skins = {}
    for i=1,6 do
        local swatch = action(vignette,"Color"..i,"",cfg.Colors[i])
        swatch.Size = UDim2.fromOffset(34,34)
        swatch.Position = UDim2.fromOffset(72+(i-1)*48,174)
        corner(swatch,19)
        local outline = stroke(swatch,INK, i==1 and 3 or 1, i==1 and 0 or .75)
        self.skins[i] = {button=swatch,stroke=outline}
        swatch.Activated:Connect(function()
            self.skin = i
            for j,item in ipairs(self.skins) do
                animate(item.stroke,0.15,{Thickness=j==i and 3 or 1,Transparency=j==i and 0 or .75})
            end
        end)
    end
    local play = action(vignette,"Play","PLAY NOW",YELLOW)
    play.AnchorPoint = Vector2.new(0.5,0)
    play.Position = UDim2.fromOffset(210,237)
    play.Size = UDim2.fromOffset(274,59)
    play.TextSize = 23
    stroke(play,Color3.fromRGB(53,97,67),3,0)
    play.Activated:Connect(function()
        if self.mode == "menu" or self.mode == "win" then
            if callbacks.onPlay then callbacks.onPlay(self.skin) end
        end
    end)
    play.MouseEnter:Connect(function() animate(play,.15,{BackgroundColor3=Color3.fromRGB(193,250,126)}) end)
    play.MouseLeave:Connect(function() animate(play,.15,{BackgroundColor3=YELLOW}) end)
    self.play=play
    local help = label(vignette,"Help","MOUSE / TOUCH / WASD / CONTROLLER",Enum.Font.GothamMedium,11,SECONDARY,44)
    help.Position = UDim2.fromOffset(12,304)
    help.Size = UDim2.new(1,-24,0,19)
    self.help = help

    self.resize = renderer.viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Resize()
    end)
    self:SetMode("menu")
    task.defer(function()
        if screen.Parent then self:Resize() end
    end)
    return self
end

function UI:Resize()
    local s = self.renderer.viewport.AbsoluteSize
    if s.X < 1 or s.Y < 1 then return end
    local small = UserInputService.TouchEnabled or s.X < 730
    self.progress:Resize(s)
    self.leaderboard:Resize(s)
    self.killCounter.Position=UDim2.fromOffset(small and 13 or 22,small and 113 or 135)
    self.killCounter.TextSize=small and 16 or 21
    self.menuScale.Scale = math.clamp(math.min((s.X-24)/420,(s.Y-24)/349),0.55,1)
    self.toast.Size = UDim2.fromOffset(math.min(s.X-24,360),42)
    self.minimap:Resize(s)
end

function UI:NewRun()
    self.best = 0
    self.progress:Reset()
end

function UI:SetMode(mode)
    self.mode=mode
    -- Victory has a dedicated results screen; never show the old menu card.
    self.overlay.Visible = mode == "menu" or mode == "win"
    self.hud.Visible = mode ~= "menu"
    local showColor = mode=="menu" or mode=="win"
    self.skinTitle.Visible = showColor
    for _,s in ipairs(self.skins) do s.button.Visible = showColor end
    self.play.Visible = mode ~= "revive" and mode ~= "dead"
    if mode=="menu" then
        self.title.Text="PAINTLAND"
        self.subtitle.Text="STEAL THE TURF. RULE THE ARENA."
        self.play.Text="PLAY NOW"
        self.help.Text="MOUSE / TOUCH / WASD / CONTROLLER"
    elseif mode=="win" then
        self.title.Text="ALL YOURS!"
        self.subtitle.Text="100% OF THE MAP CAPTURED"
        self.play.Text="PLAY AGAIN"
        self.help.Text="ONE MORE ROUND?"
    end
    self.titleShadow.Text = self.title.Text
end

function UI:Toast(message,color)
    self.toastVersion += 1
    local id=self.toastVersion
    self.toast.Text = message
    self.toast.TextColor3 = color or INK
    self.toast.TextTransparency = 0
    self.toast.Position=UDim2.fromOffset(0,5)
    animate(self.toast,0.3,{Position=UDim2.fromOffset(0,0)})
    task.delay(0.8,function()
        if id~=self.toastVersion or not self.toast.Parent then return end
        animate(self.toast,.35,{TextTransparency=1})
    end)
end

function UI:Update(world)
    local player=world.entities[1]
    if not player then return end
    local total=world.grid.playableTotal
    local value = world.completed and 100
        or ((world.grid.counts[1] or 0) / math.max(1, total) * 100)
    self.best=math.max(self.best,value)
    self.progress:Update(value, player.color)
    self.killCounter.Text=string.format("☠  %d",player.kills or 0)
    local ordered,leader=LeaderboardService.Get(world)
    self.renderer:SetLeader(leader and leader.id or nil)
    self.minimap:UpdateStats(world)
    self.leaderboard:Update(ordered,leader,world)
    -- World:CheckVictory handles the atomic win transition. The UI must not
    -- trigger a second end-state transition from a delayed refresh.

end

function UI:Destroy()
    if self.resize then self.resize:Disconnect() end
    self.progress:Destroy()
    self.leaderboard:Destroy()
    self.minimap:Destroy()
end
return UI
