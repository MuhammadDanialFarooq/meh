-- Reference-inspired motion/lighting and actual procedural cosmetic builders.
Instance=uiInstance
local Catalog=loadModule("CosmeticCatalog")
local hats,faces=Catalog.Get(loadModule("Config"))
assert(#hats==6 and #faces==4,"Default wardrobe incomplete")
local fakeCfg=table.clone(loadModule("Config"))
local custom=table.clone(fakeCfg)
custom.CosmeticFaces={{Name="Custom",Style="Classic",ImageId=123}}
local choice=Catalog.Selection(custom,2,1,Color3.new(0,1,0))
assert(choice.Hat=="Cap" and choice.FaceImageId==123,"Custom cosmetic preset ignored")
local Animator=loadModule("UIAnimator")
local animator=Animator.new(fakeCfg)
local b=uiInstance.new("TextButton")
animator:Bind(b)
b.MouseEnter:Fire()
for _=1,120 do animator:Update(1/120) end
assert(animator.buttons[1].scale.Scale>1.03 and animator.buttons[1].scale.Scale<1.05,"Hover spring did not settle")
b.MouseButton1Down:Fire()
for _=1,120 do animator:Update(1/120) end
assert(animator.buttons[1].scale.Scale<.96,"Press spring did not compress")
b.MouseButton1Up:Fire();b.MouseLeave:Fire()
for _=1,120 do animator:Update(1/120) end
assert(math.abs(animator.buttons[1].scale.Scale-1)<.001,"Button spring did not return")
local panel=uiInstance.new("Frame")
animator:Reveal(panel)
for _=1,240 do animator:Update(1/120) end
assert(math.abs(panel.Position.Y.Offset)<.01 and not next(animator.panels),"Panel entrance never settled")
fakeCfg.ReducedMotion=true;b.MouseEnter:Fire();animator:Update(.1)
assert(animator.buttons[1].scale.Scale==1,"Reduced motion left a hover bounce")
animator:Destroy();fakeCfg.ReducedMotion=false

services.Lighting={Brightness=3,ClockTime=8,Ambient=Color3.new(.2,.2,.2),OutdoorAmbient=Color3.new(.3,.3,.3),
    GlobalShadows=false,ShadowSoftness=.5,ColorShift_Bottom=Color3.new(0,0,0),ColorShift_Top=Color3.new(0,0,0),
    EnvironmentDiffuseScale=1,EnvironmentSpecularScale=1,ExposureCompensation=.1,children={}}
setfenv(factories.LightingController,setmetatable({Enum=enums,TweenInfo={new=function() return {} end}},
    {__index=getfenv(factories.LightingController)}))
local lighting=loadModule("LightingController").new(fakeCfg)
assert(services.Lighting.Brightness==1.5 and lighting.color.Contrast==.3,"Reference-inspired grade not applied")
lighting:SetMode("menu");assert(lighting.blur.Size==4,"Menu blur not set")
lighting:SetMode("playing");assert(lighting.blur.Size==0,"Gameplay retained blur")
lighting:SetMode("defeat");assert(lighting.blur.Size==0,"Death backdrop was blurred")
lighting:Destroy()
assert(services.Lighting.Brightness==3 and services.Lighting.ClockTime==8,"Lighting settings not restored")

-- Minimal 3D value/model doubles execute the real builders, not a mock catalog.
local V3={}
local vm={__add=function(a,b) return V3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
    __mul=function(a,n) return V3.new(a.X*n,a.Y*n,a.Z*n) end}
function V3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
local CF={}
local cm={__mul=function(a,b) return CF.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end}
function CF.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},cm) end
CF.Angles=function() return CF.new() end
CF.lookAt=function(v) return CF.new(v.X,v.Y,v.Z) end
local Geometry={new=function(class)
    local obj=uiInstance.new(class)
    function obj:GetChildren()
        local result={}
        for _,child in ipairs(self.children) do if not child.Destroyed then result[#result+1]=child end end
        return result
    end
    function obj:GetDescendants()
        local result={}
        local function walk(o)
            for _,c in ipairs(o:GetChildren()) do result[#result+1]=c;walk(c) end
        end
        walk(self);return result
    end
    function obj:IsA(kind) return kind==self.ClassName or (kind=="BasePart" and self.ClassName=="Part") end
    function obj:GetPivot() return self.pivot or CF.new() end
    function obj:PivotTo(cf) self.pivot=cf end
    return obj
end}
Instance=Geometry
for _,name in ipairs({"FaceBuilder","CharacterVisuals","CosmeticPreview"}) do
    setfenv(factories[name],setmetatable({Vector3=V3,CFrame=CF,Enum=enums},
        {__index=getfenv(factories[name])}))
end
local Characters=loadModule("CharacterVisuals")
local container=Geometry.new("Folder")
local characters=Characters.new(container,fakeCfg)
local entity={id=1,name="Tester",color=Color3.new(0,1,.5),isHuman=true,alive=true,pos=Vector2.zero,heading=0}
characters:Create(entity)
for hi,hat in ipairs(hats) do
    for fi,face in ipairs(faces) do
        characters:SetCosmetics(1,Catalog.Selection(fakeCfg,hi,fi,entity.color))
        characters:Update(entity,false)
        local r=characters.objects[1]
        assert(r.cosmetics.Hat==hat and #r.face:GetChildren()>0,"Cosmetic combination failed")
        if hat~="None" then assert(#r.hatParts>0,"Hat built no geometry") end
        assert(#r.model:GetDescendants()<70,"Cosmetic swaps leaked live geometry")
    end
end
characters:SetCosmetics(1,{Hat="None",FaceImageId=123})
local r=characters.objects[1]
assert(r.faceDecal.Texture=="rbxassetid://123" and r.faceDecal.Transparency==0,"Custom face image did not equip")
for _,p in ipairs(r.face:GetChildren()) do assert(p.Transparency==1,"Custom face did not hide procedural face") end
characters:Pulse(1,.8);assert(r.pulse==.8,"Gameplay character pulse missing")
local viewport=Geometry.new("ViewportFrame")
local preview=loadModule("CosmeticPreview").new(viewport,fakeCfg)
preview:Set(Catalog.Selection(fakeCfg,6,4,entity.color),entity.color)
preview:Update(.016,false)
assert(viewport.CurrentCamera==preview.camera and preview.characters.objects[1].cosmetics.Hat=="Wizard",
    "Live preview did not show selected style")
preview:Destroy();characters:Destroy()
print("[Paintland V39 TEST PASS] Spring settling, reduced motion, lighting restore, 24 hat/face combinations, custom image, preview and gameplay pulse")
