-- Clear territory meter with a single animated fill and readable live value.
local TweenService = game:GetService("TweenService")
local HUD = {}
HUD.__index = HUD
local function make(parent, class, name, props)
    local item=Instance.new(class)
    item.Name=name
    for key,value in pairs(props) do item[key]=value end
    item.Parent=parent
    return item
end
function HUD.new(parent,cfg)
    local self=setmetatable({cfg=cfg,value=0},HUD)
    self.canvas=make(parent,"Frame","TerritoryMeter",{
        AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,56),
        Size=UDim2.fromOffset(350,76),BackgroundColor3=Color3.fromRGB(19,30,48),
        BackgroundTransparency=0.06,BorderSizePixel=0,ZIndex=30})
    make(self.canvas,"UICorner","Round",{CornerRadius=UDim.new(0,18)})
    make(self.canvas,"UIStroke","Edge",{Color=Color3.fromRGB(80,108,134),Transparency=0.6,Thickness=1})
    self.caption=make(self.canvas,"TextLabel","Caption",{BackgroundTransparency=1,
        Position=UDim2.fromOffset(18,10),Size=UDim2.new(1,-100,0,22),Text="YOUR TERRITORY",
        TextColor3=Color3.fromRGB(166,187,205),Font=Enum.Font.GothamBold,TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31})
    self.percent=make(self.canvas,"TextLabel","Percent",{BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,8),Size=UDim2.fromOffset(90,26),
        Text="0.0%",TextColor3=Color3.fromRGB(244,250,255),Font=Enum.Font.GothamBold,
        TextSize=22,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=31})
    self.track=make(self.canvas,"Frame","Track",{Position=UDim2.fromOffset(18,44),
        Size=UDim2.new(1,-36,0,10),BackgroundColor3=Color3.fromRGB(43,59,78),BorderSizePixel=0,
        ClipsDescendants=true,ZIndex=31})
    make(self.track,"UICorner","Round",{CornerRadius=UDim.new(1,0)})
    self.fill=make(self.track,"Frame","Fill",{Size=UDim2.fromScale(0,1),
        BackgroundColor3=Color3.fromRGB(82,230,186),BorderSizePixel=0,ZIndex=32})
    make(self.fill,"UICorner","Round",{CornerRadius=UDim.new(1,0)})
    self:Reset()
    return self
end
function HUD:Resize(viewport)
    self.canvas.Size=UDim2.fromOffset(math.min(350,math.max(180,viewport.X-32)),68)
end
function HUD:Reset()
    if self.tween then self.tween:Cancel() end
    self.value=0
    self.fill.Size=UDim2.fromScale(0,1)
    self.percent.Text="0.0%"
end
function HUD:Update(percent,color)
    percent=math.clamp(percent,0,100)
    local value=percent/100
    self.percent.Text=string.format("%.1f%%",percent>=100 and 100 or math.min(99.9,percent))
    self.fill.BackgroundColor3=color or Color3.fromRGB(82,230,186)
    if math.abs(value-self.value)<0.0001 then return end
    self.value=value
    if self.tween then self.tween:Cancel() end
    self.tween=TweenService:Create(self.fill,TweenInfo.new(0.22,Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out),{Size=UDim2.fromScale(value,1)})
    self.tween:Play()
end
function HUD:Destroy()
    if self.tween then self.tween:Cancel() end
    self.canvas:Destroy()
end
return HUD
