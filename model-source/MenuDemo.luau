-- A separate, silent bot-only match for the main menu. No player input, revive,
-- purchases, rewards or game UI callbacks are attached to this world.
local World=require(script.Parent.World)
local Demo={}
Demo.__index=Demo
function Demo.new(cfg,renderer,events)
    return setmetatable({cfg=cfg,renderer=renderer,events=events or {},active=false,
        rng=Random.new(),age=0,followAge=0,world=nil,target=nil,focus=Vector2.zero},Demo)
end
function Demo:ChooseTarget()
    local alive={}
    for _,e in ipairs(self.world.entities) do
        if e.alive then alive[#alive+1]=e end
    end
    self.target=#alive>0 and alive[self.rng:NextInteger(1,#alive)] or nil
    self.followAge=0
end
function Demo:Start()
    if self.events.onReset then self.events.onReset() end
    self.active=true
    self.age,self.followAge=0,0
    local cfg=table.clone(self.cfg)
    self.world=World.new(cfg,function(index) self.renderer:MarkCell(index) end,{
        onSpawn=function(e)
            self.renderer:ResetEntityVisual(e.id)
            if self.events.onSpawn then self.events.onSpawn(e) end
        end,
        onCapture=function(e,count,cells)
            self.renderer:ClearTrail(e.id)
            if self.events.onCapture then self.events.onCapture(e,count,cells,self.world) end
        end,
        onMerge=function(killer,victim,cells,hit)
            if self.events.onMerge then self.events.onMerge(killer,victim,cells,hit,self.world) end
        end,
        onEliminate=function(victim,killer,cause,hit)
            self.renderer:RemoveEntityVisual(victim.id)
            if self.events.onEliminate then self.events.onEliminate(victim,killer,cause,hit) end
        end,
    })
    self.renderer:SetWorld(self.world)
    for id=1,(self.cfg.MenuDemoBots or 8) do
        local color=cfg.Colors[self.rng:NextInteger(1,#cfg.Colors)]
        local style=cfg.BotStyles[self.rng:NextInteger(1,#cfg.BotStyles)]
        local e=self.world:NewEntity(id,cfg.BotNames[((id-1)%#cfg.BotNames)+1],color,style)
        -- Entity 1 is normally the human; turn it into a bot BEFORE spawning.
        e.isHuman=false
        self.world:Spawn(e)
    end
    self:ChooseTarget()
    self.focus=self.target and self.target.pos or Vector2.zero
    return self.world
end
function Demo:Update(dt)
    if not self.active then return end
    self.age+=math.max(0,dt)
    self.followAge+=math.max(0,dt)
    if self.age>=(self.cfg.MenuDemoRoundSeconds or 55) or self.world.completed then
        self:Start()
        return
    end
    local elapsed=math.clamp(dt,0,.08)
    local step=self.cfg.SimulationSubstep or 1/60
    local steps=math.min(self.cfg.MaxSubsteps or 4,math.max(1,math.ceil(elapsed/step)))
    for _=1,steps do
        self.world:Step(math.min(elapsed/steps,step),function() return nil end)
    end
    if not self.target or not self.target.alive or self.followAge>=(self.cfg.MenuDemoFollowSeconds or 12) then
        self:ChooseTarget()
    end
    if self.target then self.focus=self.focus:Lerp(self.target.pos,1-math.exp(-3*elapsed)) end
end
function Demo:Stop()
    self.active=false
    self.world,self.target=nil,nil
end
return Demo
