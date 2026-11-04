-- The authority supplies the world and actor; client payloads contain only an ID.
local Registry=require(script.Parent.AbilityRegistry)
local Service={};Service.__index=Service
function Service.new(cfg) return setmetatable({cfg=cfg},Service) end
function Service:State(world,actor)
    local state={}
    for _,ability in ipairs(Registry.List) do
        state[ability.Id]=math.max(0,((actor.abilityReadyAt or {})[ability.Id] or 0)-world.time)
    end
    return state
end
function Service:Use(world,actor,id,running)
    local ability=type(id)=="string" and Registry.ById[id]
    if not ability then return false,"Unknown ability" end
    if self.cfg.AbilitiesEnabled==false then return false,"Abilities are disabled" end
    if not running or not world or world.completed or not actor or not actor.alive then
        return false,"Abilities need an active match"
    end
    actor.abilityReadyAt=actor.abilityReadyAt or {}
    if (actor.abilityReadyAt[id] or 0)>world.time then return false,"Ability is cooling down" end
    -- Reserve before activation, including any capture/elimination callbacks.
    local previous=actor.abilityReadyAt[id]
    actor.abilityReadyAt[id]=world.time+ability.Cooldown(self.cfg)
    local ok,result=ability.Activate(world,actor,self.cfg)
    if not ok then actor.abilityReadyAt[id]=previous;return false,result end
    return true,result
end
return Service
