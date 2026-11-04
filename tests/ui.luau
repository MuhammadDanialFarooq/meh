-- Exercise real UI constructors and callbacks with layout/signal doubles.
-- This checks layout arithmetic and state; it does not emulate Roblox rendering.
local function signal()
    local s={handlers={}}
    function s:Connect(callback)
        local connection={Connected=true,callback=callback}
        function connection:Disconnect() self.Connected=false end
        table.insert(self.handlers,connection)
        return connection
    end
    function s:Fire(...)
        for _,connection in ipairs(table.clone(self.handlers)) do
            if connection.Connected then connection.callback(...) end
        end
    end
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
local tweens={created={}}
function tweens:Create(obj,info,goals)
    local tween={Object=obj,Info=info,Goals=goals,Cancelled=false}
    function tween:Play() self.Played=true;for k,v in pairs(goals) do obj[k]=v end end
    function tween:Cancel() self.Cancelled=true end
    table.insert(self.created,tween)
    return tween
end
local services={RunService={IsStudio=function() return false end},TweenService=tweens,
    UserInputService={TouchEnabled=false,InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),GetFocusedTextBox=function() return nil end},Players={LocalPlayer={UserId=0}}}
game.GetService=function(_,name) return services[name] or {} end
local deferred={}
local taskDouble={defer=function(f) f() end,delay=function(_,f) table.insert(deferred,f) end,spawn=function() end}
local uiInstance={}
function uiInstance.new(class)
    local values={ClassName=class,children={},Activated=signal(),Visible=true,Enabled=true,Active=true,
        MouseEnter=signal(),MouseLeave=signal(),SelectionGained=signal(),SelectionLost=signal(),
        InputBegan=signal(),InputEnded=signal(),Destroying=signal(),
        AnchorPoint=Vector2.zero,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0)}
    local properties={}
    local obj
    obj=setmetatable({},{__index=values,__newindex=function(_,key,value)
        local old=values[key]
        if old==value then return end
        if key=="Parent" then
            if old and old.children then
                local index=table.find(old.children,obj)
                if index then table.remove(old.children,index) end
            end
            if value and value.children then table.insert(value.children,obj) end
        end
        values[key]=value
        if properties[key] then properties[key]:Fire() end
    end})
    -- Backing values ensure even writes to existing fields run property signals.
    function values:FindFirstChild(name)
        for _,child in ipairs(values.children) do if child.Name==name then return child end end
    end
    function values:GetPropertyChangedSignal(name)
        if not properties[name] then properties[name]=signal() end
        return properties[name]
    end
    function values:IsA(name)
        if name==class or name=="Instance" then return true end
        if name=="GuiObject" then
            return class=="Frame" or class=="CanvasGroup" or class=="TextLabel" or class=="TextButton"
                or class=="TextBox" or class=="ImageLabel" or class=="ImageButton" or class=="ScrollingFrame"
        end
        return name=="GuiButton" and (class=="TextButton" or class=="ImageButton")
    end
    function values:Play() self.Playing=true;self.PlayCount=(self.PlayCount or 0)+1 end
    function values:Stop() self.Playing=false end
    function values:GetChildren() return table.clone(values.children) end
    function values:ClearAllChildren()
        for _,child in ipairs(table.clone(values.children)) do child:Destroy() end
    end
    function values:Destroy()
        if values.Destroyed then return end
        values.Destroyed=true
        values.Destroying:Fire()
        self:ClearAllChildren()
        self.Parent=nil
    end
    return obj
end
-- Override UI factory environments while retaining actual dependencies and logic.
for _,name in ipairs({"AbilityInput","LoadoutMenu","AbilityHUD","WalletHUD","ResultsScreen","ReviveHeart","ReviveController","Fonts","MainMenu","ButtonEffects","UIController","HUDCanvas","LeaderboardController","MinimapController"}) do
    local env=setmetatable({UDim=UDim,Enum=enums,Instance=uiInstance,task=taskDouble,
        TweenInfo={new=function() return {} end},ColorSequence={new=function() return {} end},
        Font={new=function(family,weight,style) return {Family=family,Weight=weight,Style=style} end},
        NumberSequenceKeypoint={new=function(time,value,envelope) return {Time=time,Value=value,Envelope=envelope or 0} end},
        NumberSequence={new=function(a,b)
            return {Keypoints=type(a)=="table" and a or {{Time=0,Value=a},{Time=1,Value=b or a}}}
        end}},
        {__index=getfenv(factories[name])})
    setfenv(factories[name],env)
    cache[name]=nil
end
Instance=uiInstance
local uiCfg=table.clone(loadModule("Config"))
uiCfg.SoundMutedByDefault=true -- explicitly exercise muted session toggle
local screen=uiInstance.new("ScreenGui")
screen.Parent=uiInstance.new("Folder")
local viewport=uiInstance.new("Frame")
viewport.AbsoluteSize=Vector2.new(1280,720)
local renderer={screen=screen,viewport=viewport,SetLeader=function() end}
local playSkin,muted
local ui=loadModule("UIController").new(renderer,uiCfg,{
    onPlay=function(skin) playSkin=skin end,onSoundToggle=function(value) muted=value end})
ui.play.Activated:Fire();assert(playSkin==nil,"Play bypassed loading loadout")
ui:SetWallet({loaded=true,coins=0,gems=0,persistent=false})
assert(ui.overlay.Visible and not ui.hud.Visible,"Menu visibility broken")
assert(ui.overlay.BackgroundTransparency>=.5,"Menu tint hides the live match")
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
for _,size in ipairs({{320,568},{375,667},{390,844},{568,320},{640,360},{844,390},{900,600},{1280,720},{1920,1080}}) do
    viewport.AbsoluteSize=Vector2.new(size[1],size[2]);ui:Resize()
    local items={ui.progress.canvas,ui.killCard,ui.leaderboard.panel,ui.minimap.panel,ui.soundButton,ui.wallet.root,ui.abilities.root}
    local bounds={}
    for _,obj in ipairs(items) do
        local r=rect(obj);table.insert(bounds,r)
        assert(r[1]>=0 and r[2]>=0 and r[1]+r[3]<=size[1] and r[2]+r[4]<=size[2],
            obj.Name .. " leaves viewport at " .. size[1] .. "x" .. size[2])
    end
    for i=1,#bounds do for j=i+1,#bounds do
        assert(not overlap(bounds[i],bounds[j]),items[i].Name .. " overlaps " .. items[j].Name)
    end end
    local menuBounds=rect(ui.menu.root)
    assert(menuBounds[1]>=0 and menuBounds[2]>=0
        and menuBounds[1]+menuBounds[3]<=size[1] and menuBounds[2]+menuBounds[4]<=size[2],
        "Menu does not fit "..size[1].."x"..size[2])
end
ui:SetMode("revive");assert(not ui.soundButton.Visible,"Sound button covers revive")
ui:SetMode("playing");assert(ui.soundButton.Visible,"Sound button not restored")
-- Results retain the death snapshot even if later HUD updates inspect the world.
local world={entities={{kills=7,color=Color3.fromRGB(23,196,158)}},grid={size=4,total=16,
    mask=table.create(16,true),owners={1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0},counts={[1]=4},playableTotal=16}}
ui:RecordDefeat(world)
world.grid.counts[1]=1;world.grid.owners[1]=0
ui:ShowDefeat(world)
assert(ui.mode=="defeat" and ui.defeatOverlay.Visible and not ui.overlay.Visible and not ui.hud.Visible,"Results not exclusive")
assert(ui.defeatStats.count==4 and ui.defeatStats.cells[1],"Death snapshot mutated")
playSkin=nil;ui.replay.Activated:Fire();assert(playSkin==nil,"Replay skipped automatic reveal")
ui:UpdatePresentation(3)
assert(ui.result.Text=="25.0%","Animated result did not reach death percentage")
ui.returnMenu.Activated:Fire()
assert(ui.mode=="menu" and playSkin==nil and not ui.defeatOverlay.Visible,"Results menu routing broken")
ui:ShowDefeat(world);ui:UpdatePresentation(3);ui.replay.Activated:Fire()
assert(playSkin==3,"Play Again lost selected color")
for _,size in ipairs({{320,568},{375,667},{568,320},{640,360},{844,390},{1280,720}}) do
    viewport.AbsoluteSize=Vector2.new(size[1],size[2]);ui:Resize()
    local play,back=rect(ui.replay),rect(ui.returnMenu)
    assert(play[4]>=44 and back[4]>=44,"Results touch controls too small")
    assert(not overlap(play,back),"Results actions overlap")
    for _,bounds in ipairs({play,back,rect(ui.results.stage)}) do
        assert(bounds[1]>=0 and bounds[2]>=0 and bounds[1]+bounds[3]<=size[1] and bounds[2]+bounds[4]<=size[2],"Results outside viewport")
    end
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
print("[Paintland V42 TEST PASS] Menu/play/color/mute/defeat states; frozen death stats, revive guards; HUD/wallet/ability bounds and overlap at 9 sizes")
