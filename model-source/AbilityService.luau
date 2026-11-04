-- One server-selected slot. Charge comes only from authoritative captures/kills.
local Registry=require(script.Parent.AbilityRegistry)
local Service={};Service.__index=Service
function Service.new(cfg) return setmetatable({cfg=cfg},Service) end
function Service:Equip(actor,id)
    actor.equippedAbility=Registry.ById[id] and id or ""
    actor.abilityRequired=math.max(1,self.cfg.AbilityChargeRequired or 100)
    actor.abilityCharge=0;actor.usingAbility=false
end
function Service:State(_,actor)
    local id=actor.equippedAbility or ""
    local required=actor.abilityRequired or self.cfg.AbilityChargeRequired or 100
    local charge=math.clamp(actor.abilityCharge or 0,0,required)
    return {equipped=id,charge=charge,required=required,ready=id~="" and charge>=required}
end
function Service:Grant(actor,value)
    if not actor or not actor.alive or actor.usingAbility or not Registry.ById[actor.equippedAbility] then return end
    if type(value)~="number" or value~=value or value<=0 or value==math.huge then return end
    actor.abilityCharge=math.min(actor.abilityRequired or 100,(actor.abilityCharge or 0)+value)
end
function Service:Capture(actor,count,total)
    if total>0 and count>0 then self:Grant(actor,count/total*100*(self.cfg.AbilityChargePerPercent or 20)) end
end
function Service:Kill(actor) self:Grant(actor,self.cfg.AbilityChargePerKill or 35) end
function Service:Use(world,actor,id,running)
    if self.cfg.AbilitiesEnabled==false then return false,"Abilities are disabled" end
    if not running or not world or world.completed or not actor or not actor.alive then return false,"Abilities need an active match" end
    if id~=actor.equippedAbility then return false,"That ability is not equipped" end
    local ability=type(id)=="string" and Registry.ById[id]
    if not ability then return false,"Equip an unlocked ability in Loadout" end
    if actor.usingAbility or not self:State(world,actor).ready then return false,"Capture land or get kills to charge" end
    local previous=actor.abilityCharge
    actor.abilityCharge=0;actor.usingAbility=true
    -- Ability-generated rewards never recharge the same activation.
    local called,ok,result=pcall(ability.Activate,world,actor,self.cfg)
    actor.usingAbility=false
    if not called then warn("[Paintland Ability] "..tostring(ok));return false,"Ability failed; try again next charge" end
    if not ok then actor.abilityCharge=previous;return false,result end
    return true,result
end
return Service
