-- V32: visible victim -> pale flash -> winner color sweep above absorbed land.
-- Never draws a second map in a SurfaceGui or StarterGui.
local ChunkGeometry = require(script.Parent.ChunkGeometry)

local LandMergeEffects = {}
LandMergeEffects.__index = LandMergeEffects

local function newOverlay(parent)
    local p = Instance.new("Part")
    p.Name = "MergeFade"
    p.Anchored = true
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Transparency = 1
    p.Parent = parent
    return p
end

function LandMergeEffects.new(renderer, cfg)
    return setmetatable({renderer = renderer, cfg = cfg, time = 0,
        pool = {}, active = {}}, LandMergeEffects)
end

function LandMergeEffects:GetPart()
    return table.remove(self.pool) or newOverlay(self.renderer.arena.effectsFolder)
end

function LandMergeEffects:Emit(killer, victim, changedCells, hit)
    if self.cfg.TerritoryMergeEffectsEnabled == false then return end
    if not killer or not victim or not changedCells then return end
    local rects = ChunkGeometry.RectanglesFromSet(changedCells, self.cfg.Grid)
    local maxParts = math.min(self.cfg.WorkspaceMergePartLimit or 26,
        (self.cfg.TerritoryMergeOverlayLimit or 170) - #self.active)
    if maxParts <= 0 then return end
    local cell = self.cfg.Cell
    local half = self.cfg.Grid * cell / 2
    local duration = self.cfg.TerritoryMergeDuration or 0.45
    local count = 0
    local origin=hit and hit.position or killer.pos
    -- Sample across the resulting rectangles instead of showing many heavy parts.
    local stride = math.max(1, math.ceil(#rects / maxParts))
    for i = 1, #rects, stride do
        if count >= maxParts then break end
        local r = rects[i]
        local p = self:GetPart()
        p.Color = victim.color
        p.Size = Vector3.new((r.x2 - r.x1 + 1) * cell, 0.025,
            (r.y2 - r.y1 + 1) * cell)
        p.Position = Vector3.new(-half + (r.x1 + r.x2 - 1) * 0.5 * cell,
            0.435, -half + (r.y1 + r.y2 - 1) * 0.5 * cell)
        p.Transparency = 0.18
        local dx = p.Position.X - origin.X
        local dz = p.Position.Z - origin.Y
        local distance = math.sqrt(dx * dx + dz * dz)
        self.active[#self.active + 1] = {
            part = p, start = self.time + (self.cfg.ReducedMotion and 0 or math.min(self.cfg.TerritoryMergeWaveDelay or 0.25, distance / 500)),
            from=victim.color, to=killer.color,
            duration = duration,
        }
        count += 1
    end
end

function LandMergeEffects:Update(dt)
    self.time += math.min(dt, 0.1)
    for i = #self.active, 1, -1 do
        local item = self.active[i]
        local alpha = (self.time - item.start) / item.duration
        if alpha >= 1 then
            item.part.Transparency = 1
            table.insert(self.pool, item.part)
            table.remove(self.active, i)
        elseif alpha >= 0 then
            local t = math.clamp(alpha, 0, 1)
            local flash=math.clamp(t/0.18,0,1)
            if self.cfg.ReducedMotion then
                item.part.Color=item.from:Lerp(item.to,t)
            else
                item.part.Color=t<0.18 and item.from:Lerp(Color3.new(1,1,1),flash)
                    or Color3.new(1,1,1):Lerp(item.to,math.clamp((t-.18)/.55,0,1))
            end
            item.part.Transparency = 0.12 + 0.88 * (t * t * (3 - 2 * t))
        end
    end
end

function LandMergeEffects:Clear()
    for _, item in ipairs(self.active) do
        item.part.Transparency = 1
        table.insert(self.pool, item.part)
    end
    table.clear(self.active)
end

function LandMergeEffects:Destroy()
    self:Clear()
    for _, part in ipairs(self.pool) do part:Destroy() end
    table.clear(self.pool)
end
return LandMergeEffects
