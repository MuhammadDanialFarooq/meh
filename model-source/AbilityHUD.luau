local Registry=require(script.Parent.AbilityRegistry)
local Fonts=require(script.Parent.Fonts)
local ButtonEffects=require(script.Parent.ButtonEffects)
local UIS=game:GetService("UserInputService")
local HUD={};HUD.__index=HUD
local INK=Color3.fromRGB(40,35,76)
local function make(parent,class,name,p)
    local o=Instance.new(class);o.Name=name;for k,v in pairs(p) do o[k]=v end;o.Parent=parent;return o
end
function HUD.new(screen,cfg,onRequest)
    local self=setmetatable({cfg=cfg,onRequest=onRequest,active=false,buttons={},remaining={},pending={}},HUD)
    self.root=make(screen,"Frame","Abilities",{BackgroundTransparency=1,Visible=false,ZIndex=150,Active=false})
    for _,ability in ipairs(Registry.List) do
        local button=make(self.root,"TextButton",ability.Id,{AnchorPoint=Vector2.new(.5,.5),Text="",
            BackgroundColor3=ability.Color,BorderSizePixel=0,AutoButtonColor=false,ZIndex=151})
        make(button,"UICorner","Round",{CornerRadius=UDim.new(0,16)})
        make(button,"UIStroke","Outline",{Color=INK,Thickness=2})
        local title=make(button,"TextLabel","Name",{Position=UDim2.fromOffset(2,8),Size=UDim2.new(1,-4,0,17),
            Text=ability.Name,TextColor3=INK,FontFace=Fonts.Bold,TextSize=11,BackgroundTransparency=1,Active=false,ZIndex=152})
        local status=make(button,"TextLabel","Cooldown",{Position=UDim2.fromOffset(2,29),Size=UDim2.new(1,-4,0,22),
            Text=ability.Key,TextColor3=INK,FontFace=Fonts.Bold,TextSize=16,BackgroundTransparency=1,Active=false,ZIndex=152})
        ButtonEffects.SetSize(button,UDim2.fromOffset(68,60));ButtonEffects.Bind(button,cfg)
        button.Activated:Connect(function() self:Request(ability.Id) end)
        self.buttons[ability.Id]={button=button,title=title,status=status,definition=ability}
    end
    self.input=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        for _,ability in ipairs(Registry.List) do
            if input.KeyCode==Enum.KeyCode[ability.Key] or input.KeyCode==Enum.KeyCode[ability.Gamepad] then
                self:Request(ability.Id);return
            end
        end
    end)
    return self
end
function HUD:Request(id)
    if not self.active or (self.remaining[id] or 0)>0 or (self.pending[id] or 0)>0 then return end
    self.pending[id]=1
    self.onRequest(id)
    self:Update(0)
end
function HUD:SetActive(active)
    self.active=active and self.cfg.AbilitiesEnabled~=false
    self.root.Visible=self.active
    if not self.active then table.clear(self.pending) end
end
function HUD:SetState(state)
    self.remaining=table.clone(state.cooldowns or {})
    if state.id then self.pending[state.id]=nil end
    self:Update(0)
end
function HUD:Update(dt)
    for id,view in pairs(self.buttons) do
        local left=math.max(0,(self.remaining[id] or 0)-(self.active and dt or 0));self.remaining[id]=left
        local waiting=math.max(0,(self.pending[id] or 0)-dt);self.pending[id]=waiting
        view.status.Text=waiting>0 and "…" or (left>0 and (tostring(math.ceil(left)).."s") or (UIS.TouchEnabled and "READY" or view.definition.Key))
        view.status.TextSize=UIS.TouchEnabled and left<=0 and 11 or 16
        view.button.BackgroundTransparency=(left>0 or waiting>0) and .4 or 0
    end
end
function HUD:Resize(size)
    local portrait=size.X<600 and size.Y>=500
    local columns=math.min(portrait and 2 or 4,#Registry.List)
    local rows=math.ceil(#Registry.List/math.max(1,columns))
    self.root.Size=UDim2.fromOffset(columns*76-8,rows*68-8)
    self.root.AnchorPoint=Vector2.new(portrait and 1 or .5,1)
    self.root.Position=portrait and UDim2.new(1,-12,1,-68) or UDim2.new(.5,0,1,-12)
    for i,ability in ipairs(Registry.List) do
        self.buttons[ability.Id].button.Position=UDim2.fromOffset(((i-1)%columns)*76+34,math.floor((i-1)/columns)*68+30)
    end
end
function HUD:Destroy()
    self.input:Disconnect();self.root:Destroy()
end
return HUD
