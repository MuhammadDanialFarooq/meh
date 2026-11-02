-- Exercise real UI constructors and callbacks with layout/signal doubles.
-- This checks layout arithmetic and state; it does not emulate Roblox rendering.
local function signal()
    local s={handlers={}}
    function s:Connect(callback)
        table.insert(self.handlers,callback)
        return {Disconnect=function() end}
    end
    function s:Fire(...) for _,callback in ipairs(self.handlers) do callback(...) end end
    return s
end
local function axis(scale,offset) return {Scale=scale,Offset=offset} end
UDim2={new=function(xs,xo,ys,yo) return {X=axis(xs,xo),Y=axis(ys,yo)} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
local UDim={new=axis}
-- Module factories capture outer locals, so expose these through their environment.
-- Define globals needed by UI-only modules in their factory environment.
local enums=setmetatable({}, {__index=function(t,k)
    local values=setmetatable({}, {__index=function(_,name) return name end})
    rawset(t,k,values);return values
end})
local tweens={Create=function(_,obj,_,goals)
    return {Play=function() for k,v in pairs(goals) do obj[k]=v end end,Cancel=function() end}
end}
local services={RunService={IsStudio=function() return false end},TweenService=tweens,UserInputService={TouchEnabled=false},Players={LocalPlayer={UserId=0}}}
game.GetService=function(_,name) return services[name] or {} end
local deferred={}
local taskDouble={defer=function(f) f() end,delay=function(_,f) table.insert(deferred,f) end,spawn=function() end}
local uiInstance={new=function(class)
    local obj={ClassName=class,children={},Activated=signal(),Visible=true,
        AnchorPoint=Vector2.zero,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0)}
    function obj:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end end
    function obj:GetPropertyChangedSignal() return signal() end
    function obj:Destroy() self.Destroyed=true end
    function obj:ClearAllChildren() self.children={} end
    return setmetatable(obj,{__newindex=function(t,k,v)
        rawset(t,k,v)
        if k=="Parent" and v and v.children then table.insert(v.children,t) end
    end})
end}
-- Override UI factory environments while retaining actual dependencies and logic.
for _,name in ipairs({"UIController","HUDCanvas","LeaderboardController","MinimapController"}) do
    local env=setmetatable({UDim=UDim,Enum=enums,Instance=uiInstance,task=taskDouble,
        TweenInfo={new=function() return {} end},ColorSequence={new=function() return {} end}},
        {__index=getfenv(factories[name])})
    setfenv(factories[name],env)
    cache[name]=nil
end
Instance=uiInstance
local uiCfg=table.clone(loadModule("Config"))
local screen=uiInstance.new("ScreenGui")
screen.Parent={}
local viewport=uiInstance.new("Frame")
viewport.AbsoluteSize=Vector2.new(1280,720)
local renderer={screen=screen,viewport=viewport,SetLeader=function() end}
local playSkin,muted
local ui=loadModule("UIController").new(renderer,uiCfg,{
    onPlay=function(skin) playSkin=skin end,onSoundToggle=function(value) muted=value end})
assert(ui.overlay.Visible and not ui.hud.Visible,"Menu visibility broken")
assert(ui.soundButton.Text=="SOUND: OFF","UI did not reflect muted default")
ui.soundButton.Activated:Fire()
assert(muted==false and ui.soundButton.Text=="SOUND: ON","Unmute button failed")
ui.soundButton.Activated:Fire()
assert(muted==true,"Mute button failed")
ui.skins[3].button.Activated:Fire();ui.play.Activated:Fire()
assert(playSkin==3,"Menu failed to pass selected color")
ui:SetMode("playing")
assert(ui.hud.Visible and not ui.overlay.Visible,"Playing mode visibility broken")
local function rect(obj)
    local p=obj.Parent
    local pw,ph,px,py
    if p==screen then pw,ph=viewport.AbsoluteSize.X,viewport.AbsoluteSize.Y;px,py=0,0
    else
        local r=rect(p);px,py,pw,ph=r[1],r[2],r[3],r[4]
    end
    local w=obj.Size.X.Scale*pw+obj.Size.X.Offset
    local h=obj.Size.Y.Scale*ph+obj.Size.Y.Offset
    return {px+obj.Position.X.Scale*pw+obj.Position.X.Offset-w*obj.AnchorPoint.X,
        py+obj.Position.Y.Scale*ph+obj.Position.Y.Offset-h*obj.AnchorPoint.Y,w,h}
end
local function overlap(a,b)
    return a[1]<b[1]+b[3] and b[1]<a[1]+a[3] and a[2]<b[2]+b[4] and b[2]<a[2]+a[4]
end
for _,size in ipairs({{320,568},{375,667},{390,844},{640,360},{844,390},{900,600},{1280,720},{1920,1080}}) do
    viewport.AbsoluteSize=Vector2.new(size[1],size[2]);ui:Resize()
    local items={ui.progress.canvas,ui.killCard,ui.leaderboard.panel,ui.minimap.panel,ui.soundButton}
    local bounds={}
    for _,obj in ipairs(items) do
        local r=rect(obj);table.insert(bounds,r)
        assert(r[1]>=0 and r[2]>=0 and r[1]+r[3]<=size[1] and r[2]+r[4]<=size[2],
            obj.Name .. " leaves viewport at " .. size[1] .. "x" .. size[2])
    end
    for i=1,#bounds do for j=i+1,#bounds do
        assert(not overlap(bounds[i],bounds[j]),items[i].Name .. " overlaps " .. items[j].Name)
    end end
    local scale=ui.menuScale.Scale
    assert(scale>0 and 420*scale<=size[1]-32+1e-6 and 460*scale<=size[2]-110+1e-6,"Menu does not fit")
end
ui:SetMode("revive");assert(not ui.soundButton.Visible,"Sound button covers revive")
ui:SetMode("playing");assert(ui.soundButton.Visible,"Sound button not restored")
-- Results retain the death snapshot even if later HUD updates inspect the world.
local world={entities={{kills=7}},grid={counts={[1]=224},playableTotal=1000}}
ui:RecordDefeat(world)
world.grid.counts[1]=10
ui:ShowDefeat(world)
assert(ui.mode=="defeat" and ui.defeatOverlay.Visible and not ui.overlay.Visible and not ui.hud.Visible,"Defeat overlay not exclusive")
assert(ui.result.Text=="You conquered 22.4% land" and ui.defeatDetails.Text=="224 tiles  ·  7 eliminations","Death snapshot changed")
assert(not ui.skins[1].button.Visible and ui.result.Visible,"Color selector covers results")
playSkin=nil
ui.returnMenu.Activated:Fire()
assert(ui.mode=="menu" and playSkin==nil and ui.skins[1].button.Visible and not ui.result.Visible,
    "Defeat button restarted gameplay instead of returning to menu")
assert(ui.defeatOverlay.BackgroundColor3.R==0 and ui.defeatOverlay.BackgroundTransparency>.2
    and ui.defeatOverlay.BackgroundTransparency<.8,"Defeat did not preserve game through black tint")
assert(ui.replay:FindFirstChild("Icon").ClassName=="ImageLabel" and
    ui.returnMenu:FindFirstChild("Icon").ClassName=="ImageLabel","Death button icons are not images")
ui:ShowDefeat(world);playSkin=nil;ui.replay.Activated:Fire()
assert(playSkin==3,"Play Again lost selected color or did not start a run")
for _,size in ipairs({{320,568},{375,667},{640,360},{844,390},{1280,720}}) do
    viewport.AbsoluteSize=Vector2.new(size[1],size[2]);ui:Resize()
    local scale=ui.defeatScale.Scale
    assert(scale>0 and 420*scale<=size[1]-32+1e-6 and 350*scale<=size[2]-64+1e-6,
        "Death layout leaves viewport")
    assert(ui.replay.Position.Y.Offset+ui.replay.Size.Y.Offset<ui.returnMenu.Position.Y.Offset,
        "Death actions overlap")
    assert(ui.replay.Size.Y.Offset*scale>=44-1e-6,"Death buttons are too small for touch")
end
ui:NewRun();assert(ui.defeatStats==nil,"New run retained stale defeat stats")

local Revive=loadModule("ReviveController")
local ended=0
local r=setmetatable({active=true,state="countdown",remaining=.1,requestSerial=0,
    root={Visible=true},countdown={},cfg={ReviveTransactionTimeout=90},waitTime=0,
    callbacks={onTimeout=function() ended+=1 end}},Revive)
r:Update(.2)
assert(ended==1 and not r.active and not r.root.Visible,"Revive timeout did not finish run")
r:Update(10);r:EndRun();assert(ended==1,"Defeat triggered repeatedly")
r.active=true;r.state="countdown";r.root.Visible=true;r:EndRun()
assert(ended==2,"Declining revive did not finish run")
r.active=true;r.state="waiting";r.root.Visible=true
r:EndRun();r:Update(1)
assert(ended==2 and r.active,"Pending transaction was abandoned")
r.state="countdown";r.networkResolved=true;r.checkingAd=false
r.adButton={Active=false};r.buyButton={Active=false};r.creditButton={Active=false}
r:Update(0)
assert(ended==3 and not r.active,"Known unavailable revives did not finish run immediately")
r.active=true;r.state="countdown";r.checkingAd=true;r.remaining=5
r:Update(.1)
assert(ended==3 and r.active,"Availability discovery was mistaken for exhausted revives")
ui:Destroy();assert(ui.soundButton.Destroyed and ui.overlay.Destroyed,"UI teardown failed")
print("[Paintland V29 TEST PASS] Menu/play/color/mute/defeat states; frozen death stats, revive timeout/decline/transaction guard; HUD bounds at 8 sizes")
