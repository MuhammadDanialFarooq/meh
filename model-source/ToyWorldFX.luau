-- V21: small physical impact motes above the board. Pooled and bounded for phones.
local FX={}
FX.__index=FX
local function bead(folder)
    local p=Instance.new("Part")
    p.Name="CaptureConfetti"
    p.Shape=Enum.PartType.Ball
    p.Size=Vector3.new(.35,.35,.35)
    p.Anchored=true
    p.Material=Enum.Material.Neon
    p.CanCollide=false
    p.CanTouch=false
    p.CanQuery=false
    p.CastShadow=false
    p.Transparency=1
    p.Parent=folder
    return p
end
function FX.new(renderer,cfg)
    return setmetatable({folder=renderer.arena.effectsFolder,cfg=cfg,
        pool={},active={},created=0,max=cfg.ToyFXMaxObjects or 50,
        rng=Random.new()},FX)
end
function FX:_emit(pos,color,count,size)
    if self.cfg.ReducedMotion then return end
    local mobile=game:GetService("UserInputService").TouchEnabled
    count=math.min(mobile and math.ceil(count*.55) or count,
        self.max-#self.active)
    for i=1,count do
        local p=table.remove(self.pool)
        if not p then
            if self.created>=self.max then break end
            p=bead(self.folder)
            self.created+=1
        end
        local a=self.rng:NextNumber(0,math.pi*2)
        local speed=self.rng:NextNumber(7,18)*(size or 1)
        local origin=Vector3.new(pos.X,1.1,pos.Y)
        p.Position=origin
        p.Color=color:Lerp(Color3.new(1,1,1),self.rng:NextNumber(.15,.55))
        local radius=self.rng:NextNumber(.25,.7)
        p.Size=Vector3.new(radius,radius,radius)
        p.Transparency=0
        self.active[#self.active+1]={part=p,life=.58,age=0,at=origin,
            velocity=Vector3.new(math.cos(a)*speed,self.rng:NextNumber(4,11),math.sin(a)*speed)}
    end
end
function FX:Capture(entity,count)
    if entity and count>0 then self:_emit(entity.pos,entity.color,math.min(12,3+math.floor(math.sqrt(count))),1) end
end
function FX:Elimination(victim,killer,hit)
    if victim then self:_emit(hit and hit.position or victim.pos,killer and killer.color or victim.color,12,1.1) end
end
function FX:Spawn(entity)
    if entity then self:_emit(entity.pos,entity.color,7,.65) end
end
function FX:Update(dt)
    dt=math.clamp(dt or 0,0,.05)
    for i=#self.active,1,-1 do
        local o=self.active[i]
        o.age+=dt
        local t=o.age/o.life
        if t>=1 then
            o.part.Transparency=1
            self.pool[#self.pool+1]=o.part
            table.remove(self.active,i)
        else
            local v=o.velocity
            o.part.Position=o.at+v*o.age+Vector3.new(0,-20*o.age*o.age,0)
            o.part.Transparency=t*t
            local scale=math.max(.1,1-t)
            o.part.Size=Vector3.new(.5,.5,.5)*scale
        end
    end
end
function FX:Clear()
    for _,o in ipairs(self.active) do o.part.Transparency=1;self.pool[#self.pool+1]=o.part end
    table.clear(self.active)
end
return FX
