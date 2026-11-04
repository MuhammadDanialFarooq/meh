-- Cosmetic elastic response inspired by the supplied slime demo's velocity drag
-- and SmartBone inertia. No forces, bones or collider state enter game simulation.
local Slime={}
local function spring(value,velocity,target,dt,frequency,damping)
    local acceleration=(target-value)*frequency*frequency-2*damping*frequency*velocity
    velocity+=acceleration*dt
    return value+velocity*dt,velocity
end
function Slime.new(position,heading)
    return {position=position,heading=heading or 0,stretch=0,stretchVelocity=0,
        lean=0,leanVelocity=0,turn=0,turnVelocity=0,phase=0}
end
function Slime.Step(state,position,heading,dt,reduced)
    dt=math.max(0,dt or 0)
    local distance=(position-state.position).Magnitude
    local rotation=math.atan2(math.sin(heading-state.heading),math.cos(heading-state.heading))
    -- Respawns, large corrections and suspended frames should not create elastic explosions.
    if dt>.25 or distance>14 or reduced then
        state.stretch=0;state.stretchVelocity=0;state.lean=0;state.leanVelocity=0
        state.turn=0;state.turnVelocity=0
        state.position=position;state.heading=heading
        return {x=1,y=1,z=1,lean=0,turn=0,bob=0,phase=state.phase}
    end
    local speed=dt>0.0001 and math.min(30,distance/dt) or 0
    local travel=math.clamp(speed/18,0,1)
    local stretchTarget=travel*.12
    local turnTarget=math.clamp(rotation/math.max(dt,.01),-5,5)*.045
    local remaining=math.min(dt,.1)
    while remaining>0 do
        local step=math.min(remaining,1/120);remaining-=step
        state.stretch,state.stretchVelocity=spring(state.stretch,state.stretchVelocity,stretchTarget,step,14,.58)
        state.lean,state.leanVelocity=spring(state.lean,state.leanVelocity,travel*.085,step,11,.65)
        state.turn,state.turnVelocity=spring(state.turn,state.turnVelocity,turnTarget,step,13,.55)
    end
    state.phase+=dt*(3+travel*5)
    state.position=position;state.heading=heading
    local breathe=math.sin(state.phase)*.018
    local y=math.clamp(1-state.stretch+breathe,.78,1.13)
    -- Approximately conserve volume as the slime spreads against the ground.
    local spread=1/math.sqrt(y)
    return {x=spread,z=spread*(1+state.stretch*.32),y=y,
        lean=math.clamp(state.lean,-.12,.12),turn=math.clamp(state.turn,-.25,.25),
        bob=math.sin(state.phase*2)*travel*.045,phase=state.phase}
end
return Slime
