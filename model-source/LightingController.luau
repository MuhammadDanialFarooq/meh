-- Local reference-inspired afternoon grade. Only our own post effects are created;
-- previous base settings are restored when the game's screen is destroyed.
local Lighting=game:GetService("Lighting")
local TweenService=game:GetService("TweenService")
local Style={}
Style.__index=Style
function Style.new(cfg)
    local self=setmetatable({cfg=cfg,previous={},effects={}},Style)
    if cfg.StylizedLighting==false then return self end
    local settings={Brightness=1.5,ClockTime=14.1,Ambient=Color3.fromRGB(197,197,197),
        OutdoorAmbient=Color3.fromRGB(190,190,190),GlobalShadows=true,ShadowSoftness=.2,
        ColorShift_Bottom=Color3.fromRGB(141,48,255),ColorShift_Top=Color3.fromRGB(167,61,119),
        EnvironmentDiffuseScale=.75,EnvironmentSpecularScale=.1,ExposureCompensation=0}
    for key,value in pairs(settings) do self.previous[key]=Lighting[key];Lighting[key]=value end
    self.color=Instance.new("ColorCorrectionEffect")
    self.color.Name="PaintlandGrade";self.color.Enabled=true
    self.color.Brightness=-.04;self.color.Contrast=cfg.LightingContrast or .3
    self.color.Saturation=cfg.LightingSaturation or .35
    self.color.TintColor=Color3.new(1,1,1);self.color.Parent=Lighting
    self.blur=Instance.new("BlurEffect")
    self.blur.Name="PaintlandMenuBlur";self.blur.Size=0;self.blur.Parent=Lighting
    self.effects={self.color,self.blur}
    return self
end
function Style:SetMode(mode)
    if self.destroyed or not self.blur then return end
    if self.tween then self.tween:Cancel() end
    local size=mode=="cosmetics" and 8 or (mode=="menu" and (self.cfg.MenuBlurSize or 4) or 0)
    if self.cfg.ReducedMotion then self.blur.Size=size;return end
    self.tween=TweenService:Create(self.blur,TweenInfo.new(.35,Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out),{Size=size});self.tween:Play()
end
function Style:Destroy()
    if self.destroyed then return end
    self.destroyed=true
    if self.tween then self.tween:Cancel() end
    for _,effect in ipairs(self.effects) do effect:Destroy() end
    for key,value in pairs(self.previous) do Lighting[key]=value end
    table.clear(self.effects);table.clear(self.previous)
end
return Style
