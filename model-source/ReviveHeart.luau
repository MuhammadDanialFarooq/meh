-- Fixed heart silhouette with a draining fill. Only the separate contour pulses.
local Fonts=require(script.Parent.Fonts)
local Heart={}
Heart.__index=Heart
local ROWS=72
local function make(parent,class,name,props)
    local o=Instance.new(class);o.Name=name
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent;return o
end
local function frame(parent,name,props)
    props.BorderSizePixel=0;props.Active=false;props.Selectable=false
    return make(parent,"Frame",name,props)
end
local function silhouette()
    local polygon={}
    for i=0,240 do
        local t=i/240*math.pi*2
        local x=16*math.sin(t)^3
        local y=13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t)
        polygon[#polygon+1]={x=(x+16)/32,y=(12-y)/29}
    end
    local rows={}
    for row=1,ROWS do
        local scan=(row-.5)/ROWS
        local crossings={}
        for i=1,#polygon-1 do
            local a,b=polygon[i],polygon[i+1]
            if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan) then
                crossings[#crossings+1]=a.x+(b.x-a.x)*(scan-a.y)/(b.y-a.y)
            end
        end
        table.sort(crossings)
        -- Top scanlines cross two lobes. Keep the central notch empty rather
        -- than bridging the minimum/maximum intersections into a flat top.
        for i=1,#crossings-1,2 do
            local low,high=crossings[i],crossings[i+1]
            if high>low then rows[#rows+1]={y=(row-1)/ROWS,x=low,w=high-low,h=1/ROWS+.001} end
        end
    end
    return rows
end
local SHAPE=silhouette()
local function draw(parent,color,outline)
    local parts={}
    for _,r in ipairs(SHAPE) do
        if outline then
            for _,x in ipairs({r.x,r.x+r.w-.012}) do
                parts[#parts+1]=frame(parent,"PulseEdge",{Position=UDim2.fromScale(x,r.y),Size=UDim2.fromScale(.012,r.h),
                    BackgroundColor3=color,ZIndex=104})
            end
        else
            parts[#parts+1]=frame(parent,"HeartRow",{Position=UDim2.fromScale(r.x,r.y),Size=UDim2.fromScale(r.w,r.h),
                BackgroundColor3=color,ZIndex=105})
        end
    end
    return parts
end
function Heart.new(parent,cfg,isMuted)
    local self=setmetatable({cfg=cfg,isMuted=isMuted,remaining=4,total=4,lastSecond=nil,pulseAge=1,beepCount=0},Heart)
    self.root=frame(parent,"Heart",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(210,200),BackgroundTransparency=1,ZIndex=104})
    self.pulse=frame(self.root,"PulseOutline",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=104})
    self.pulseParts=draw(self.pulse,Color3.fromRGB(166,247,255),true)
    self.body=frame(self.root,"FixedHeart",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=105})
    draw(self.body,Color3.fromRGB(20,35,119),false)
    local inside=frame(self.body,"Inside",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromScale(.94,.94),BackgroundTransparency=1,ZIndex=106})
    draw(inside,Color3.fromRGB(17,91,153),false)
    self.fill=frame(inside,"Liquid",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=107})
    self.fillParts=draw(self.fill,Color3.fromRGB(255,62,89),false)
    local shine=frame(self.body,"Highlight",{Position=UDim2.fromScale(.14,.12),Size=UDim2.fromScale(.12,.1),
        BackgroundColor3=Color3.fromRGB(195,247,255),BackgroundTransparency=.55,ZIndex=108})
    make(shine,"UICorner","Round",{CornerRadius=UDim.new(1,0)})
    self.countdown=make(self.body,"TextLabel","Seconds",{BackgroundTransparency=1,Size=UDim2.fromScale(1,.65),
        Position=UDim2.fromScale(0,.21),Text="4",FontFace=Fonts.Bold,TextColor3=Color3.new(1,1,1),TextScaled=true,
        TextStrokeColor3=Color3.fromRGB(20,35,119),TextStrokeTransparency=0,Active=false,Selectable=false,ZIndex=109})
    make(self.countdown,"UITextSizeConstraint","TextSize",{MinTextSize=18,MaxTextSize=88})
    local id=cfg.ReviveCountdownSoundId
    if id==nil then id="rbxasset://sounds/electronicpingshort.wav" end
    id=tostring(id);if id:match("^%d+$") then id="rbxassetid://"..id end
    self.sound=make(self.root,"Sound","ReviveCountdownBeep",{SoundId=id,Volume=math.clamp(cfg.ReviveCountdownVolume or .35,0,1),Looped=false})
    self:Reset(4)
    return self
end
function Heart:Tick(second)
    if second<=0 then return end
    self.pulseAge=0
    if self.cfg.SoundEnabled==false or (self.isMuted and self.isMuted()) or self.sound.SoundId=="" then return end
    self.sound:Stop();self.sound.TimePosition=0;self.sound:Play();self.beepCount+=1
end
function Heart:Paint(remaining,total)
    local fraction=math.clamp(remaining/math.max(.001,total),0,1)
    local waterline=1-fraction
    for i,r in ipairs(SHAPE) do
        local y=math.max(r.y,waterline)
        local height=fraction>0 and math.max(0,math.min(1,r.y+r.h)-y) or 0
        local part=self.fillParts[i]
        part.Visible=height>0
        part.Position=UDim2.fromScale(r.x,y);part.Size=UDim2.fromScale(r.w,height)
    end
    self.fraction=fraction
end
function Heart:Reset(total)
    self.total=math.max(.001,total or 4);self.remaining=self.total
    self.lastSecond=nil;self.pulseAge=1
    self.countdown.Text=tostring(math.ceil(self.total));self:Paint(self.total,self.total)
    self:Stop()
end
function Heart:Update(dt,remaining,total,waiting)
    self.remaining=math.max(0,remaining);self.total=math.max(.001,total or self.total)
    self:Paint(self.remaining,self.total)
    local second=math.ceil(self.remaining)
    if waiting then
        self.countdown.Text="…";self.sound:Stop()
    else
        self.countdown.Text=tostring(second)
        if second~=self.lastSecond then
            self.lastSecond=second;self:Tick(second)
        end
    end
    self.pulseAge=math.min(1,self.pulseAge+math.max(0,dt)/.7)
    local age=self.pulseAge
    local visible=not self.cfg.ReducedMotion and not waiting and age<1
    self.pulse.Visible=visible
    if visible then
        self.pulse.Size=UDim2.fromScale(1+age*.24,1+age*.24)
        for _,part in ipairs(self.pulseParts) do part.BackgroundTransparency=.2+age*.8 end
    end
end
function Heart:Stop()
    self.sound:Stop();self.pulse.Visible=false
end
function Heart:Destroy()
    self:Stop();self.root:Destroy()
end
return Heart
