-- Movement consumes this timed boost; no position teleport or collision bypass.
local Dash={Id="Dash",Name="DASH",Color=Color3.fromRGB(255,210,85)}
function Dash.Activate(_,actor,cfg)
    actor.dashRemaining=math.clamp(cfg.DashDurationSeconds or .65,.1,2)
    actor.dashMultiplier=math.clamp(cfg.DashSpeedMultiplier or 2.25,1,3)
    return true,{duration=actor.dashRemaining,multiplier=actor.dashMultiplier}
end
return Dash
