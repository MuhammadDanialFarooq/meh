-- Bounded cosmetic ribbons: victim blocks catch up, follow the killer, then absorb.
local Trail={};Trail.__index=Trail
function Trail.new(renderer,cfg)
    return setmetatable({renderer=renderer,cfg=cfg,active={},free={},total=0},Trail)
end
function Trail:Part()
    local p=table.remove(self.free)
    if p then return p end
    if self.total>=(self.cfg.KillBlockTrailMaxParts or 48) then return nil end
    p=Instance.new("Part");p.Name="CollectedPaintBlock";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Parent=self.renderer.arena.effectsFolder
    self.total+=1;return p
end
function Trail:Emit(victim,killer,hit)
    if self.cfg.KillBlockTrailEnabled==false or self.cfg.ReducedMotion or not victim or not killer or victim==killer or not killer.alive then return end
    local origin=hit and hit.position or victim.pos
    local record={id=killer.id,userId=killer.userId,revision=killer.spawnRevision,age=0,blocks={},history={killer.pos}}
    for i=1,7 do
        local p=self:Part();if not p then break end
        p.Color=victim.color;p.Transparency=0;p.Size=Vector3.new(1.2,1.2,1.2)
        local at=origin+Vector2.new(math.cos(i*2.4),math.sin(i*2.4))*1.5
        p.Position=Vector3.new(at.X,1.3,at.Y)
        record.blocks[#record.blocks+1]={part=p,pos=at,number=i}
    end
    if #record.blocks>0 then self.active[#self.active+1]=record end
end
function Trail:Release(record)
    for _,b in ipairs(record.blocks) do b.part.Transparency=1;table.insert(self.free,b.part) end
end
function Trail:Update(dt)
    dt=math.max(0,dt)
    local world=self.renderer.world
    for i=#self.active,1,-1 do
        local r=self.active[i];r.age+=dt
        local e=world and world.entities[r.id]
        local lifetime=self.cfg.KillBlockTrailDuration or 2.4
        if not e or not e.alive or e.userId~=r.userId or e.spawnRevision~=r.revision or r.age>=lifetime or self.cfg.ReducedMotion then
            self:Release(r);table.remove(self.active,i)
        else
            if (e.pos-r.history[1]).Magnitude>.7 then table.insert(r.history,1,e.pos) end
            while #r.history>42 do table.remove(r.history) end
            local absorb=math.clamp((r.age-(lifetime-.6))/.6,0,1)
            for n,b in ipairs(r.blocks) do
                local fallback=e.pos-Vector2.new(math.cos(e.heading),math.sin(e.heading))*(n*1.5+3)
                local behind=r.history[math.min(#r.history,1+n*3)] or fallback
                if #r.history<2 then behind=fallback end
                local target=behind:Lerp(e.pos,absorb)
                if r.age>n*.035 then b.pos=b.pos:Lerp(target,1-math.exp(-(8+n*.3)*dt)) end
                local size=math.max(.05,1.2*(1-absorb))
                b.part.Size=Vector3.new(size,size,size)
                b.part.CFrame=CFrame.new(b.pos.X,1.3+math.sin(r.age*6+n)*.18+absorb*1.7,b.pos.Y)*CFrame.Angles(r.age*2,n*.4,r.age*1.4)
                b.part.Color=b.part.Color:Lerp(e.color,math.clamp(dt*2,0,1))
                b.part.Transparency=absorb*.65
            end
        end
    end
end
function Trail:Clear()
    for _,r in ipairs(self.active) do self:Release(r) end;table.clear(self.active)
end
function Trail:Destroy()
    self:Clear();for _,p in ipairs(self.free) do p:Destroy() end;table.clear(self.free);self.total=0
end
return Trail
