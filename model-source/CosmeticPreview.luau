local Characters=require(script.Parent.CharacterVisuals)
local Preview={}
Preview.__index=Preview
function Preview.new(viewport,cfg)
    local world=Instance.new("WorldModel");world.Parent=viewport
    local camera=Instance.new("Camera");camera.FieldOfView=38
    camera.CFrame=CFrame.lookAt(Vector3.new(16,8,10),Vector3.new(0,4,0))
    camera.Parent=viewport;viewport.CurrentCamera=camera
    viewport.Ambient=Color3.fromRGB(190,190,200);viewport.LightColor=Color3.new(1,1,1)
    viewport.LightDirection=Vector3.new(-1,-1,-1)
    local entity={id=1,name="",color=cfg.Colors[1],isHuman=true,alive=true,pos=Vector2.zero,heading=0}
    local self=setmetatable({world=world,camera=camera,entity=entity,
        characters=Characters.new(world,cfg),angle=0},Preview)
    self.characters:Create(entity)
    self.characters.objects[1].name.Parent.Enabled=false
    return self
end
function Preview:Set(cosmetics,color)
    self.entity.color=color
    self.characters:SetCosmetics(1,cosmetics)
    self.characters:Update(self.entity,false)
end
function Preview:Update(dt,reduced)
    if not reduced then self.angle+=math.clamp(dt,0,.1)*.18 end
    self.entity.heading=math.sin(self.angle)*.35
    self.characters:Update(self.entity,false)
end
function Preview:Destroy()
    self.characters:Destroy();self.world:Destroy();self.camera:Destroy()
end
return Preview
