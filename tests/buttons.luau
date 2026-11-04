-- Exercise actual Size goals, including mixed scale/offset layouts and resizing.
local effects=loadModule("ButtonEffects")
local buttonParent=uiInstance.new("Frame");buttonParent.Parent=screen
local b=uiInstance.new("TextButton");b.Parent=buttonParent
b.Position=UDim2.new(.2,18,.3,142);b.Size=UDim2.new(.8,-36,0,44)
b.BackgroundColor3=Color3.fromRGB(82,230,186);b.ZIndex=50
local oldPosition,oldSize=b.Position,b.Size
local cfg={ReducedMotion=false,ButtonParticlesEnabled=true,ButtonSlashEnabled=true}
local state=effects.Bind(b,cfg,{play=true})
assert(b.AnchorPoint.X==.5 and b.AnchorPoint.Y==.5,"Button anchor not centered")
assert(not b:FindFirstChild("InteractionScale"),"Button still uses a second scaling transform")
local fixedPosition=b.Position
local function width(size,parent) return size.X.Scale*parent+size.X.Offset end
for _,parentWidth in ipairs({296,370,1280}) do
    local center=fixedPosition.X.Scale*parentWidth+fixedPosition.X.Offset
    local restingWidth=width(oldSize,parentWidth)
    assert(math.abs(center-restingWidth*.5-(oldPosition.X.Scale*parentWidth+oldPosition.X.Offset))<1e-6,
        "Anchor conversion moved the resting left edge")
    b.MouseEnter:Fire()
    local grown=width(b.Size,parentWidth)
    local leftGrowth=(center-restingWidth/2)-(center-grown/2)
    local rightGrowth=(center+grown/2)-(center+restingWidth/2)
    assert(grown>restingWidth and math.abs(leftGrowth-rightGrowth)<1e-6,"Growth is not symmetric")
    assert(b.Position==fixedPosition,"Hover moved the fixed center")
    b.InputBegan:Fire({UserInputType=enums.UserInputType.Touch})
    assert(width(b.Size,parentWidth)<restingWidth,"Touch press did not compress the button")
    assert(b.Position==fixedPosition,"Press moved the fixed center")
    b.InputEnded:Fire({UserInputType=enums.UserInputType.Touch})
    b.MouseLeave:Fire()
    assert(math.abs(width(b.Size,parentWidth)-restingWidth)<1e-6,"Interaction compounded the base size")
end
assert(#state.particles==8 and #state.idle==6,"Play effects missing or exceeding their fixed budgets")
assert(state.shineInner:FindFirstChild("UIGradient") or #state.shineInner.children>0,"Reference shine gradient absent")
assert(state.sparkles[1].Image=="rbxassetid://96254055681570","Reference sparkle image not used")
local instances=#b.children
for _=1,10 do state.lastBurst=-math.huge;state:Burst() end
assert(#b.children==instances and #state.particles==8,"Effects allocate new objects for each burst")
local activeFX=table.clone(state.fx)
local activeIdle=table.clone(state.idle)
buttonParent.Visible=false
assert(state.factor==1 and #state.fx==0 and #state.idle==0,"Hiding ancestor did not reset effects")
for _,t in ipairs(activeFX) do assert(t.Cancelled,"Hidden button retained burst tween") end
for _,t in ipairs(activeIdle) do assert(t.Cancelled,"Hidden button retained idle tween") end
assert(not state.shine.Visible and not state.sparkleLayer.Visible,"Hidden button kept looping visuals")
for _,spark in ipairs(state.particles) do assert(not spark.Visible,"Hidden button kept particles") end
local hiddenTweenCount=#tweens.created
b.InputEnded:Fire({UserInputType=enums.UserInputType.Touch});b.MouseLeave:Fire();b.SelectionLost:Fire()
assert(#tweens.created==hiddenTweenCount,"Late input restarted hidden animation")
buttonParent.Visible=true
assert(#state.idle==6,"Returning to menu did not resume effects")
b.Active=false;b.MouseEnter:Fire();assert(state.factor==1 and #state.idle==0,"Disabled button animated")
cfg.ReducedMotion=true;b.Active=true;b.MouseEnter:Fire()
assert(state.factor==1 and #state.idle==0,"Reduced motion still scales or animates")
state.lastBurst=-math.huge;b.Activated:Fire();assert(#state.fx==0,"Reduced motion emitted burst")
cfg.ReducedMotion=false;state:Reset()
b.MouseEnter:Fire();effects.SetSize(b,UDim2.fromOffset(132,44));b.MouseLeave:Fire()
assert(b.Size.X.Offset==132 and b.Size.Y.Offset==44,"Explicit resize lost the new baseline")
local depth=uiInstance.new("Frame");depth.Parent=buttonParent;depth.Size=UDim2.fromOffset(138,48)
local c=uiInstance.new("TextButton");c.Parent=buttonParent;c.Size=UDim2.fromOffset(132,44)
c.ZIndex=50;c.BackgroundColor3=Color3.fromRGB(82,230,186)
local linked=effects.Bind(c,cfg,{depth=depth})
c.MouseEnter:Fire();c.MouseLeave:Fire()
assert(depth.Size.X.Offset==138 and depth.Size.Y.Offset==48,"Depth lost its independent resting size")
local ending=table.clone(state.idle);b:Destroy()
assert(state.destroyed and #state.connections==0,"Destroyed button retained listeners")
for _,t in ipairs(ending) do assert(t.Cancelled,"Destroyed button retained idle tween") end
local fonts=loadModule("Fonts")
assert(fonts.Bold.Family=="rbxasset://fonts/families/Montserrat.json" and fonts.Bold.Weight==enums.FontWeight.Bold,
    "Bold Montserrat is not configured")
assert(fonts.Regular.Weight==enums.FontWeight.Regular,"Regular Montserrat is not configured")
print("[Paintland V40 TEST PASS] Symmetric Size growth, stable center/baseline, pooled reference effects, ancestor/disable/destroy cleanup, Montserrat weights")
