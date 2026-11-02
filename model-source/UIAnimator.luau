-- Frame-rate-independent damped springs; one update from the existing game loop.
local Animator={}
Animator.__index=Animator
local function spring(x,v,target,dt)
    local w,z=18,.65
    local wd=w*math.sqrt(1-z*z)
    local r=x-target
    local c,s,d=math.cos(wd*dt),math.sin(wd*dt),math.exp(-z*w*dt)
    return target+d*(r*c+(v+z*w*r)/wd*s),d*(v*c-(z*w*v+w*w*r)/wd*s)
end
function Animator.new(cfg)
    return setmetatable({cfg=cfg,buttons={},panels={},connections={}},Animator)
end
function Animator:Bind(button)
    local scale=Instance.new("UIScale");scale.Name="InteractionSpring";scale.Parent=button
    local entry={button=button,scale=scale,x=1,v=0,target=1,hover=false}
    self.buttons[#self.buttons+1]=entry
    local function connect(event,callback) self.connections[#self.connections+1]=event:Connect(callback) end
    connect(button.MouseEnter,function() entry.hover=true;entry.target=1.04 end)
    connect(button.MouseLeave,function() entry.hover=false;entry.target=1 end)
    connect(button.SelectionGained,function() entry.target=1.04 end)
    connect(button.SelectionLost,function() entry.target=1 end)
    connect(button.MouseButton1Down,function() entry.target=.95 end)
    connect(button.MouseButton1Up,function() entry.target=entry.hover and 1.04 or 1 end)
    connect(button.Activated,function() entry.v=entry.v+2;entry.target=1 end)
end
function Animator:Reveal(panel)
    self.panels[panel]={x=self.cfg.ReducedMotion and 0 or 26,v=0,base=UDim2.fromScale(.5,.5)}
end
function Animator:Update(dt)
    if self.destroyed then return end
    dt=math.clamp(dt or 0,0,.1)
    for _,e in ipairs(self.buttons) do
        if self.cfg.ReducedMotion then e.x,e.v=1,0
        else e.x,e.v=spring(e.x,e.v,e.target,dt) end
        e.scale.Scale=math.clamp(e.x,.9,1.07)
    end
    for panel,e in pairs(self.panels) do
        if self.cfg.ReducedMotion then e.x,e.v=0,0 else e.x,e.v=spring(e.x,e.v,0,dt) end
        panel.Position=UDim2.new(e.base.X.Scale,e.base.X.Offset,e.base.Y.Scale,e.base.Y.Offset+e.x)
        if math.abs(e.x)<.01 and math.abs(e.v)<.01 then
            panel.Position=e.base;self.panels[panel]=nil
        end
    end
end
function Animator:Destroy()
    self.destroyed=true
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    table.clear(self.connections);table.clear(self.buttons);table.clear(self.panels)
end
return Animator
