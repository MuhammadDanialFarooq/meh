-- Recognizes a deliberate double tap, never a steering drag or UI interaction.
local Input={};Input.__index=Input
local function point(i) return Vector2.new(i.Position.X,i.Position.Y) end
function Input.new(cfg,activate,uis,clock)
    uis=uis or game:GetService("UserInputService")
    local self=setmetatable({cfg=cfg,activate=activate,uis=uis,clock=clock or os.clock,active=false,connections={}},Input)
    self.connections[1]=uis.InputBegan:Connect(function(i,processed) self:Begin(i,processed) end)
    self.connections[2]=uis.InputChanged:Connect(function(i) self:Move(i) end)
    self.connections[3]=uis.InputEnded:Connect(function(i,processed) self:End(i,processed) end)
    self.connections[4]=uis.WindowFocusReleased:Connect(function() self:Reset() end)
    return self
end
function Input:Reset() self.touch=nil;self.lastTap=nil end
function Input:SetActive(active) self.active=active;if not active then self:Reset() end end
function Input:Begin(i,processed)
    if not self.active then return end
    if processed or self.uis:GetFocusedTextBox() then self:Reset();return end
    if i.KeyCode==Enum.KeyCode.Space or i.KeyCode==Enum.KeyCode.ButtonR2 then self.activate();return end
    if i.UserInputType~=Enum.UserInputType.Touch then return end
    if self.touch then self.touch.invalid=true;self.lastTap=nil;return end
    self.touch={input=i,start=point(i),time=self.clock(),distance=0}
end
function Input:Move(i)
    local t=self.touch
    if t and t.input==i then t.distance=math.max(t.distance,(point(i)-t.start).Magnitude) end
end
function Input:End(i,processed)
    local t=self.touch
    if not t or t.input~=i then return end
    self:Move(i);self.touch=nil
    local now=self.clock()
    if not self.active or processed or t.invalid or self.uis:GetFocusedTextBox()
        or now-t.time>.25 or t.distance>(self.cfg.AbilityTapMaxMovement or 18) then self.lastTap=nil;return end
    local previous=self.lastTap;local at=point(i)
    if previous and now-previous.time<=(self.cfg.AbilityDoubleTapSeconds or .3) and (at-previous.point).Magnitude<=64 then
        self.lastTap=nil;self.activate()
    else self.lastTap={time=now,point=at} end
end
function Input:Destroy()
    self:SetActive(false);for _,c in ipairs(self.connections) do c:Disconnect() end;table.clear(self.connections)
end
return Input
