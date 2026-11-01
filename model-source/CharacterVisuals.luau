-- V21: procedural toy character. All geometry is generated locally in Workspace.
-- No external character models, MeshIds, uploaded hats, or invisible face plates.
local CharacterVisuals = {}
CharacterVisuals.__index = CharacterVisuals

local function make(parent, name, size, cf, color, shape, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Shape = shape or Enum.PartType.Block
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Parent = parent
    return p
end

local function assetUri(value)
    if type(value) == "number" and value > 0 then
        return "rbxassetid://" .. tostring(math.floor(value))
    end
    if type(value) == "string" then
        if value:match("^%d+$") then return "rbxassetid://" .. value end
        if value:match("^rbxassetid://%d+$") then return value end
    end
    return nil
end

local function newLabel(root, entity)
    local bb = Instance.new("BillboardGui")
    bb.Name = "PlayerName"
    bb.Adornee = root
    bb.Size = UDim2.fromOffset(172, 30)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 4.55, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 240
    bb.Parent = root
    local text = Instance.new("TextLabel")
    text.Name = "Name"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBlack
    text.TextSize = 15
    text.TextColor3 = Color3.fromRGB(255,255,255)
    text.TextStrokeColor3 = Color3.fromRGB(38,44,71)
    text.TextStrokeTransparency = 0
    text.Text = entity.name
    text.Parent = bb
    local crown = Instance.new("TextLabel")
    crown.Name = "LeaderCrown"
    crown.AnchorPoint = Vector2.new(0.5,1)
    crown.Position = UDim2.fromScale(0.5,0)
    crown.Size = UDim2.fromOffset(32,27)
    crown.BackgroundTransparency = 1
    crown.Font = Enum.Font.GothamBlack
    crown.Text = "👑"
    crown.TextScaled = true
    crown.Visible = false
    crown.Parent = bb
    return text,crown
end

local function addHat(model, kind, color)
    local created = {}
    local function shape(name, size, cf, tone, typeShape)
        local p = make(model,name,size,model:GetPivot()*cf,tone,typeShape)
        created[#created+1] = p
        return p
    end
    if kind == "Crown" then
        local gold = Color3.fromRGB(255,208,54)
        shape("GoldBand",Vector3.new(3.6,.62,3.35),CFrame.new(0,3.23,0),gold,Enum.PartType.Ball)
        for i=-2,2 do
            local h = (i == 0) and 1.55 or 1.15
            shape("GoldPoint"..i,Vector3.new(.48,h,.5),CFrame.new(i*.63,3.70+(h-1.1)*.5,-.20),gold,Enum.PartType.Block)
        end
        shape("CrownGem",Vector3.new(.55,.55,.20),CFrame.new(0,3.40,-1.68),Color3.fromRGB(78,180,255),Enum.PartType.Ball)
    elseif kind == "Cap" then
        -- A curved cap, with a short rounded brim: no large blue cuboid in front.
        shape("CapCrown",Vector3.new(4.6,1.12,4.25),CFrame.new(0,3.0,0.15),color,Enum.PartType.Ball)
        shape("CapBrim",Vector3.new(3.0,.23,1.10),CFrame.new(0,2.77,-2.14),color,Enum.PartType.Ball)
    elseif kind == "TopHat" then
        local ink = Color3.fromRGB(39,38,69)
        shape("Brim",Vector3.new(4.6,.18,4.2),CFrame.new(0,3.20,0),ink,Enum.PartType.Ball)
        shape("Top",Vector3.new(3.1,2.12,3.0),CFrame.new(0,4.18,0),ink,Enum.PartType.Block)
        shape("Ribbon",Vector3.new(3.22,.30,3.1),CFrame.new(0,3.52,0),Color3.fromRGB(255,200,71))
    end
    return created
end

function CharacterVisuals.new(folder, cfg)
    return setmetatable({folder=folder,cfg=cfg,objects={},equipped={}},CharacterVisuals)
end

function CharacterVisuals:Create(entity)
    self:Remove(entity.id)
    local model=Instance.new("Model")
    model.Name="Player_"..entity.id
    model.Parent=self.folder
    local root=make(model,"Pivot",Vector3.new(.15,.15,.15),CFrame.new(),entity.color)
    root.Transparency=1
    model.PrimaryPart=root
    -- Feet and body are actual sphere geometry. No invisible accessory plates.
    local shadow=make(model,"SoftShadow",Vector3.new(5.5,.14,4.5),CFrame.new(0,-3.44,.38),
        Color3.fromRGB(43,54,73),Enum.PartType.Ball)
    shadow.Transparency=.65
    local feet={}
    for _,x in ipairs({-1.35,1.35}) do
        feet[#feet+1]=make(model,"LittleFoot",Vector3.new(1.95,.86,2.0),
            CFrame.new(x,-2.65,-.5),Color3.fromRGB(255,245,228),Enum.PartType.Ball)
    end
    local body=make(model,"BeanBody",Vector3.new(5.8,6.55,5.25),
        CFrame.new(),entity.color,Enum.PartType.Ball)
    -- Small glossy cheek highlight placed on the visible curved body.
    local shine=make(model,"CheekLight",Vector3.new(.65,.88,.32),
        CFrame.new(-1.38,1.45,-2.27)*CFrame.Angles(0,0,math.rad(-18)),
        Color3.fromRGB(255,255,255),Enum.PartType.Ball)
    shine.Transparency=.38
    -- Large expressive eyeballs, facing -Z in the model's local coordinates.
    local face=Instance.new("Folder")
    face.Name="ProceduralFace"
    face.Parent=model
    for _,x in ipairs({-.91,.91}) do
        make(face,"EyeWhite",Vector3.new(1.28,1.41,.60),CFrame.new(x,.55,-2.48),
            Color3.fromRGB(255,252,250),Enum.PartType.Ball)
        make(face,"Pupil",Vector3.new(.53,.76,.29),CFrame.new(x+.07,.5,-2.82),
            Color3.fromRGB(32,40,62),Enum.PartType.Ball)
        make(face,"EyeShine",Vector3.new(.19,.22,.09),CFrame.new(x-.10,.76,-2.995),
            Color3.fromRGB(255,255,255),Enum.PartType.Ball)
    end
    local mouth=make(face,"Smile",Vector3.new(.72,.27,.18),CFrame.new(0,-.74,-2.48),
        Color3.fromRGB(42,43,65),Enum.PartType.Ball)
    for _,x in ipairs({-1.65,1.65}) do
        local blush=make(face,"Blush",Vector3.new(.48,.23,.17),CFrame.new(x,-.28,-2.11),
            Color3.fromRGB(255,138,149),Enum.PartType.Ball)
        blush.Transparency=.27
    end
    -- Decal on the body, not a visible part in front of the camera.
    local faceDecal=Instance.new("Decal")
    faceDecal.Name="CustomFace"
    faceDecal.Face=Enum.NormalId.Front
    faceDecal.Transparency=1
    faceDecal.Parent=body
    local name,crown=newLabel(root,entity)
    local record={model=model,root=root,body=body,shine=shine,face=face,faceDecal=faceDecal,
        name=name,crown=crown,hatParts={},cosmetics={},createdAt=os.clock()}
    self.objects[entity.id]=record
    local cosmetics=self.equipped[entity.id] or
        (entity.isHuman and self.cfg.PlayerCosmetics or self.cfg.BotCosmetics) or {}
    self:SetCosmetics(entity.id,cosmetics)
    return record
end

function CharacterVisuals:SetCosmetics(id,cosmetics)
    cosmetics=cosmetics or {}
    self.equipped[id]=cosmetics
    local r=self.objects[id]
    if not r then return end
    for _,p in ipairs(r.hatParts) do p:Destroy() end
    r.hatParts={}
    r.hatParts=addHat(r.model,cosmetics.Hat or "None",
        cosmetics.HatColor or Color3.fromRGB(59,138,242))
    local image=assetUri(cosmetics.FaceImageId)
    r.faceDecal.Texture=image or ""
    r.faceDecal.Transparency=image and 0 or 1
    for _,p in ipairs(r.face:GetChildren()) do
        if p:IsA("BasePart") then p.Transparency=image and 1 or (p.Name=="Blush" and .27 or 0) end
    end
    -- A 2D hat badge is optional, but never creates opaque geometry in the scene.
    if r.hatBadge then r.hatBadge:Destroy(); r.hatBadge=nil end
    local hatImage=assetUri(cosmetics.HatImageId)
    if hatImage then
        local gui=Instance.new("BillboardGui")
        gui.Name="HatBadge"
        gui.Adornee=r.root
        gui.AlwaysOnTop=true
        gui.Size=UDim2.fromOffset(42,42)
        gui.StudsOffsetWorldSpace=Vector3.new(0,5.6,0)
        gui.MaxDistance=180
        gui.Parent=r.root
        local img=Instance.new("ImageLabel")
        img.Size=UDim2.fromScale(1,1)
        img.BackgroundTransparency=1
        img.Image=hatImage
        img.Parent=gui
        r.hatBadge=gui
    end
    r.cosmetics=cosmetics
end

function CharacterVisuals:Update(entity,isLeader)
    if not entity.alive then self:Remove(entity.id); return end
    local r=self.objects[entity.id] or self:Create(entity)
    r.name.Text=entity.name
    r.crown.Visible=isLeader
    r.body.Color=entity.color
    -- All movement is one Model:PivotTo, avoiding independently sliding parts.
    local t=os.clock()
    local bob=math.sin(t*7.3+entity.id)*.085
    local yaw=-entity.heading-math.pi/2
    local lean=math.sin(t*4.2+entity.id)*.025
    r.model:PivotTo(CFrame.new(entity.pos.X,(self.cfg.CharacterHeight or 3.7)+bob,entity.pos.Y)
        * CFrame.Angles(0,yaw,lean))
end

function CharacterVisuals:Remove(id)
    local r=self.objects[id]
    if r then r.model:Destroy() end
    self.objects[id]=nil
end
function CharacterVisuals:Clear()
    for id in pairs(self.objects) do self:Remove(id) end
end
function CharacterVisuals:Destroy()
    self:Clear()
    table.clear(self.equipped)
end
return CharacterVisuals
