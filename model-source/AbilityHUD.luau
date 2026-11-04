-- A small control hint. The charge ring and READY badge live on the character.
local Fonts=require(script.Parent.Fonts)
local AbilityInput=require(script.Parent.AbilityInput)
local UIS=game:GetService("UserInputService")
local HUD={};HUD.__index=HUD
function HUD.new(screen,cfg,onRequest)
    local self=setmetatable({cfg=cfg,onRequest=onRequest,active=false,pending=0,state={}},HUD)
    local root=Instance.new("Frame");root.Name="AbilityHint";root.BackgroundTransparency=1
    root.Active=false;root.Visible=false;root.ZIndex=150;root.Parent=screen;self.root=root
    local text=Instance.new("TextLabel");text.Name="EquippedAbility";text.Size=UDim2.fromScale(1,1)
    text.BackgroundTransparency=1;text.Active=false;text.FontFace=Fonts.Bold;text.TextSize=11
    text.TextColor3=Color3.new(1,1,1);text.TextStrokeColor3=Color3.fromRGB(40,35,76);text.TextStrokeTransparency=0
    text.TextWrapped=true;text.ZIndex=151;text.Parent=root;self.label=text
    self.input=AbilityInput.new(cfg,function() self:Request() end)
    return self
end
function HUD:Request()
    if not self.active or not self.state.ready or self.pending>0 then return end
    self.pending=1;self.onRequest(self.state.equipped);self:Update(0)
end
function HUD:SetActive(active)
    self.active=active and self.cfg.AbilitiesEnabled~=false;self.root.Visible=self.active
    self.input:SetActive(self.active);if not self.active then self.pending=0 end
end
function HUD:SetState(state)
    self.state=state;if state.id then self.pending=0 end;self:Update(0)
end
function HUD:Update(dt)
    self.pending=math.max(0,self.pending-dt)
    local id=self.state.equipped or ""
    local prompt=UIS.TouchEnabled and "DOUBLE TAP" or (UIS.GamepadEnabled and "R2 / SPACE" or "SPACEBAR")
    local chargeHint=tostring(self.cfg.AbilityChargePerPercent or 20).." / 1% CAPTURE · "..tostring(self.cfg.AbilityChargePerKill or 35).." / KILL"
    self.label.Text=id=="" and "Equip an ability in Loadout" or
        (id:upper().." · "..(self.pending>0 and "…" or (self.state.ready and prompt or chargeHint)))
end
function HUD:Resize(size)
    local portrait=size.X<600 and size.Y>=500
    self.root.Size=UDim2.fromOffset(144,44)
    self.root.AnchorPoint=Vector2.new(portrait and 1 or .5,1)
    self.root.Position=portrait and UDim2.new(1,-12,1,-68) or UDim2.new(.5,0,1,-12)
end
function HUD:Destroy() self.input:Destroy();self.root:Destroy() end
return HUD
