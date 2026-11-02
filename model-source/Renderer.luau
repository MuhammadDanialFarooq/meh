-- V20: single authoritative VISUAL representation in Workspace.
-- 3D actors, 3D land, 3D trails. PlayerGui is HUD/effects only.
local TrailRenderer = require(script.Parent.TrailRenderer)
local ChunkGeometry = require(script.Parent.ChunkGeometry)
local WorkspaceArena = require(script.Parent.WorkspaceArena)
local CharacterVisuals = require(script.Parent.CharacterVisuals)

local Renderer = {}
Renderer.__index = Renderer

local function effectViewport(parent)
    local frame = Instance.new("Frame")
    frame.Name = "ScreenEffectsOnly"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromScale(1, 1)
    frame.ClipsDescendants = true
    frame.Active = false
    frame.Parent = parent
    return frame
end

local function createLandPart(parent)
    local tile = Instance.new("Part")
    tile.Name = "PaintTop"
    tile.Anchored = true
    tile.CanCollide, tile.CanTouch, tile.CanQuery = false, false, false
    tile.CastShadow = false
    tile.Material = Enum.Material.SmoothPlastic
    tile.Parent = parent
    return tile
end

function Renderer.new(cfg, playerGui)
    local self = setmetatable({}, Renderer)
    self.cfg = cfg
    local oldScreen = playerGui:FindFirstChild("PaintlandGame")
    if oldScreen then oldScreen:Destroy() end
    -- Remove previous world-space GUI surfaces left by V17/V18/V19.
    for _, name in ipairs({"PaintlandFloorSurfaceV18", "PaintlandFloorSurfaceV17", "PaintlandFloorSurface"}) do
        local old = playerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end

    local screen = Instance.new("ScreenGui")
    screen.Name = "PaintlandGame"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 30
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Parent = playerGui
    self.screen = screen
    self.viewport = effectViewport(screen)
    self.arena = WorkspaceArena.new(self.viewport, cfg)
    self.characters = CharacterVisuals.new(self.arena.actorsFolder, cfg)
    self.actorObjects = self.characters.objects
    self.trailRenderer = TrailRenderer.new(self.arena.trailFolder, cfg)
    self.half = cfg.Grid * cfg.Cell / 2
    self.pixelScale = 1
    self.chunksWide = math.ceil(cfg.Grid / cfg.Chunk)
    self.chunkObjects = {}
    self.dirtySet, self.dirtyQueue, self.dirtyHead = {}, {}, 1
    self.world = nil
    self.leaderId = nil
    self.contourCanvas = nil  -- deprecated: never create a second territory image
    self.resizeConnection = self.viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Resize()
    end)
    self:Resize()
    return self
end

function Renderer:SetWorld(world)
    self.world = world
    self.arena.landFolder:ClearAllChildren()
    self.chunkObjects = {}
    self.dirtySet, self.dirtyQueue, self.dirtyHead = {}, {}, 1
    self.characters:Clear()
    self.trailRenderer:Reset()
    self.trailRenderer.grid = world and world.grid or nil
    self.leaderId = nil
    for id = 1, self.chunksWide * self.chunksWide do
        self:MarkChunk(id)
    end
end

function Renderer:MarkChunk(id)
    if self.dirtySet[id] then return end
    self.dirtySet[id] = true
    self.dirtyQueue[#self.dirtyQueue + 1] = id
end

function Renderer:MarkCell(index)
    local n = self.cfg.Grid
    local x = math.floor(((index - 1) % n) / self.cfg.Chunk)
    local y = math.floor(math.floor((index - 1) / n) / self.cfg.Chunk)
    self:MarkChunk(y * self.chunksWide + x + 1)
end

function Renderer:Resize()
    local view = self.viewport.AbsoluteSize
    if view.Y > 1 then
        self.pixelScale = view.Y / (self.cfg.WorldViewHeightStuds or 120)
    end
end

function Renderer:GetPlayerScreenPosition(pos, height)
    local camera = workspace.CurrentCamera
    if camera then
        local projected = camera:WorldToViewportPoint(Vector3.new(
            pos.X, height or self.cfg.CharacterHeight or 3.7, pos.Y))
        return Vector2.new(projected.X, projected.Y)
    end
    return self.viewport.AbsoluteSize * 0.5
end

function Renderer:RebuildChunk(id)
    if not self.world then return end
    local rectangles = ChunkGeometry.Rectangles(self.world.grid, self.cfg, id, self.chunksWide)
    local pool = self.chunkObjects[id]
    if not pool then pool={}; self.chunkObjects[id]=pool end
    local cell=self.cfg.Cell
    for i,rect in ipairs(rectangles) do
        local record=pool[i]
        if not record then
            local base=createLandPart(self.arena.landFolder)
            base.Name="ColorSkirt"
            local top=createLandPart(self.arena.landFolder)
            record={base=base,top=top}
            pool[i]=record
        end
        local owner=self.world.entities[rect.owner]
        local color=owner and owner.color or self.cfg.Colors[1]
        local width=(rect.x2-rect.x1+1)*cell
        local depth=(rect.y2-rect.y1+1)*cell
        local x=-self.half+(rect.x1+rect.x2-1)*.5*cell
        local z=-self.half+(rect.y1+rect.y2-1)*.5*cell
        record.base.Size=Vector3.new(width+.06,.15,depth+.06)
        record.base.Position=Vector3.new(x,.18,z)
        record.base.Color=color:Lerp(Color3.fromRGB(45,50,79),.23)
        record.base.Transparency=0
        record.top.Size=Vector3.new(width+.035,.13,depth+.035)
        record.top.Position=Vector3.new(x,.275,z)
        record.top.Color=color
        record.top.Transparency=0
    end
    for i=#rectangles+1,#pool do
        pool[i].base.Transparency=1
        pool[i].top.Transparency=1
    end
end

function Renderer:RenderChunks()
    local budget = self.cfg.MaxChunksPerFrame or 4
    local built = 0
    while built < budget and self.dirtyHead <= #self.dirtyQueue do
        local id = self.dirtyQueue[self.dirtyHead]
        self.dirtyHead += 1
        self.dirtySet[id] = nil
        if id then
            self:RebuildChunk(id)
            built += 1
        end
    end
    if self.dirtyHead > #self.dirtyQueue then
        self.dirtyQueue, self.dirtyHead = {}, 1
    end
end

function Renderer:SetLeader(id) self.leaderId = id end
function Renderer:ClearTrail(id) self.trailRenderer:Clear(id) end
function Renderer:RemoveEntityVisual(id)
    self.characters:Remove(id)
    self.trailRenderer:Clear(id)
end
function Renderer:ResetEntityVisual(id) self:RemoveEntityVisual(id) end
function Renderer:SetCosmetics(id, cosmetics) self.characters:SetCosmetics(id, cosmetics) end

function Renderer:RenderActor(entity)
    if not entity.alive then
        self:RemoveEntityVisual(entity.id)
        return
    end
    self.characters:Update(entity, self.leaderId == entity.id)
    self.trailRenderer:Render(entity)
end

function Renderer:Render(_, _)
    if not self.world then return end
    -- Terrain first for initial startup; entities remain independent of chunks.
    self:RenderChunks()
    for _, entity in ipairs(self.world.entities) do
        local ok, err = pcall(function() self:RenderActor(entity) end)
        if not ok then
            warn("[Paintland V20] Workspace actor/trail render failure for ID "
                .. tostring(entity.id) .. ": " .. tostring(err))
        end
    end
end

function Renderer:Destroy()
    if self.resizeConnection then self.resizeConnection:Disconnect() end
    self.characters:Destroy()
    self.trailRenderer:Reset()
    if self.arena then self.arena:Destroy() end
    if self.screen then self.screen:Destroy() end
end
return Renderer
