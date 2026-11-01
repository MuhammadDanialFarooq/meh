-- Entirely generated HUD minimap. Draws cached chunk rectangles only when ownership changes.
local ChunkGeometry = require(script.Parent.ChunkGeometry)
local UserInputService = game:GetService("UserInputService")

local Minimap = {}
Minimap.__index = Minimap

local function frame(parent, name, color, z)
    local f = Instance.new("Frame")
    f.Name = name
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function text(parent, name, textValue, size)
    local t = Instance.new("TextLabel")
    t.Name = name
    t.BackgroundTransparency = 1
    t.Text = textValue
    t.TextColor3 = Color3.fromRGB(31, 51, 58)
    t.Font = Enum.Font.GothamBold
    t.TextSize = size
    t.ZIndex = 27
    t.Parent = parent
    return t
end

local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

function Minimap.new(cfg, parent, renderer)
    local self = setmetatable({}, Minimap)
    self.cfg, self.renderer, self.world = cfg, renderer, nil
    self.chunksWide = math.ceil(cfg.Grid / cfg.Chunk)
    self.chunkPools, self.markers = {}, {}
    self.dirty, self.queue, self.head = {}, {}, 1
    self.elapsed = 0
    self.side = 136
    -- Clean flat minimap with an inset map surface, not a UI dashboard card.
    self.panel = frame(parent, "RuntimeMinimap", Color3.fromRGB(255,255,255),24)
    self.panel.AnchorPoint = Vector2.new(0,1)
    self.panel.Position = UDim2.new(0,13,1,-13)
    self.panel.ClipsDescendants = false
    round(self.panel, 18)
    local outline=Instance.new("UIStroke")
    outline.Color=Color3.fromRGB(37,65,119)
    outline.Thickness=2.5
    outline.Parent=self.panel

    self.header = text(self.panel, "Title", "", 10)
    self.header.Visible=false
    self.coverage = text(self.panel, "Coverage", "", 9)
    self.coverage.AnchorPoint = Vector2.new(0.5,1)
    self.coverage.Position = UDim2.new(0.5,0,1,-3)
    self.coverage.Size = UDim2.new(1,-10,0,15)
    self.coverage.TextColor3 = Color3.fromRGB(33,67,98)
    self.coverage.TextStrokeColor3=Color3.new(1,1,1)
    self.coverage.TextStrokeTransparency=0.4
    self.coverage.ZIndex=33

    self.map = frame(self.panel, "Map", Color3.fromRGB(233,249,242),25)
    self.map.Position = UDim2.fromOffset(4,4)
    self.map.ClipsDescendants = true
    round(self.map, 14)
    self.areas = frame(self.map, "Land", Color3.new(1, 1, 1), 25)
    self.areas.BackgroundTransparency = 1
    self.areas.Size = UDim2.fromScale(1, 1)
    self.dots = frame(self.map, "Players", Color3.new(1, 1, 1), 28)
    self.dots.BackgroundTransparency = 1
    self.dots.Size = UDim2.fromScale(1, 1)

    self.cameraBox = frame(self.map, "VisibleArea", Color3.new(1, 1, 1), 26)
    self.cameraBox.BackgroundTransparency = 1
    -- A tilted perspective camera cannot be represented by this axis-aligned box.
    self.cameraBox.Visible = false
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(30, 44, 54)
    stroke.Thickness = 1.4
    stroke.Transparency = 0.75
    stroke.Parent = self.cameraBox
    self:Resize(renderer.viewport.AbsoluteSize)
    return self
end

function Minimap:Resize(viewportSize)
    local small=UserInputService.TouchEnabled or viewportSize.X<750
    self.side=small and (self.cfg.MinimapPhoneSize or 108) or (self.cfg.MinimapDesktopSize or 142)
    local margin=small and 9 or 15
    self.panel.Position=UDim2.new(0,margin,1,-margin)
    self.panel.Size=UDim2.fromOffset(self.side+8,self.side+26)
    self.map.Size=UDim2.fromOffset(self.side,self.side)
    self.coverage.TextSize=small and 8 or 10
    for id=1,self.chunksWide*self.chunksWide do self:MarkChunk(id) end
end

function Minimap:MarkChunk(id)
    if self.dirty[id] then return end
    self.dirty[id] = true
    self.queue[#self.queue + 1] = id
end

function Minimap:MarkCell(index)
    local n = self.cfg.Grid
    local cx = math.floor(((index - 1) % n) / self.cfg.Chunk)
    local cy = math.floor(math.floor((index - 1) / n) / self.cfg.Chunk)
    self:MarkChunk(cy * self.chunksWide + cx + 1)
end

function Minimap:SetWorld(world)
    self.world = world
    self.areas:ClearAllChildren()
    self.dots:ClearAllChildren()
    self.chunkPools, self.markers = {}, {}
    self.dirty, self.queue, self.head = {}, {}, 1
    for id = 1, self.chunksWide^2 do self:MarkChunk(id) end
    for _, e in ipairs(world.entities) do
        self:EnsureMarker(e)
    end
end

function Minimap:EnsureMarker(e)
    if self.markers[e.id] then return self.markers[e.id] end
    local m = frame(self.dots, "Player" .. e.id, e.color, 29)
    m.AnchorPoint = Vector2.new(0.5, 0.5)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = m
    if e.isHuman then
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.new(1, 1, 1)
        outline.Thickness = 2
        outline.Parent = m
    end
    self.markers[e.id] = m
    return m
end

function Minimap:RebuildChunk(chunkId)
    if not self.world then return end
    local rectangles = ChunkGeometry.Rectangles(self.world.grid, self.cfg, chunkId, self.chunksWide)
    local pool = self.chunkPools[chunkId]
    if not pool then
        pool = {}
        self.chunkPools[chunkId] = pool
    end
    local s = self.side / self.cfg.Grid
    for index, rect in ipairs(rectangles) do
        local item = pool[index]
        if not item then
            item = frame(self.areas, "C" .. chunkId .. "_" .. index, Color3.new(1, 1, 1), 25)
            pool[index] = item
        end
        local e = self.world.entities[rect.owner]
        item.BackgroundColor3 = e and e.color or self.cfg.Colors[1]
        -- Shared integer boundaries avoid fractional seams and overlapping colors.
        local left = math.floor((rect.x1 - 1) * s + 0.5)
        local top = math.floor((rect.y1 - 1) * s + 0.5)
        local right = math.floor(rect.x2 * s + 0.5)
        local bottom = math.floor(rect.y2 * s + 0.5)
        item.Position = UDim2.fromOffset(left, top)
        item.Size = UDim2.fromOffset(right - left, bottom - top)
        item.Visible = right > left and bottom > top
    end
    for i = #rectangles + 1, #pool do pool[i].Visible = false end
end

function Minimap:MapPosition(pos)
    local half = self.cfg.Grid * self.cfg.Cell * 0.5
    local full = half * 2
    return Vector2.new((pos.X + half) / full * self.side,
        (pos.Y + half) / full * self.side)
end

function Minimap:UpdateMarkers(cameraPosition)
    if not self.world then return end
    for _, e in ipairs(self.world.entities) do
        local marker = self:EnsureMarker(e)
        marker.Visible = e.alive
        if e.alive then
            local p = self:MapPosition(e.pos)
            marker.Position = UDim2.fromOffset(p.X, p.Y)
            local diameter = e.isHuman and (self.side < 150 and 7 or 9) or (self.side < 150 and 4 or 5)
            marker.Size = UDim2.fromOffset(diameter, diameter)
            marker.BackgroundColor3 = e.color
        end
    end
    local viewportSize = self.renderer.viewport.AbsoluteSize
    local worldWidth = viewportSize.X / self.renderer.pixelScale
    local worldHeight = viewportSize.Y / self.renderer.pixelScale
    local worldSize = self.cfg.Grid * self.cfg.Cell
    local w, h = math.min(self.side, worldWidth / worldSize * self.side),
        math.min(self.side, worldHeight / worldSize * self.side)
    local center = self:MapPosition(cameraPosition)
    self.cameraBox.Size = UDim2.fromOffset(w, h)
    self.cameraBox.Position = UDim2.fromOffset(
        math.clamp(center.X - w / 2, 0, self.side - w),
        math.clamp(center.Y - h / 2, 0, self.side - h))
end

function Minimap:UpdateStats(world)
    local total = world.grid.playableTotal
    local percent = total > 0 and (world.grid.counts[1] or 0) / total * 100 or 0
    self.coverage.Text = string.format("%.1f%% YOUR LAND", percent)
end

function Minimap:Render(dt, cameraPosition)
    if not self.world then return end
    local built = 0
    while built < 8 and self.head <= #self.queue do
        local id = self.queue[self.head]
        self.queue[self.head] = false
        self.head += 1
        self.dirty[id] = nil
        self:RebuildChunk(id)
        built += 1
    end
    if self.head > #self.queue then
        self.queue = {}
        self.head = 1
    end
    self.elapsed += dt
    if self.elapsed > (self.cfg.MinimapUpdateRate or 0.12) then
        self.elapsed = 0
        self:UpdateMarkers(cameraPosition)
    end
end

function Minimap:Destroy()
    self.panel:Destroy()
end

return Minimap
