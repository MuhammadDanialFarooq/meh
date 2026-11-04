-- V40: tween Size around a fixed center; never combine this with a button UIScale.
local TweenService=game:GetService("TweenService")
local Effects={}
local bindings=setmetatable({},{__mode="k"})
local function scaled(size,factor)
    return UDim2.new(size.X.Scale*factor,size.X.Offset*factor,size.Y.Scale*factor,size.Y.Offset*factor)
end
function Effects.SetSize(button,size)
    local state=bindings[button]
    if state then
        state.baseSize=size
        state:Animate(state.factor)
    else button.Size=size end
end
function Effects.Bind(button,cfg,options)
    if bindings[button] then return bindings[button] end
    options=options or {}
    local p,s,a=button.Position,button.Size,button.AnchorPoint
    button.Position=UDim2.new(p.X.Scale+s.X.Scale*(.5-a.X),p.X.Offset+s.X.Offset*(.5-a.X),
        p.Y.Scale+s.Y.Scale*(.5-a.Y),p.Y.Offset+s.Y.Offset*(.5-a.Y))
    button.AnchorPoint=Vector2.new(.5,.5);button.AutoButtonColor=false
    local oldScale=button:FindFirstChild("InteractionScale")
    if oldScale then oldScale:Destroy() end
    local state={baseSize=s,depthSize=options.depth and options.depth.Size,factor=1,motion={},fx={},idle={},particles={},connections={},serial=0,
        hovered=false,focused=false,pressed=false,lastBurst=-math.huge,destroyed=false}
    bindings[button]=state
    local function cancel(list)
        for _,t in ipairs(list) do t:Cancel() end
        table.clear(list)
    end
    local function connect(signal,fn)
        table.insert(state.connections,signal:Connect(fn))
    end
    local function visible()
        local ancestor=button
        while ancestor do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
            if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
            ancestor=ancestor.Parent
        end
        return true
    end
    function state:Animate(factor,instant)
        cancel(self.motion)
        if self.destroyed or not button.Active or not visible() then factor=1;instant=true end
        self.factor=cfg.ReducedMotion and 1 or factor
        -- Both UDim components scale, keeping the pixel center fixed at every parent size.
        for _,object in ipairs(options.depth and {button,options.depth} or {button}) do
            local goal=scaled(object==button and self.baseSize or self.depthSize,self.factor)
            if instant or cfg.ReducedMotion then object.Size=goal
            else
                local t=TweenService:Create(object,TweenInfo.new(.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=goal})
                table.insert(self.motion,t);t:Play()
            end
        end
    end
    function state:ClearFX()
        self.serial+=1;cancel(self.fx)
        for _,spark in ipairs(self.particles) do spark.Visible=false end
        if self.slashLayer then self.slashLayer.Visible=false end
    end
    -- Adapted from the supplied UIEffects Shine/Sparkles. No tag observer,
    -- spring or sound-library dependency is required by these local effects.
    function state:StopIdle()
        cancel(self.idle)
        if self.shine then self.shine.Visible=false end
        if self.sparkleLayer then self.sparkleLayer.Visible=false end
    end
    function state:StartIdle()
        if not options.play or self.destroyed or cfg.ReducedMotion or not button.Active or not visible() then return end
        if #self.idle>0 then return end
        if cfg.ButtonSlashEnabled~=false then
            if not self.shine then
                local layer=Instance.new("Frame");layer.Name="PlayShine"
                layer.Size=UDim2.new(1,-12,1,-12);layer.AnchorPoint=Vector2.new(.5,.5);layer.Position=UDim2.fromScale(.5,.5)
                layer.BackgroundTransparency=1;layer.BorderSizePixel=0;layer.ClipsDescendants=true
                layer.Active=false;layer.Selectable=false;layer.ZIndex=button.ZIndex+1;layer.Parent=button
                local inner=Instance.new("Frame");inner.Name="ShineSlash"
                inner.Size=UDim2.fromScale(1,1);inner.AnchorPoint=Vector2.new(0,.5)
                inner.BackgroundColor3=Color3.new(1,1,1);inner.BackgroundTransparency=.6;inner.BorderSizePixel=0
                inner.Active=false;inner.Selectable=false;inner.ZIndex=button.ZIndex+2;inner.Parent=layer
                local gradient=Instance.new("UIGradient");gradient.Rotation=23
                gradient.Transparency=NumberSequence.new({
                    NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.182,.494),
                    NumberSequenceKeypoint.new(.308,1),NumberSequenceKeypoint.new(.484,1),
                    NumberSequenceKeypoint.new(.752,0),NumberSequenceKeypoint.new(.753,1),NumberSequenceKeypoint.new(1,1)})
                gradient.Parent=inner;self.shine=layer;self.shineInner=inner
            end
            self.shine.Visible=true;self.shineInner.Position=UDim2.fromScale(-2,.5)
            local t=TweenService:Create(self.shineInner,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false,1.5),
                {Position=UDim2.fromScale(1,.5)})
            table.insert(self.idle,t);t:Play()
        end
        if cfg.ButtonParticlesEnabled~=false then
            if not self.sparkleLayer then
                local layer=Instance.new("Frame");layer.Name="PlaySparkles";layer.Size=UDim2.fromScale(1,1)
                layer.BackgroundTransparency=1;layer.BorderSizePixel=0;layer.Active=false;layer.Selectable=false
                layer.ZIndex=button.ZIndex+3;layer.Parent=button;self.sparkleLayer=layer;self.sparkles={}
                for i,xy in ipairs({{.934,.581},{.143,.57},{.091,.266},{.12,.751},{.962,.281}}) do
                    local spark=Instance.new("ImageLabel");spark.Name="Sparkle"..i
                    spark.AnchorPoint=Vector2.new(.5,.5);spark.BackgroundTransparency=1
                    spark.Position=UDim2.fromScale(xy[1],xy[2]);spark.Image="rbxassetid://96254055681570"
                    spark.Active=false;spark.Selectable=false;spark.ZIndex=button.ZIndex+4;spark.Parent=layer
                    self.sparkles[i]=spark
                end
            end
            self.sparkleLayer.Visible=true
            for i,spark in ipairs(self.sparkles) do
                spark.Size=UDim2.fromOffset(10+i,10+i);spark.Rotation=i*37;spark.ImageTransparency=.15
                local t=TweenService:Create(spark,TweenInfo.new(.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true,.3+i*.12),
                    {Size=UDim2.fromOffset(0,0),Rotation=i*37+50,ImageTransparency=.8})
                table.insert(self.idle,t);t:Play()
            end
        end
    end
    function state:Reset()
        self.hovered=false;self.focused=false;self.pressed=false
        self:Animate(1,true);self:ClearFX();self:StopIdle()
    end
    function state:Burst()
        if self.destroyed or not button.Active or not visible() or cfg.ReducedMotion then return end
        if os.clock()-self.lastBurst<.35 then return end
        self.lastBurst=os.clock();self:ClearFX()
        local serial=self.serial
        local function fx(object,duration,goals)
            local t=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),goals)
            table.insert(self.fx,t);t:Play()
        end
        if cfg.ButtonParticlesEnabled~=false then
            for i=1,8 do
                local spark=self.particles[i]
                if not spark then
                    spark=Instance.new("Frame");spark.Name="ButtonPaintSpark"
                    spark.AnchorPoint=Vector2.new(.5,.5);spark.BorderSizePixel=0
                    spark.Active=false;spark.Selectable=false;spark.ZIndex=button.ZIndex+3;spark.Parent=button
                    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=spark
                    self.particles[i]=spark
                end
                local angle=(i-1)*math.pi/4
                -- Start near the rim so paint remains visible against the button face.
                spark.Position=UDim2.new(.5+math.cos(angle)*.43,0,.5+math.sin(angle)*.38,0)
                spark.Size=UDim2.fromOffset(i%2==0 and 6 or 4,i%2==0 and 6 or 4)
                spark.BackgroundColor3=i%2==0 and Color3.new(1,1,1) or button.BackgroundColor3
                spark.BackgroundTransparency=.08;spark.Rotation=i*29;spark.Visible=true
                fx(spark,.46,{Position=UDim2.new(.5+math.cos(angle)*.56,math.cos(angle)*14,
                    .5+math.sin(angle)*.7,math.sin(angle)*15),Size=UDim2.fromOffset(1,1),BackgroundTransparency=1,Rotation=i*61})
            end
        end
        if options.play and cfg.ButtonSlashEnabled~=false then
            if not self.slashLayer then
                local layer=Instance.new("Frame");layer.Name="PlaySlashLayer";layer.Size=UDim2.new(1,-12,1,-12)
                layer.AnchorPoint=Vector2.new(.5,.5);layer.Position=UDim2.fromScale(.5,.5)
                layer.BackgroundTransparency=1;layer.ClipsDescendants=true;layer.BorderSizePixel=0
                layer.Active=false;layer.Selectable=false;layer.ZIndex=button.ZIndex+1;layer.Parent=button
                self.slashLayer=layer;self.slashes={}
                for i=1,2 do
                    local slash=Instance.new("Frame");slash.Name="Slash"..i;slash.AnchorPoint=Vector2.new(.5,.5)
                    slash.Size=UDim2.new(i==1 and .6 or .35,0,1,0);slash.Rotation=0
                    slash.BorderSizePixel=0;slash.BackgroundColor3=Color3.new(1,1,1)
                    slash.Active=false;slash.Selectable=false;slash.ZIndex=button.ZIndex+2;slash.Parent=layer
                    -- Draw the diagonal in a gradient so clipping does not depend
                    -- on the place's rotated-descendant clipping setting.
                    local band=Instance.new("UIGradient");band.Rotation=23
                    band.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
                        NumberSequenceKeypoint.new(i==1 and .35 or .47,1),NumberSequenceKeypoint.new(.5,0),
                        NumberSequenceKeypoint.new(i==1 and .65 or .53,1),NumberSequenceKeypoint.new(1,1)})
                    band.Parent=slash
                    self.slashes[i]=slash
                end
            end
            self.slashLayer.Visible=true
            for i,slash in ipairs(self.slashes) do
                slash.Position=UDim2.new(-.2,-(i-1)*24,.5,0);slash.BackgroundTransparency=i==1 and .72 or .45
                fx(slash,.5,{Position=UDim2.new(1.2,-(i-1)*24,.5,0),BackgroundTransparency=1})
            end
        end
        task.delay(.52,function()
            if not self.destroyed and self.serial==serial then self:ClearFX() end
        end)
    end
    local function rest() return (state.hovered or state.focused) and 1.045 or 1 end
    local function enter()
        if not button.Active or not visible() then return end
        state.hovered=true;state:Animate(state.pressed and .95 or rest())
        if options.play then state:Burst() end
    end
    connect(button.MouseEnter,enter)
    connect(button.MouseLeave,function() state.hovered=false;state.pressed=false;state:Animate(rest()) end)
    connect(button.SelectionGained,function()
        if not button.Active or not visible() then return end
        state.focused=true;state:Animate(rest());if options.play then state:Burst() end
    end)
    connect(button.SelectionLost,function() state.focused=false;state.pressed=false;state:Animate(rest()) end)
    local function primary(input)
        return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
            or input.KeyCode==Enum.KeyCode.ButtonA
    end
    connect(button.InputBegan,function(input)
        if not primary(input) or not button.Active or not visible() then return end
        state.pressed=true;state:Animate(.95)
        if options.play then state:Burst() end
    end)
    connect(button.InputEnded,function(input)
        if primary(input) then state.pressed=false;state:Animate(rest()) end
    end)
    connect(button.Activated,function()
        if not button.Active or not visible() then return end
        state.pressed=false;state:Animate(rest());state:Burst()
    end)
    connect(button:GetPropertyChangedSignal("Active"),function()
        if not button.Active then state:Reset() else state:StartIdle() end
    end)
    -- Ancestor changes matter: menu and results screens hide their parent overlay.
    local ancestor=button
    while ancestor do
        if ancestor:IsA("GuiObject") or ancestor:IsA("ScreenGui") then
            connect(ancestor:GetPropertyChangedSignal(ancestor:IsA("ScreenGui") and "Enabled" or "Visible"),function()
                if not visible() then state:Reset() else state:StartIdle() end
            end)
        end
        ancestor=ancestor.Parent
    end
    connect(button.Destroying,function()
        state.destroyed=true;state:Reset()
        for _,connection in ipairs(state.connections) do connection:Disconnect() end
        table.clear(state.connections);bindings[button]=nil
    end)
    state:StartIdle()
    return state
end
return Effects
