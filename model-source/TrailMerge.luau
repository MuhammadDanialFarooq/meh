-- Preserve the route from the cut back to each player's land before clearing
-- either trail. Only the defeated trail BEFORE the hit belongs to this bridge.
local Merge = {}
function Merge.Route(grid, killer, victim, hit)
    if not hit or not hit.index then return nil end
    local cut
    for n,index in ipairs(victim.trailCells) do
        if index==hit.index then cut=n;break end
    end
    if not cut then return nil end
    local route={}
    for n=1,cut do route[victim.trailCells[n]]=true end
    for _,index in ipairs(killer.trailCells) do route[index]=true end
    -- Bridge only the sub-cell collision tolerance, never arbitrary map space.
    local contact=grid:At(hit.position)
    if not contact then return nil end
    local function bridge(a,b)
        if not a or not b then return false end
        local ax,ay=(a-1)%grid.size+1,math.floor((a-1)/grid.size)+1
        local bx,by=(b-1)%grid.size+1,math.floor((b-1)/grid.size)+1
        if math.abs(ax-bx)>2 or math.abs(ay-by)>2 then return false end
        route[a]=true
        while ax~=bx or ay~=by do
            if ax~=bx then ax+=ax<bx and 1 or -1 else ay+=ay<by and 1 or -1 end
            local index=grid:Index(ax,ay)
            if not index then return false end
            route[index]=true
        end
        return true
    end
    if not bridge(contact,hit.index) then return nil end
    local last=killer.trailCells[#killer.trailCells]
    if last and not bridge(last,contact) then return nil end
    -- Trail entry can diagonally touch home. Preserve its actual departure cell
    -- so the four-connected ownership grid can follow the route to home.
    local victimHome=victim.nodes[1] and grid:At(victim.nodes[1])
    if victimHome and not bridge(victimHome,victim.trailCells[1]) then return nil end
    local killerHome=killer.nodes[1] and grid:At(killer.nodes[1])
    if last and killerHome and not bridge(killerHome,killer.trailCells[1]) then return nil end
    return {cells=route,cut=hit.index,contact=contact,required=killer.trailCells}
end
return Merge
