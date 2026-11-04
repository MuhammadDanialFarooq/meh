-- Register future modules here; the server and HUD both consume this list.
-- Contract: Id, Name, Key, Gamepad, Color, Cooldown(config), Activate(world, actor, config).
local Registry={List={require(script.Parent.Splash),require(script.Parent.Dash)},ById={}}
for _,ability in ipairs(Registry.List) do
    assert(type(ability.Id)=="string" and not Registry.ById[ability.Id],"Duplicate ability id")
    Registry.ById[ability.Id]=ability
end
return Registry
