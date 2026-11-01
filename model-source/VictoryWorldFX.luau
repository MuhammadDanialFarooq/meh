-- V24: light Workspace celebration anchored at the winning player.
-- Visual only. All generated objects are capped and cleaned on replay.
local TweenService=game:GetService("TweenService")
local FX={}
FX.__index=FX
function FX.new(renderer,cfg)
    return setmetatable({renderer=renderer,cfg=cfg,active={},generation=0},FX)
end
function FX:Clear()
    self.generation+=1
    for _,obj in ipairs(self.active) do if obj.Parent then obj:Destroy() end end
    table.clear(self.active)
end
local function makePart(parent, name, pos, size, color)
    local p=Instance.new("Part")
    p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Material=Enum.Material.Neon
    p.Color=color;p.Transparency=.15;p.Size=size;p.Position=pos;p.Parent=parent
    return p
end
function FX:Play(entity)
    self:Clear()
    if self.cfg.VictoryEffectsEnabled==false or not entity then return end
    local arena=self.renderer.arena
    local parent=arena and arena.effectsFolder
    if not parent then return end
    local pos=Vector3.new(entity.pos.X,(self.cfg.CharacterHeight or 3.7)+1.8,entity.pos.Y)
    local anchor=makePart(parent,"VictoryBurstAnchor",pos,Vector3.new(.1,.1,.1),Color3.new(1,1,1))
    anchor.Transparency=1
    table.insert(self.active,anchor)
    local particles=Instance.new("ParticleEmitter")
    particles.Name="VictorySparks"
    particles.Texture="rbxasset://textures/particles/sparkles_main.dds"
    particles.Rate=0
    particles.Lifetime=NumberRange.new(.55,1.25)
    particles.Speed=NumberRange.new(11,22)
    particles.SpreadAngle=Vector2.new(180,180)
    particles.Acceleration=Vector3.new(0,-16,0)
    particles.Drag=2
    particles.LightEmission=.45
    particles.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,245,185)),
        ColorSequenceKeypoint.new(.5,entity.color),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,255,255))})
    particles.Size=NumberSequence.new({
        NumberSequenceKeypoint.new(0,.85),NumberSequenceKeypoint.new(.5,.52),
        NumberSequenceKeypoint.new(1,0)})
    particles.Parent=anchor
    particles:Emit(self.cfg.ReducedMotion and 14 or 45)
    local mobile=game:GetService("UserInputService").TouchEnabled
    local count=mobile and (self.cfg.VictoryWorldSparkCountMobile or 12)
        or (self.cfg.VictoryWorldSparkCount or 22)
    if self.cfg.ReducedMotion then count=math.floor(count*.4) end
    for i=1,count do
        local angle=i*math.pi*2/math.max(count,1)
        local dir=Vector3.new(math.cos(angle),0,math.sin(angle))
        local p=makePart(parent,"VictoryGlint",pos+dir*1.5,Vector3.new(.65,.65,.65),
            i%3==0 and Color3.fromRGB(255,219,90) or entity.color)
        p.Shape=Enum.PartType.Ball
        table.insert(self.active,p)
        TweenService:Create(p,TweenInfo.new(.72,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
            Position=pos+dir*(12+(i%5)*1.5)+Vector3.new(0,(i%4)*.7,0),
            Transparency=1,Size=Vector3.new(.12,.12,.12)
        }):Play()
    end
    local version=self.generation
    task.delay(3,function()
        if self.generation==version then self:Clear() end
    end)
end
return FX
