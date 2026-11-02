-- Original procedural expressions; no face image uploads required.
local Faces={}
function Faces.Build(model,style)
    local folder=Instance.new("Folder");folder.Name="ProceduralFace";folder.Parent=model
    local function part(name,size,cf,color)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=model:GetPivot()*cf
        p.Color=color;p.Shape=Enum.PartType.Ball;p.Material=Enum.Material.SmoothPlastic
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Parent=folder;return p
    end
    local dark=Color3.fromRGB(32,40,62)
    for _,x in ipairs({-.91,.91}) do
        if style=="Wink" and x<0 then
            part("Wink",Vector3.new(1.15,.18,.25),CFrame.new(x,.55,-2.65),dark)
        else
            part("EyeWhite",Vector3.new(1.28,1.41,.60),CFrame.new(x,.55,-2.48),Color3.fromRGB(255,252,250))
            part("Pupil",Vector3.new(.53,.76,.29),CFrame.new(x+.07,.5,-2.82),dark)
            part("EyeShine",Vector3.new(.19,.22,.09),CFrame.new(x-.1,.76,-2.995),Color3.new(1,1,1))
        end
        if style=="Angry" then
            part("Brow",Vector3.new(1.15,.22,.22),CFrame.new(x,1.36,-2.58)*CFrame.Angles(0,0,x<0 and -.3 or .3),dark)
        elseif style=="Glasses" then
            local lens=part("Shades",Vector3.new(1.8,1,.30),CFrame.new(x,.6,-2.97),dark)
            lens.Shape=Enum.PartType.Block
            part("LensGlint",Vector3.new(.7,.1,.06),CFrame.new(x,.85,-3.14)*CFrame.Angles(0,0,.3),Color3.new(1,1,1))
        end
    end
    if style=="Glasses" then part("Bridge",Vector3.new(.6,.18,.15),CFrame.new(0,.7,-3),dark) end
    part("Smile",Vector3.new(style=="Angry" and .55 or .85,.24,.18),CFrame.new(0,-.74,-2.48),dark)
    for _,x in ipairs({-1.65,1.65}) do
        local p=part("Blush",Vector3.new(.48,.23,.17),CFrame.new(x,-.28,-2.11),Color3.fromRGB(255,138,149))
        p.Transparency=.27
    end
    return folder
end
return Faces
