-- A tweened ground ring and an overhead badge, always using the actor's paint.
local TweenService=game:GetService("TweenService")
local Fonts=require(script.Parent.Fonts)
local Indicator={};Indicator.__index=Indicator
function Indicator.new(root,parent,cfg)
    local self=setmetatable({cfg=cfg,parts={},target=-1,phase=0},Indicator)
    self.folder=Instance.new("Folder");self.folder.Name="AbilityRing";self.folder.Parent=parent
    self.value=Instance.new("NumberValue");self.value.Name="ChargeTween";self.value.Value=0;self.value.Parent=self.folder
    local gui=Instance.new("BillboardGui");gui.Name="AbilityCharge";gui.Adornee=root;gui.AlwaysOnTop=true
    gui.Size=UDim2.fromOffset(144,28);gui.StudsOffsetWorldSpace=Vector3.new(0,8.8,0);gui.MaxDistance=160;gui.Enabled=false;gui.Parent=root
    self.gui=gui
    local badge=Instance.new("TextLabel");badge.AnchorPoint=Vector2.new(.5,.5);badge.Position=UDim2.fromScale(.5,.5)
    badge.Size=UDim2.fromScale(1,1);badge.BackgroundColor3=Color3.fromRGB(255,250,232);badge.BorderSizePixel=0
    badge.FontFace=Fonts.Bold;badge.TextSize=11;badge.TextColor3=Color3.new(1,1,1);badge.Parent=gui;self.badge=badge
    local round=Instance.new("UICorner");round.CornerRadius=UDim.new(1,0);round.Parent=badge
    local edge=Instance.new("UIStroke");edge.Color=Color3.fromRGB(40,35,76);edge.Thickness=2;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Parent=badge
    badge.TextStrokeColor3=edge.Color;badge.TextStrokeTransparency=.2
    self.scale=Instance.new("UIScale");self.scale.Parent=badge
    return self
end
function Indicator:Build()
    if #self.parts>0 then return end
    for i=1,48 do
        local p=Instance.new("Part");p.Name="Arc"..i;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
        p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Size=Vector3.new(.28,.1,2*math.pi*4.25/48*1.04)
        p.Parent=self.folder;self.parts[i]=p
    end
end
function Indicator:Update(actor,dt)
    local visible=self.cfg.AbilitiesEnabled~=false and actor.alive and (actor.equippedAbility or "")~=""
    self.gui.Enabled=visible
    if not visible then for _,p in ipairs(self.parts) do p.Transparency=1 end;return end
    self:Build()
    local required=math.max(1,actor.abilityRequired or 100)
    local charge=math.clamp(actor.abilityCharge or 0,0,required)
    local target=charge/required
    if target~=self.target then
        self.target=target;if self.tween then self.tween:Cancel() end
        if self.cfg.ReducedMotion then self.value.Value=target
        else
            self.tween=TweenService:Create(self.value,TweenInfo.new(self.cfg.AbilityRingTweenSeconds or .28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Value=target})
            self.tween:Play()
        end
    end
    local ready=charge>=required
    self.badge.Text=ready and ("READY · "..actor.equippedAbility:upper()) or
        (actor.equippedAbility:upper().." · "..math.ceil(required-charge).." TO GO")
    self.badge.TextColor3=actor.color
    self.phase+=math.max(0,dt or 0)
    self.scale.Scale=ready and not self.cfg.ReducedMotion and (1+.035*math.sin(self.phase*4)) or 1
    for i,p in ipairs(self.parts) do
        local angle=(i-.5)/#self.parts*math.pi*2-math.pi/2
        p.CFrame=CFrame.new(actor.pos.X+math.cos(angle)*4.25,.55,actor.pos.Y+math.sin(angle)*4.25)*CFrame.Angles(0,-angle,0)
        local fill=math.clamp(self.value.Value*#self.parts-(i-1),0,1)
        p.Color=Color3.fromRGB(215,220,226):Lerp(actor.color,fill)
        p.Transparency=.48*(1-fill)
    end
end
function Indicator:Destroy()
    if self.tween then self.tween:Cancel() end
    self.gui:Destroy();self.folder:Destroy();table.clear(self.parts)
end
return Indicator
