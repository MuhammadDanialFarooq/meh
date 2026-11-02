-- Session-only cosmetic choices; no purchase or persistent ownership implied.
local Catalog={}
Catalog.Hats={"None","Cap","Crown","TopHat","Halo","Wizard"}
Catalog.Faces={
    {Name="Happy",Style="Classic"},{Name="Wink",Style="Wink"},
    {Name="Fierce",Style="Angry"},{Name="Shades",Style="Glasses"},
}
function Catalog.Get(cfg)
    local hats,faces=cfg.CosmeticHats,cfg.CosmeticFaces
    return hats and #hats>0 and hats or Catalog.Hats,faces and #faces>0 and faces or Catalog.Faces
end
function Catalog.Selection(cfg,hatIndex,faceIndex,color)
    local hats,faces=Catalog.Get(cfg)
    local face=faces[faceIndex] or faces[1]
    return {Hat=hats[hatIndex] or "None",FaceStyle=face.Style or "Classic",
        FaceImageId=face.ImageId or 0,HatColor=color,HatImageId=0}
end
function Catalog.Random(cfg,rng,color)
    local hats,faces=Catalog.Get(cfg)
    return Catalog.Selection(cfg,rng:NextInteger(1,#hats),rng:NextInteger(1,#faces),color)
end
return Catalog
