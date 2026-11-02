local TerritorySystem = {}

-- Captures first overwrite land inside the closed loop. This may split an
-- enemy's territory. Keep only the fragment containing the enemy's head;
-- the disconnected fragments are returned to neutral ground.
function TerritorySystem.Capture(world, actor)
    if not actor.alive then return end

    local grid = world.grid
    local before = grid.counts[actor.id] or 0
    -- Capture invariant: closing your own trail may add land, never delete
    -- territory you already owned. Record ownership BEFORE other callbacks.
    local previouslyOwned = {}
    for index = 1, grid.total do
        if grid.owners[index] == actor.id then
            previouslyOwned[#previouslyOwned + 1] = index
        end
    end
    local _, claimedCells, affectedOwners = grid:Capture(actor.id, actor.trailCells)
    world.trails:Clear(actor)

    -- Trail joins and closed loops follow the same covered-head/split-land rules.
    world:ResolveClaims(actor, claimedCells, affectedOwners)

    -- IMPORTANT: Never prune the CAPTURER's own territory here.
    -- In V23-V25 RemoveDetachedLand(actor.id, actor.pos) could select the tiny
    -- section near the head and delete a 70%+ original connected landmass.
    -- Only LOSING owners are eligible for the split-territory rule above.

    -- Defensive invariant: if any future capture callback takes an old cell
    -- from this capturer during their own completed loop, restore it now.
    local restored = 0
    for _, index in ipairs(previouslyOwned) do
        if grid.owners[index] ~= actor.id then
            grid:Set(index, actor.id)
            claimedCells[index] = true
            restored += 1
        end
    end
    if restored > 0 then
        warn(string.format(
            "[Paintland V26] Restored %d original cells: capture must never delete its owner's old land",
            restored
        ))
    end
    assert((grid.counts[actor.id] or 0) >= before,
        "[Paintland V26] Capture ownership unexpectedly decreased")

    -- Cosmetic particles may only originate from land still owned by actor.
    -- The UI uses actual net gain, not cells that were immediately pruned.
    for index in pairs(claimedCells) do
        if grid.owners[index] ~= actor.id then
            claimedCells[index] = nil
        end
    end
    local netGain = math.max(0, (grid.counts[actor.id] or 0) - before)

    actor.home = actor.pos
    if not actor.isHuman and not world.completed then world.ai:Plan(actor, world) end

    -- State transition FIRST. Particle/render/UI errors may never prevent victory.
    if actor.isHuman then world:CheckVictory() end

    -- Optional presentation. Keep simulation/win consistent if visual code fails.
    if world.events.onCapture then
        local ok, err = xpcall(function()
            world.events.onCapture(actor, netGain, claimedCells)
        end, debug.traceback)
        if not ok then warn("[Paintland V25] Capture VFX error: " .. tostring(err)) end
    end
end

return TerritorySystem
