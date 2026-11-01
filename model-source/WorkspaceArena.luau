-- V21 toy-like 3D playfield. One world-render path, no SurfaceGui terrain.
local Arena = {}
Arena.__index = Arena
local function part(parent, name, size, cf, color, material)
    local p=Instance.new("Part")
    p.Name=name
    p.Anchored=true
    p.Size=size
    p.CFrame=cf
    p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic
    p.CanCollide=false
    p.CanTouch=false
    p.CanQuery=false
    p.CastShadow=false
    p.Parent=parent
    return p
end
local function asset(v)
    if type(v)=="number" and v>0 then return "rbxassetid://"..math.floor(v) end
    if type(v)=="string" and v:match("^%d+$") then return "rbxassetid://"..v end
    if type(v)=="string" and v:match("^rbxassetid://%d+$") then return v end
    return nil
end
local function disk(parent,name,radius,thickness,y,color)
    local d=part(parent,name,Vector3.new(thickness,radius*2,radius*2),
        CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2),color)
    d.Shape=Enum.PartType.Cylinder
    return d
end

function Arena.new(_,cfg)
    for _,name in ipairs({"PaintlandRuntime","PaperPrototype","PaintlandWorld"}) do
        local old=workspace:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local folder=Instance.new("Folder")
    folder.Name="PaintlandRuntime"
    folder.Parent=workspace
    local size=cfg.Grid*cfg.Cell
    local radius=cfg.ArenaRadius or (size/2-cfg.Cell*2)
    part(folder,"OutsideGround",Vector3.new(size+1000,.4,size+1000),
        CFrame.new(0,-1.3,0),cfg.OutsideColor)
    disk(folder,"CircularDropShadow",radius+14,.8,-.90,Color3.fromRGB(58,57,90))
    disk(folder,"NavyArenaRing",radius+9,.52,-.50,Color3.fromRGB(51,58,105))
    disk(folder,"CandyArenaRing",radius+4,.36,-.32,Color3.fromRGB(248,151,90))
    local floor=disk(folder,"Playfield",radius,.28,-.12,cfg.FloorColor)
    floor.CanQuery=true
    local textureId = asset(cfg.FloorTextureId)
    if textureId then
        local surface=Instance.new("Texture")
        surface.Name="OptionalFloorTexture"
        -- Cylinder's local +X end-cap points upward after our rotation.
        surface.Face=Enum.NormalId.Right
        surface.Texture=textureId
        surface.StudsPerTileU=cfg.FloorTextureTileStuds or 32
        surface.StudsPerTileV=cfg.FloorTextureTileStuds or 32
        surface.Transparency=cfg.FloorTextureTransparency or .65
        surface.Parent=floor
    end
    -- Straight tile guides are clipped mathematically to the circle.
    local grid=Instance.new("Folder")
    grid.Name="FloorTileGrid"
    grid.Parent=folder
    local interval=cfg.ArenaTileStuds or 16
    local color=cfg.ArenaGridColor or Color3.fromRGB(213,218,223)
    local thick=cfg.ArenaGridThickness or .11
    for offset=-radius+interval,radius-interval,interval do
        local extent=math.sqrt(math.max(0,radius*radius-offset*offset))-1.0
        if extent>4 then
            local xline=part(grid,"TileLineX",Vector3.new(thick,.025,2*extent),
                CFrame.new(offset,.035,0),color)
            xline.Transparency=.63
            local zline=part(grid,"TileLineZ",Vector3.new(2*extent,.025,thick),
                CFrame.new(0,.035,offset),color)
            zline.Transparency=.63
        end
    end
    local land=Instance.new("Folder") land.Name="Land" land.Parent=folder
    local trails=Instance.new("Folder") trails.Name="Trails" trails.Parent=folder
    local actors=Instance.new("Folder") actors.Name="Characters" actors.Parent=folder
    local fx=Instance.new("Folder") fx.Name="LandEffects" fx.Parent=folder
    return setmetatable({folder=folder,floor=floor,half=size/2,cfg=cfg,
        landFolder=land,trailFolder=trails,actorsFolder=actors,effectsFolder=fx},Arena)
end
function Arena:Resize() end
function Arena:Destroy()
    if self.folder then self.folder:Destroy() end
end
return Arena
