-- V22: world-space capture effects; no numerical capture reward in the HUD.
-- A single BillboardGui above captured land, plus a bounded white->owner-color
-- sweep across coalesced regions. This module never edits real ownership.
local TweenService = game:GetService("TweenService")
local Geometry = require(script.Parent.ChunkGeometry)

local TerritoryVFX = {}
TerritoryVFX.__index = TerritoryVFX

local function make(parent, kind, name)
    local inst = Instance.new(kind)
    inst.Name = name
    inst.Parent = parent
    return inst
end

local function centerOfRect(rect, grid)
    return Vector2.new(
        -grid.half + (rect.x1 + rect.x2 - 1) * 0.5 * grid.cell,
        -grid.half + (rect.y1 + rect.y2 - 1) * 0.5 * grid.cell
    )
end

function TerritoryVFX.new(renderer, cfg)
    return setmetatable({
        renderer = renderer, cfg = cfg, generation = 0,
        active = {}, activeCount = 0,
    }, TerritoryVFX)
end

function TerritoryVFX:Clear()
    self.generation += 1
    for obj in pairs(self.active) do
        if obj.Parent then obj:Destroy() end
    end
    table.clear(self.active)
    self.activeCount = 0
end

function TerritoryVFX:_register(object)
    self.active[object] = true
    self.activeCount += 1
end

function TerritoryVFX:_finish(object)
    if not self.active[object] then return end
    self.active[object] = nil
    self.activeCount = math.max(0, self.activeCount - 1)
    object:Destroy()
end

function TerritoryVFX:_showBillboard(position, percent, ownerColor)
    local folder = self.renderer.arena.effectsFolder
    if not folder or not folder.Parent then return end
    local anchor = make(folder, "Part", "LandGainPopupAnchor")
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = Vector3.new(position.X, 2.5, position.Y)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Transparency = 1
    self:_register(anchor)

    local gui = make(anchor, "BillboardGui", "LandGainBillboard")
    gui.Adornee = anchor
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = 320
    gui.Size = UDim2.fromOffset(230, 63)

    local label = make(gui, "TextLabel", "AreaGain")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 25
    label.Text = string.format("+%.2f%%", percent)
    label.TextColor3 = ownerColor:Lerp(Color3.new(1, 1, 1), 0.25)
    label.TextStrokeColor3 = Color3.fromRGB(27, 35, 69)
    label.TextStrokeTransparency = 0.1
    local scale = make(gui, "UIScale", "PopupScale")
    scale.Scale = 0.56

    local duration = self.cfg.CaptureWorldPopupDuration or 0.8
    TweenService:Create(anchor, TweenInfo.new(duration, Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out), {Position = anchor.Position + Vector3.new(0, 3, 0)}):Play()
    TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back,
        Enum.EasingDirection.Out), {Scale = 1}):Play()
    task.delay(duration * 0.6, function()
        if not self.active[anchor] then return end
        TweenService:Create(label, TweenInfo.new(duration * 0.38,
            Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    end)
    task.delay(duration + 0.05, function() self:_finish(anchor) end)
end

function TerritoryVFX:_showFlash(rect, ownerColor, grid, delaySeconds, version)
    task.delay(delaySeconds, function()
        if self.generation ~= version then return end
        local parent = self.renderer.arena.effectsFolder
        if not parent or not parent.Parent then return end
        if self.activeCount >= (self.cfg.CaptureFlashMaxActive or 72) then return end
        local center = centerOfRect(rect, grid)
        local tile = make(parent, "Part", "TerritoryWhiteSweep")
        tile.Anchored = true
        tile.CanCollide = false
        tile.CanTouch = false
        tile.CanQuery = false
        tile.CastShadow = false
        tile.Material = Enum.Material.SmoothPlastic
        tile.Color = Color3.fromRGB(255, 250, 239)
        tile.Transparency = 0.03
        tile.Size = Vector3.new((rect.x2-rect.x1+1)*grid.cell + 0.06,
            0.045, (rect.y2-rect.y1+1)*grid.cell + 0.06)
        tile.Position = Vector3.new(center.X, 0.385, center.Y)
        self:_register(tile)
        -- Color follows the claimed owner, then gently fades to the actual land.
        TweenService:Create(tile, TweenInfo.new(self.cfg.CaptureFlashDuration or 0.34,
            Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Color = ownerColor, Transparency = 1,
                Position = tile.Position - Vector3.new(0, 0.045, 0)}):Play()
        task.delay((self.cfg.CaptureFlashDuration or 0.34) + 0.05,
            function() self:_finish(tile) end)
    end)
end

function TerritoryVFX:Play(entity, gainedCells, changedCells, grid)
    if not entity or gainedCells <= 0 or not grid or not changedCells then return end
    -- Only owners of the final land are visualized. Never create stale flash
    -- segments for tiles that were stolen again in the same simulation step.
    local valid = {}
    local sx, sy, num = 0, 0, 0
    for index in pairs(changedCells) do
        if grid.owners[index] == entity.id then
            valid[index] = true
            local x = (index - 1) % grid.size + 1
            local y = math.floor((index - 1) / grid.size) + 1
            local c = grid:Center(x, y)
            sx += c.X
            sy += c.Y
            num += 1
        end
    end
    if num <= 0 then return end
    local regions = Geometry.RectanglesFromSet(valid, grid.size)
    if #regions == 0 then return end
    -- Spread flashes away from the point of loop closure, giving a land-growth sweep.
    table.sort(regions, function(a,b)
        return (centerOfRect(a, grid) - entity.pos).Magnitude
            < (centerOfRect(b, grid) - entity.pos).Magnitude
    end)
    local max = self.cfg.CaptureFlashMaxRegions or 24
    local version = self.generation
    for index = 1, (self.cfg.ReducedMotion and 0 or math.min(#regions, max)) do
        self:_showFlash(regions[index], entity.color, grid,
            (index - 1) * 0.014, version)
    end
    if entity.isHuman or self.cfg.ShowBotLandBillboards then
        if gainedCells >= (self.cfg.CaptureWorldPopupMinCells or 3) then
            -- Choose a REAL owned cell closest to the center of the new area;
            -- the mathematical centroid of a crescent can be outside the land.
            local centroid = Vector2.new(sx/num, sy/num)
            local best, bestDist
            for index in pairs(valid) do
                local x = (index - 1) % grid.size + 1
                local y = math.floor((index - 1) / grid.size) + 1
                local center = grid:Center(x, y)
                local distance = (center - centroid).Magnitude
                if not bestDist or distance < bestDist then
                    best, bestDist = center, distance
                end
            end
            self:_showBillboard(best, gainedCells / grid.playableTotal * 100, entity.color)
        end
    end
end

return TerritoryVFX
