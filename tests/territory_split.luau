local Grid=loadModule("Grid")
local cfg=table.clone(loadModule("Config"))
cfg.Grid=16;cfg.Cell=4;cfg.ArenaRadius=100;cfg.ArenaBoundaryMargin=0
local function setup(alternate)
    local changed={}
    local g=Grid.new(cfg,function(i) changed[i]=true end)
    for y=2,6 do for x=2,6 do g:Set(g:Index(x,y),1) end end
    for y=4,5 do for x=10,11 do g:Set(g:Index(x,y),1) end end
    for x=7,9 do g:Set(g:Index(x,4),1) end
    if alternate then
        for x=6,10 do g:Set(g:Index(x,2),1) end
        g:Set(g:Index(10,3),1)
    end
    g:Set(g:Index(8,4),2)
    return g,changed
end
-- Head sits on the tiny island. Losing the bridge must keep the mainland.
local g,changed=setup(false)
assert(g:RemoveDetachedLand(1,g:Center(10,4))==5,"Wrong number of detached cells removed")
assert(g.counts[1]==26 and g.owners[g:Index(2,2)]==1,"Head-near sliver erased main territory")
assert(g.owners[g:Index(8,4)]==2,"Cleanup restored a genuinely captured bridge")
assert(changed[g:Index(11,5)],"Cleanup bypassed renderer/minimap invalidation")
-- Outside head also prefers the largest component over the closest sliver.
g=setup(false)
g:RemoveDetachedLand(1,g:Center(12,4))
assert(g.counts[1]==26 and g.owners[g:Index(2,2)]==1,"Outside head selected tiny nearby land")
-- Another owned bridge makes this ONE component despite the original cut.
g=setup(true)
local before=g.counts[1]
assert(g:RemoveDetachedLand(1,g:Center(10,4))==0 and g.counts[1]==before,
    "Cleanup ignored an alternate owned connection")
assert(g.owners[g:Index(2,2)]==1 and g.owners[g:Index(11,5)]==1,"Alternate connection lost a side")
-- Equal-size components may use the head as a deterministic tie breaker.
g=Grid.new(cfg)
g:Set(g:Index(2,2),1);g:Set(g:Index(2,3),1)
g:Set(g:Index(10,10),1);g:Set(g:Index(10,11),1)
g:RemoveDetachedLand(1,g:Center(10,10))
assert(g.counts[1]==2 and g.owners[g:Index(10,11)]==1,"Equal-size tie ignored head component")
-- Exercise the actual loser-cleanup call used by captures and joining.
local World=loadModule("World")
local w=World.new(cfg)
g=setup(false);w.grid=g
local loser=w:NewEntity(1,"Player",cfg.Colors[1],"Human")
loser.alive=true;loser.pos=g:Center(10,4)
local cutter=w:NewEntity(2,"Cutter",cfg.Colors[2],"Farmer")
cutter.alive=true;cutter.pos=g:Center(8,4)
w:ResolveClaims(cutter,{[g:Index(8,4)]=true},{[1]=true})
assert(loser.alive and g.counts[1]==26 and g.owners[g:Index(2,2)]==1,
    "World loser-cleanup discarded the mainland")
print("[Paintland V37 TEST PASS] Mainland preserved near tiny/outside head; alternate bridge preserved; deterministic equal-size split")
