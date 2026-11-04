-- V42: elastic slime character. Visual deformation never changes the PaperIO collider.
-- No external character models, MeshIds, uploaded hats, or invisible face plates.
local SlimeVisuals=require(script.Parent.SlimeVisuals)
local Fonts=require(script.Parent.Fonts)
local AbilityIndicator=require(script.Parent.AbilityIndicator)
local Catalog=require(script.Parent.LoadoutCatalog)
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
    text.FontFace = Fonts.Bold
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
    crown.FontFace = Fonts.Bold
    crown.Text = "👑"
    crown.TextScaled = true
    crown.Visible = false
    crown.Parent = bb
    return text,crown
end

local function addHat(model, kind, color)
    local created = {}
    local function shape(name, size, cf, tone, typeShape)
        local p = make(model,name,size,model:GetPivot()*CFrame.new(0,-.8,0)*cf,tone,typeShape)
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
    -- Body and lobes use actual rounded geometry. No invisible accessory plates.
    local shadow=make(model,"SoftShadow",Vector3.new(5.5,.14,4.5),CFrame.new(0,-2.35,.38),
        Color3.fromRGB(43,54,73),Enum.PartType.Ball)
    shadow.Transparency=.65
    -- Intersecting rounded lobes share the owner's paint color and lag separately
    -- on turns, making the silhouette behave like a soft puddle rather than feet.
    local lobes={}
    for i=1,4 do
        local angle=(i-1)*math.pi/2+math.pi/4
        lobes[i]=make(model,"SlimeLobe"..i,Vector3.new(2.7,1.45,2.8),
            CFrame.new(math.cos(angle)*1.65,-1.62,math.sin(angle)*1.65),entity.color,Enum.PartType.Ball)
    end
    local body=make(model,"SlimeBody",Vector3.new(5.8,4.8,5.5),
        CFrame.new(),entity.color,Enum.PartType.Ball)
    -- Small glossy cheek highlight placed on the visible curved body.
    local shine=make(model,"CheekLight",Vector3.new(.65,.88,.32),
        CFrame.new(-1.38,1.25,-2.14)*CFrame.Angles(0,0,math.rad(-18)),
        Color3.fromRGB(255,255,255),Enum.PartType.Ball)
    shine.Transparency=.38
    -- Large expressive eyeballs, facing -Z in the model's local coordinates.
    local face=Instance.new("Folder")
    face.Name="ProceduralFace"
    face.Parent=model
    for _,x in ipairs({-.91,.91}) do
        make(face,"EyeWhite",Vector3.new(1.28,1.41,.60),CFrame.new(x,.35,-2.48),
            Color3.fromRGB(255,252,250),Enum.PartType.Ball)
        make(face,"Pupil",Vector3.new(.53,.76,.29),CFrame.new(x+.07,.3,-2.82),
            Color3.fromRGB(32,40,62),Enum.PartType.Ball)
        make(face,"EyeShine",Vector3.new(.19,.22,.09),CFrame.new(x-.10,.56,-2.995),
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
    local record={model=model,root=root,body=body,shine=shine,face=face,faceDecal=faceDecal,lobes=lobes,shadow=shadow,
        elastic=SlimeVisuals.new(entity.pos,entity.heading),lastTime=os.clock(),rest={},
        name=name,crown=crown,hatParts={},cosmetics={},createdAt=os.clock()}
    self.objects[entity.id]=record
    record.indicator=AbilityIndicator.new(root,self.folder,self.cfg)
    record.characterId=entity.characterId
    local cosmetics=self.equipped[entity.id] or
        (entity.isHuman and self.cfg.PlayerCosmetics or self.cfg.BotCosmetics) or {}
    local character=Catalog.ByCharacter[entity.characterId]
    if character and character.Id~="Slime" then cosmetics=table.clone(cosmetics);cosmetics.Hat=character.Hat end
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
    -- Keep original local transforms; never recapture already-deformed body parts.
    for _,part in ipairs(r.model:GetDescendants()) do
        if part:IsA("BasePart") and part~=r.root and not r.rest[part] then
            r.rest[part]={size=part.Size,cf=r.root.CFrame:ToObjectSpace(part.CFrame)}
        end
    end
    for part in pairs(r.rest) do if not part.Parent then r.rest[part]=nil end end
end

function CharacterVisuals:Update(entity,isLeader)
    if not entity.alive then self:Remove(entity.id); return end
    local r=self.objects[entity.id] or self:Create(entity)
    if r.characterId~=entity.characterId then r=self:Create(entity) end
    r.name.Text=entity.name
    r.crown.Visible=isLeader
    r.body.Color=entity.color
    local now=os.clock()
    r.indicator:Update(entity,now-r.lastTime)
    local elastic=SlimeVisuals.Step(r.elastic,entity.pos,entity.heading,now-r.lastTime,
        self.cfg.ReducedMotion or self.cfg.SlimeVisualsEnabled==false)
    r.lastTime=now
    local yaw=-entity.heading-math.pi/2
    local rootCF=CFrame.new(entity.pos.X,(self.cfg.CharacterHeight or 3.7)-1+elastic.bob,entity.pos.Y)
        *CFrame.Angles(0,yaw,0)
    r.root.CFrame=rootCF
    local deformation=CFrame.Angles(-elastic.lean,0,-elastic.turn*.7)
    for part,rest in pairs(r.rest) do
        if part.Parent then
            local at=rest.cf.Position
            if part==r.shadow then
                part.Size=Vector3.new(rest.size.X*elastic.x,rest.size.Y,rest.size.Z*elastic.z)
                part.CFrame=rootCF*rest.cf
            else
                local isLobe=table.find(r.lobes,part)
                local isBody=part==r.body or isLobe
                if isBody then
                    part.Color=entity.color
                    local wave=isLobe and math.sin(elastic.phase+isLobe*1.5)*.035 or 0
                    part.Size=Vector3.new(rest.size.X*(elastic.x+wave),rest.size.Y*elastic.y,rest.size.Z*(elastic.z-wave))
                end
                -- Face and accessories follow the same soft displacement without
                -- stretching their shapes, so eyes remain clear and readable.
                local localPosition=Vector3.new(at.X*elastic.x,at.Y*elastic.y-(1-elastic.y)*2.3,at.Z*elastic.z)
                if isLobe then localPosition+=Vector3.new(elastic.turn*math.sin(isLobe)*.65,0,elastic.lean*.8) end
                part.CFrame=rootCF*deformation*CFrame.new(localPosition)*rest.cf.Rotation
            end
        end
    end
end

function CharacterVisuals:Remove(id)
    local r=self.objects[id]
    if r then r.indicator:Destroy();r.model:Destroy() end
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
