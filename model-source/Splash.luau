-- One ability definition. Only AbilityService calls Activate on the authority.
local Splash={Id="Splash",Name="SPLASH",Color=Color3.fromRGB(78,214,245)}
function Splash.Activate(world,actor,cfg)
    local grid=world.grid
    -- No free return from an exposed trail: the loop remains the core mechanic.
    if actor.drawing or grid:GetOwnerAt(actor.pos)~=actor.id then return false,"Splash needs your own land" end
    local radius=math.clamp(cfg.SplashRadiusCells or 6,1,12)*grid.cell
    local x,y=grid:Coords(actor.pos)
    local cells,affected={},{}
    local reach=math.ceil(radius/grid.cell)
    local count=0
    for dy=-reach,reach do for dx=-reach,reach do
        local index=grid:Index(x+dx,y+dy)
        if index then
            local delta=grid:Center(x+dx,y+dy)-actor.pos
            if delta:Dot(delta)<=radius*radius and grid.owners[index]~=actor.id then
                local owner=grid.owners[index]
                if owner>0 then affected[owner]=true end
                grid:Set(index,actor.id);cells[index]=true;count+=1
            end
        end
    end end
    if count==0 then return false,"No new land in Splash range" end
    world:ResolveClaims(actor,cells,affected)
    actor.home=actor.pos
    world:CheckVictory()
    -- Actual gained tiles use the same server reward hook as a closed loop.
    if world.events.onCapture then world.events.onCapture(actor,count,cells) end
    return true,{radius=radius}
end
return Splash
