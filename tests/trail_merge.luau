local World=loadModule("World")
local cfg=table.clone(loadModule("Config"))
cfg.Grid=16;cfg.Cell=4;cfg.ArenaRadius=100;cfg.ArenaBoundaryMargin=0
cfg.BoundaryAssistDepthCells=0;cfg.HitRadius=3.4
local function setup()
    local changes={}
    local w=World.new(cfg,function(i) changes[i]=true end)
    local a=w:NewEntity(1,"You",cfg.Colors[1],"Human")
    local b=w:NewEntity(2,"Rival",cfg.Colors[2],"Farmer")
    a.alive=true;b.alive=true
    return w,a,b,changes
end
local function land(w,x,y,owner) w.grid:Set(w.grid:Index(x,y),owner) end
local function trail(w,e,points)
    e.drawing=true;e.nodes={w.grid:Center(points[1][1],points[1][2])}
    for n=2,#points do
        local p=points[n]
        w.trails:Register(e,w.grid:Index(p[1],p[2]),w.grid:Center(p[1],p[2]),0)
    end
    local p=points[#points];e.pos=w.grid:Center(p[1],p[2])
end
local function connected(w,start,goal,owner)
    local seen={[start]=true};local q={start};local h=1
    while h<=#q do
        local i=q[h];h+=1
        if i==goal then return true end
        local x,y=(i-1)%w.grid.size+1,math.floor((i-1)/w.grid.size)+1
        for _,p in ipairs({{x-1,y},{x+1,y},{x,y-1},{x,y+1}}) do
            local j=w.grid:Index(p[1],p[2])
            if j and not seen[j] and w.grid.owners[j]==owner then seen[j]=true;q[#q+1]=j end
        end
    end
    return false
end
-- L-shaped enemy trail. A direct horizontal shortcut must remain neutral.
local w,a,b,changes=setup()
land(w,2,10,1);land(w,12,3,2)
trail(w,a,{{2,10},{3,10},{4,10},{5,10},{6,10}})
trail(w,b,{{12,3},{12,4},{12,5},{12,6},{11,6},{10,6},{9,6},{8,6},{7,6},{6,6},{6,7},{6,8},{6,9},{5,9},{4,9}})
local contact=w.grid:Center(6,9)
a.pos=contact
assert(w:CollisionCheck(a,contact,0.1),"Killer died during merge")
assert(not b.alive and a.kills==1,"Cut did not eliminate victim once")
assert(connected(w,w.grid:Index(2,10),w.grid:Index(12,3),1),"Territories did not join along trails")
assert(w.grid.owners[w.grid:Index(12,6)]==1,"Bend in victim trail was skipped")
assert(w.grid.owners[w.grid:Index(4,9)]==0,"Victim tail beyond cut was claimed")
assert(w.grid.owners[w.grid:Index(9,10)]==0,"Merge carved an unrelated shortcut")
assert(not a.drawing and #a.trailCells==0 and not next(w.trails.buckets),"Claimed trails remained collidable")
assert(changes[w.grid:Index(12,6)],"Merge bypassed minimap/renderer invalidation")
local actual=0
for _,owner in ipairs(w.grid.owners) do if owner==1 then actual+=1 end end
assert(w.grid.counts[1]==actual and w.grid.counts[2]==0,"Merge counts drifted")
-- Radius-based adjacent-cell cut: contact need not share the victim's cell.
w,a,b=setup();land(w,2,5,1);land(w,8,3,2)
trail(w,a,{{2,5},{3,5},{4,5},{5,5},{6,5},{7,5}})
trail(w,b,{{8,3},{8,4},{8,5},{8,6}})
contact=w.grid:Center(8,5)-Vector2.new(2.5,0)
a.pos=contact
assert(w:CollisionCheck(a,contact,0.1) and not b.alive,"Radius hit was lost")
assert(connected(w,w.grid:Index(2,5),w.grid:Index(8,3),1),"Adjacent hit left a gap")
-- Crossed rival tiles become the bridge. Off-route rival land follows the
-- existing split-land rule, retaining the component under that rival's head.
local function crossing(headOnBridge,lastTile)
    local w,a,b=setup()
    local c=w:NewEntity(3,"Crossed rival",cfg.Colors[3],"Farmer")
    c.alive=true
    c.pos=w.grid:Center(5,headOnBridge and 5 or 8)
    land(w,2,5,1);land(w,8,5,2)
    if lastTile then land(w,5,5,3)
    else for y=1,12 do land(w,5,y,3) end end
    trail(w,a,{{2,5},{3,5},{4,5}})
    trail(w,b,{{8,5},{7,5},{6,5},{5,5},{4,5},{4,6}})
    local contact=w.grid:Center(4,5);a.pos=contact
    assert(w:CollisionCheck(a,contact,0.1),"Crossing join killed its winner")
    return w,a,b,c
end
w,a,b,c=crossing(false,false)
assert(not b.alive and c.alive,"Crossing eliminated a rival whose head was safe")
assert(w.grid.owners[w.grid:Index(5,5)]==1,"Crossed rival cell did not become the bridge")
assert(connected(w,w.grid:Index(2,5),w.grid:Index(8,5),1),"Rival crossing left disconnected inheritance")
assert(not a.drawing and #a.trailCells==0,"Converted crossing trail remained exposed")
assert(w.grid.owners[w.grid:Index(5,8)]==3 and w.grid.owners[w.grid:Index(5,2)]==0,
    "Crossed rival's split-land cleanup kept the wrong fragment")
assert(w.grid.counts[3]==7,"Crossing or pruning corrupted rival count")
local count=w.grid.counts[1]
assert(w.grid:RemoveDetachedLand(1,a.pos)==0 and w.grid.counts[1]==count,
    "Later connectivity cleanup deleted joined land")
assert(w.grid.owners[w.grid:Index(8,5)]==1,"Inherited land disappeared during cleanup")
-- A rival head on the bridge must be eliminated, not left alive over taken land.
w,a,b,c=crossing(true,false)
assert(not c.alive and a.kills==2 and w.grid.counts[3]==0,"Covered rival head survived crossing")
-- Losing the last tile also eliminates a rival away from the bridge.
w,a,b,c=crossing(false,true)
assert(not c.alive and a.kills==2 and w.grid.counts[3]==0,"Landless rival survived crossing")
-- Crossings in the killer's trail are converted too, not just the victim's.
w,a,b=setup()
land(w,2,5,1);land(w,8,3,2);land(w,3,5,3);land(w,3,6,3)
c=w:NewEntity(3,"Rival",cfg.Colors[3],"Farmer");c.alive=true;c.pos=w.grid:Center(3,6)
trail(w,a,{{2,5},{3,5},{4,5},{5,5},{6,5},{7,5}})
trail(w,b,{{8,3},{8,4},{8,5},{8,6}})
contact=w.grid:Center(8,5)-Vector2.new(2.5,0);a.pos=contact
w:CollisionCheck(a,contact,0.1)
assert(connected(w,w.grid:Index(2,5),w.grid:Index(8,3),1),"Crossing in killer trail did not join")
assert(c.alive and w.grid.owners[w.grid:Index(3,6)]==3,"Join took off-route rival land")
for _,testWorld in ipairs({w}) do
    local counts={}
    for _,owner in ipairs(testWorld.grid.owners) do if owner>0 then counts[owner]=(counts[owner] or 0)+1 end end
    for id,n in pairs(testWorld.grid.counts) do assert(n==(counts[id] or 0),"Post-crossing counts drifted") end
end
print("[Paintland V36 TEST PASS] Bent/radius joins, victim and killer rival crossings, durable connectivity, covered heads, landless rivals, loser pruning")
