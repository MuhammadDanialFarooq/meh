-- End-of-run territory replay. The snapshot is copied before any later match changes.
local Fonts=require(script.Parent.Fonts)
local ButtonEffects=require(script.Parent.ButtonEffects)
local Results={}
Results.__index=Results
local WHITE=Color3.fromRGB(250,253,255)
local INK=Color3.fromRGB(26,38,114)
local CYAN=Color3.fromRGB(0,224,217)
local function make(parent,class,name,props)
    local o=Instance.new(class);o.Name=name
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent;return o
end
local function frame(parent,name,props)
    props.BorderSizePixel=0;props.Active=false;props.Selectable=false
    return make(parent,"Frame",name,props)
end
local function round(o,r) make(o,"UICorner","Round",{CornerRadius=UDim.new(0,r)}) end
local function outline(o,width,color)
    make(o,"UIStroke","Outline",{Thickness=width,Color=color or INK,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function text(parent,name,value,size)
    return make(parent,"TextLabel",name,{Text=value,FontFace=Fonts.Bold,TextSize=size,
        TextColor3=WHITE,TextStrokeColor3=INK,TextStrokeTransparency=0,BackgroundTransparency=1,
        BorderSizePixel=0,Active=false,Selectable=false,ZIndex=104})
end
local function button(parent,name,value,color)
    local b=make(parent,"TextButton",name,{Text=value,FontFace=Fonts.Bold,TextSize=21,TextColor3=WHITE,
        TextStrokeColor3=INK,TextStrokeTransparency=0,BackgroundColor3=color,BorderSizePixel=0,
        Active=false,Selectable=true,AutoButtonColor=false,AnchorPoint=Vector2.new(.5,.5),ZIndex=105})
    round(b,18);outline(b,2.5)
    make(b,"UIGradient","Shading",{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(179,232,149)),Rotation=90})
    return b
end
-- Merge identical horizontal runs vertically. Exact cells; no downsampling.
local function rectangles(size,predicate)
    local finished,open={},{}
    for y=1,size do
        local nextOpen={};local x=1
        while x<=size do
            if predicate((y-1)*size+x) then
                local first=x
                repeat x+=1 until x>size or not predicate((y-1)*size+x)
                local key=tostring(first)..":"..tostring(x)
                local r=open[key]
                if r then r.h+=1;open[key]=nil
                else r={x=first-1,y=y-1,w=x-first,h=1} end
                nextOpen[key]=r
            else x+=1 end
        end
        for _,r in pairs(open) do finished[#finished+1]=r end
        open=nextOpen
    end
    for _,r in pairs(open) do finished[#finished+1]=r end
    return finished
end
function Results.new(screen,cfg,callbacks)
    local self=setmetatable({cfg=cfg,callbacks=callbacks,active=false,elapsed=0,progress=0,ready=false,
        targetPercent=0,ownedCount=0,columns={},snapshot=nil},Results)
    self.root=frame(screen,"TerritoryResults",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),
        Visible=false,ZIndex=100})
    self.root.Active=true
    make(self.root,"UIGradient","Ocean",{Color=ColorSequence.new(Color3.fromRGB(9,87,225),Color3.fromRGB(0,191,227)),Rotation=90})
    self.content=frame(self.root,"Content",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundTransparency=1,ZIndex=101})
    self.title=text(self.content,"Title","Look at your mark!",31)
    self.caption=text(self.content,"Caption","YOUR TERRITORY",12)
    self.caption.FontFace=Fonts.Regular;self.caption.TextStrokeTransparency=.6
    self.track=frame(self.content,"CoverageTrack",{BackgroundColor3=Color3.fromRGB(32,35,174),ZIndex=102,ClipsDescendants=true})
    round(self.track,14);outline(self.track,2)
    self.fill=frame(self.track,"CapturedFill",{Size=UDim2.fromScale(0,1),BackgroundColor3=CYAN,ZIndex=103})
    round(self.fill,12)
    self.percentLabel=text(self.track,"Percent","0.0%",22)
    self.percentLabel.Position=UDim2.fromOffset(12,0);self.percentLabel.Size=UDim2.new(1,-24,1,0)
    self.percentLabel.TextXAlignment=Enum.TextXAlignment.Left
    self.stage=frame(self.content,"MapStage",{BackgroundColor3=Color3.fromRGB(0,155,207),BackgroundTransparency=.2,ZIndex=102})
    round(self.stage,28);outline(self.stage,1,Color3.fromRGB(104,239,248))
    self.map=frame(self.stage,"ArenaMap",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundTransparency=1,ZIndex=103})
    self.neutral=frame(self.map,"PlayableShape",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=103})
    self.reveal=frame(self.map,"CaptureReveal",{Size=UDim2.fromScale(0,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=104})
    self.paint=frame(self.reveal,"CapturedShape",{BackgroundTransparency=1,ZIndex=104})
    self.details=text(self.content,"Details","",14)
    self.details.FontFace=Fonts.Regular;self.details.TextStrokeTransparency=.5;self.details.TextWrapped=true
    self.status=text(self.content,"Status","Counting your color…",12)
    self.status.FontFace=Fonts.Regular;self.status.TextStrokeTransparency=.6
    self.play=button(self.content,"PlayAgain","PLAY AGAIN",Color3.fromRGB(151,244,59))
    self.menuButton=button(self.content,"MainMenu","MAIN MENU",Color3.fromRGB(48,140,234))
    self:Resize(Vector2.new(1280,720))
    ButtonEffects.Bind(self.play,cfg,{play=true});ButtonEffects.Bind(self.menuButton,cfg)
    local function choose(callback)
        if not self.active or not self.ready then return end
        self.ready=false;self.play.Active=false;self.menuButton.Active=false
        if callback then callback() end
    end
    self.play.Activated:Connect(function() choose(callbacks.onPlay) end)
    self.menuButton.Activated:Connect(function() choose(callbacks.onMainMenu) end)
    return self
end
function Results:Resize(viewport)
    if viewport.X<1 or viewport.Y<1 then return end
    local width=math.min(900,viewport.X-24)
    local height=math.min(690,viewport.Y-24)
    local wide=viewport.X>=568 and viewport.X/viewport.Y>1.4
    self.content.Size=UDim2.fromOffset(width,height)
    if wide then
        local left=math.min(math.floor(width*.48),height-12)
        self.stage.Position=UDim2.fromOffset(0,(height-left)/2);self.stage.Size=UDim2.fromOffset(left,left)
        local x=left+22;local w=width-x
        self.title.Position=UDim2.fromOffset(x,12);self.title.Size=UDim2.fromOffset(w,48)
        self.title.TextSize=viewport.X<720 and 22 or 31
        self.caption.Position=UDim2.fromOffset(x,64);self.caption.Size=UDim2.fromOffset(w,20)
        self.track.Position=UDim2.fromOffset(x,90);self.track.Size=UDim2.fromOffset(w,38)
        self.details.Position=UDim2.fromOffset(x,137);self.details.Size=UDim2.fromOffset(w,34)
        self.status.Position=UDim2.fromOffset(x,173);self.status.Size=UDim2.fromOffset(w,18)
        self.play.Position=UDim2.fromOffset(x+w/2,math.min(height-76,222))
        self.menuButton.Position=UDim2.fromOffset(x+w/2,math.min(height-24,278))
        ButtonEffects.SetSize(self.play,UDim2.fromOffset(w,46));ButtonEffects.SetSize(self.menuButton,UDim2.fromOffset(w,44))
    else
        self.title.Position=UDim2.fromOffset(0,0);self.title.Size=UDim2.fromOffset(width,48)
        self.title.TextSize=width<340 and 26 or 31
        self.caption.Position=UDim2.fromOffset(0,51);self.caption.Size=UDim2.fromOffset(width,20)
        self.track.Position=UDim2.fromOffset(8,80);self.track.Size=UDim2.fromOffset(width-16,38)
        local mapSize=math.min(width-12,height-298)
        self.stage.Position=UDim2.fromOffset((width-mapSize)/2,133);self.stage.Size=UDim2.fromOffset(mapSize,mapSize)
        self.details.Position=UDim2.fromOffset(0,142+mapSize);self.details.Size=UDim2.fromOffset(width,28)
        self.status.Position=UDim2.fromOffset(0,172+mapSize);self.status.Size=UDim2.fromOffset(width,20)
        self.play.Position=UDim2.fromOffset(width/2,height-82);self.menuButton.Position=UDim2.fromOffset(width/2,height-26)
        ButtonEffects.SetSize(self.play,UDim2.fromOffset(width-16,52));ButtonEffects.SetSize(self.menuButton,UDim2.fromOffset(width-16,44))
    end
    self.mapPixels=math.max(1,self.stage.Size.X.Offset-28)
    self.map.Size=UDim2.fromOffset(self.mapPixels,self.mapPixels)
    -- Fixed inner dimensions prevent the artwork stretching with the reveal window.
    self.paint.Size=UDim2.fromOffset(self.mapPixels,self.mapPixels)
    self:PaintProgress(self.progress)
end
function Results:PaintProgress(progress)
    self.progress=math.clamp(progress,0,1)
    self.percentLabel.Text=string.format("%.1f%%",self.targetPercent*self.progress)
    self.fill.Size=UDim2.fromScale(self.targetPercent/100*self.progress,1)
    local edge=0
    local target=self.ownedCount*self.progress
    if self.progress>=1 then edge=1
    elseif target>0 then
        local before=0
        for x,n in ipairs(self.columns) do
            if n>0 and before+n>=target then edge=((x-1)+(target-before)/n)/#self.columns;break end
            before+=n
        end
    end
    self.reveal.Size=UDim2.fromScale(edge,1)
end
function Results:Show(snapshot)
    self:Hide()
    local size=math.max(1,math.floor(snapshot.size or self.cfg.Grid or 112))
    local mask,cells={},{}
    for i=1,size*size do
        mask[i]=snapshot.mask and snapshot.mask[i]==true or false
        cells[i]=mask[i] and snapshot.cells and snapshot.cells[i]==true or false
    end
    self.snapshot={size=size,mask=mask,cells=cells,count=snapshot.count or 0,kills=snapshot.kills or 0,
        percent=math.clamp(snapshot.percent or 0,0,100),color=snapshot.color or CYAN}
    self.targetPercent=self.snapshot.percent;self.ownedCount=0;self.columns=table.create(size,0)
    for i,owned in ipairs(cells) do if owned then
        self.ownedCount+=1;local x=(i-1)%size+1;self.columns[x]+=1
    end end
    self.neutral:ClearAllChildren();self.paint:ClearAllChildren()
    for _,set in ipairs({{parent=self.neutral,predicate=function(i) return mask[i] end,color=WHITE},
        {parent=self.paint,predicate=function(i) return cells[i] end,color=self.snapshot.color}}) do
        for _,r in ipairs(rectangles(size,set.predicate)) do
            frame(set.parent,"MapRun",{Position=UDim2.fromScale(r.x/size,r.y/size),Size=UDim2.fromScale(r.w/size,r.h/size),
                BackgroundColor3=set.color,ZIndex=104})
        end
    end
    self.fill.BackgroundColor3=self.snapshot.color
    self.details.Text=string.format("%d tiles  ·  %d eliminations",self.snapshot.count,self.snapshot.kills)
    self.status.Text="Counting your color…"
    self.elapsed=0;self.ready=false;self.active=true;self.root.Visible=true
    self.play.Active=false;self.menuButton.Active=false
    self:PaintProgress(0)
    self:Update(0)
end
function Results:Update(dt)
    if not self.active or self.ready then return end
    self.elapsed+=math.max(0,dt)
    local duration=math.max(.1,self.cfg.ResultsRevealSeconds or 2)
    local t=self.cfg.ReducedMotion and 1 or math.min(1,self.elapsed/duration)
    self:PaintProgress(1-(1-t)^3)
    if t>=1 then
        self.ready=true;self.play.Active=true;self.menuButton.Active=true
        self.status.Text="Every little loop counts."
    end
end
function Results:Hide()
    self.active=false;self.ready=false;self.root.Visible=false
    self.play.Active=false;self.menuButton.Active=false
end
function Results:Destroy()
    self:Hide();self.root:Destroy()
end
return Results
