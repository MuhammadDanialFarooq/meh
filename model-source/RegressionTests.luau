-- Deterministic regression tests, also executed by the headless Luau harness.
-- They exercise the actual World / Grid / TerritorySystem implementations.
local Grid = require(script.Parent.Grid)
local World = require(script.Parent.World)
local Test = {}

local function captureCases(cfg)
    local small = table.clone(cfg)
    small.Grid, small.Cell, small.ArenaRadius = 12, 1, 100
    small.ArenaBoundaryMargin = 0
    small.BoundaryAssistDepthCells = 0
    local function grid() return Grid.new(small) end
    local function paint(g, x1, y1, x2, y2, owner)
        for y = y1, y2 do for x = x1, x2 do g:Set(g:Index(x,y), owner) end end
    end
    local function ring(g, owner)
        paint(g,2,2,11,2,owner); paint(g,2,11,11,11,owner)
        paint(g,2,3,2,10,owner); paint(g,11,3,11,10,owner)
    end
    -- 64 enclosed cells are larger than the 44-cell exterior.
    local g = grid()
    ring(g,1)
    g:Capture(1,{})
    assert(g.owners[g:Index(6,6)] == 1, "Large enclosed region was left uncaptured")
    assert(g.owners[g:Index(1,1)] == 0, "Exterior was incorrectly claimed")
    assert(g.counts[1] == 100, "Incorrect enclosed area count")
    -- A single remaining interior component must finish the board.
    g = grid()
    for i=1,g.total do g:Set(i,1) end
    paint(g,5,5,7,7,2)
    local _,changed,affected = g:Capture(1,{})
    assert(g.counts[1] == g.playableTotal and g.counts[2] == 0,
        "Final enclosed opponent blocked 100%")
    assert(changed[g:Index(6,6)] and affected[2], "Capture metadata missing")
    -- A divider touching both walls keeps the larger exterior.
    g = grid()
    paint(g,4,1,4,12,1)
    g:Capture(1,{})
    assert(g.owners[g:Index(2,6)] == 1 and g.owners[g:Index(8,6)] == 0,
        "Wall-to-wall capture chose the wrong side")
    -- Direct inheritance must neither draw a corridor nor steal third-party land.
    g = grid()
    g:Set(g:Index(2,6),1); g:Set(g:Index(10,6),2)
    paint(g,6,1,6,12,3)
    local cells,count = g:AbsorbDefeatedLand(2,1)
    assert(count == 1 and cells[g:Index(10,6)], "Defeated land failed to transfer")
    assert(g.owners[g:Index(5,6)] == 0 and g.counts[3] == 12,
        "Inheritance manufactured a corridor or stole rival land")
    -- Absorbing A can cover B's head; both must be eliminated in one capture.
    local w = World.new(small,nil,{onMerge=function() error("intentional VFX failure") end})
    local a=w:NewEntity(1,"Tester",cfg.Colors[1],"Human")
    local b=w:NewEntity(2,"Bot A",cfg.Colors[2],"Farmer")
    local c=w:NewEntity(3,"Bot B",cfg.Colors[3],"Farmer")
    for _,e in ipairs(w.entities) do e.alive=true end
    a.pos=w.grid:Center(2,2); b.pos=w.grid:Center(6,6); c.pos=w.grid:Center(1,1)
    ring(w.grid,1)
    w.grid:Set(w.grid:Index(6,6),2)
    w.grid:Set(w.grid:Index(1,1),2)
    w.grid:Set(w.grid:Index(12,12),3)
    w:Capture(a)
    assert(not b.alive and not c.alive and a.kills == 2,
        "Capture did not resolve all heads covered by inheritance")
    assert(w.grid.owners[w.grid:Index(12,12)] == 1,
        "Chain elimination failed to transfer all victim territory")
    print("[Paintland V27 TEST PASS] 5 capture/inheritance regression scenarios")
end

function Test.Run(cfg)
    captureCases(cfg)
    local world = World.new(cfg, nil, {
        onVictory = function(_, w)
            w._testVictoryCalls = (w._testVictoryCalls or 0) + 1
        end,
    })
    local grid = world.grid
    local actor = world:NewEntity(1, "Tester", cfg.Colors[1], "Human")
    actor.alive = true
    actor.pos = Vector2.zero
    actor.heading = 0
    actor.trailCells = {}
    actor.trailSet = {}
    local original = {}
    local target = math.floor(grid.playableTotal * 0.74)
    for i = 1, grid.total do
        if grid.mask[i] and #original < target then
            grid:Set(i, 1)
            original[#original + 1] = i
        end
    end
    -- Previously, pruning by head near a smaller detached component erased
    -- the majority of captured land. This test forbids THAT regression.
    actor.pos = Vector2.new(grid.maskRadius * 0.85, 0)
    local x, y = grid:Coords(actor.pos)
    for dy = -1, 1 do
        local idx = grid:Index(x, y + dy)
        if idx and grid.owners[idx] ~= 1 then
            actor.trailCells[#actor.trailCells + 1] = idx
        end
    end
    if #actor.trailCells == 0 then
        local i = grid:At(actor.pos)
        if i then actor.trailCells[1] = i end
    end
    local oldCount = grid.counts[1] or 0
    -- Use WORLD's genuine capture path, which previously called destructive
    -- pruning in TerritorySystem and World:Eliminate.
    world:Capture(actor)
    assert((grid.counts[1] or 0) >= oldCount,
        "Capture deleted previously owned land")
    for _, idx in ipairs(original) do
        assert(grid.owners[idx] == 1, "Capture erased an old owned cell")
    end

    for i = 1, grid.total do
        if grid.mask[i] then grid:Set(i, 1) end
    end
    local won = world:CheckVictory()
    assert(won and world.completed, "100% did not lock Victory")
    assert(world._testVictoryCalls == 1, "Victory callback not fired exactly once")
    world:Step(1/30, function() return nil end)
    assert(world._testVictoryCalls == 1, "Victory re-triggered on a later step")
    assert((grid.counts[1] or 0) == grid.playableTotal,
        "Victory-owned cells disappeared after stepping")
    print(string.format("[Paintland V26 TEST PASS] Capture preserved %d cells; Victory locked at %d/%d",
        #original, grid.counts[1], grid.playableTotal))
end

return Test
