do
-- Visual controllers run against value doubles; this does not emulate rendering.
local cf={};cf.__index=cf;cf.__mul=function(a) return a end
local frame={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},cf) end,Angles=function() return setmetatable({},cf) end}
local env=setmetatable({Vector3=Vector3,CFrame=frame,UDim=UDim,Enum=enums,Instance=uiInstance,
    TweenInfo={new=function(duration) return {Duration=duration} end}},{__index=getfenv(factories.UIController)})
for _,name in ipairs({"AbilityIndicator","KillBlockTrail"}) do setfenv(factories[name],env);cache[name]=nil end
local root=uiInstance.new("Part");root.Parent=screen
local parent=uiInstance.new("Folder");parent.Parent=screen
local cfg=table.clone(netCfg)
local color=Color3.new(.9,.3,.6)
local e={id=1,userId=10,spawnRevision=1,alive=true,equippedAbility="Dash",abilityCharge=35,abilityRequired=100,
    color=color,pos=Vector2.new(0,0),heading=0}
local ring=loadModule("AbilityIndicator").new(root,parent,cfg)
ring:Update(e,.016)
assert(ring.gui.Enabled and ring.badge.Text=="DASH · 65 TO GO" and ring.badge.TextColor3==color,"Charge billboard has wrong count/color")
assert(ring.tween.Goals.Value==.35 and ring.tween.Info.Duration==cfg.AbilityRingTweenSeconds,"Ring didn't tween normalized charge")
assert(#ring.parts==48,"Ring geometry allocation changed")
for _,p in ipairs(ring.parts) do assert(not p.CanCollide and not p.CanTouch and not p.CanQuery,"Charge ring affects gameplay collision") end
local prior=ring.tween;e.abilityCharge=100;ring:Update(e,.016)
assert(prior.Cancelled and ring.badge.Text=="READY · DASH","New charge didn't cancel old tween/show READY")
e.pos=Vector2.new(10,10);ring:Update(e,.016)
assert(ring.parts[1].CFrame.X>10,"Ring failed to follow actor")
e.equippedAbility="";ring:Update(e,.016)
assert(not ring.gui.Enabled and ring.parts[1].Transparency==1,"Unequipped ring remained visible")
cfg.ReducedMotion=true;e.equippedAbility="Dash";e.abilityCharge=20;ring:Update(e,.016)
assert(ring.value.Value==.2 and ring.scale.Scale==1,"Reduced motion still tweens/pulses")
local gui,folder=ring.gui,ring.folder;ring:Destroy();assert(gui.Destroyed and folder.Destroyed,"Indicator cleanup leaked objects")
cfg.ReducedMotion=false
local target={world={entities={e}},arena={effectsFolder=parent}}
local blocks=loadModule("KillBlockTrail").new(target,cfg)
local victim={color=Color3.new(.2,.5,1),pos=Vector2.new(-15,-15)}
blocks:Emit(victim,e)
assert(#blocks.active==1 and #blocks.active[1].blocks==7,"Victim didn't spawn a block chain")
local item=blocks.active[1].blocks[1];local original=item.pos
blocks:Update(.2);assert((item.pos-original).Magnitude>0,"Blocks failed to catch up to killer")
e.pos=Vector2.new(20,0);blocks:Update(.1);assert(#blocks.active[1].history>1,"Following path wasn't sampled")
for _=1,30 do blocks:Emit(victim,e) end
assert(blocks.total<=cfg.KillBlockTrailMaxParts,"Kill block pool grew without bound")
blocks:Update(3);assert(#blocks.active==0 and #blocks.free==blocks.total,"Blocks didn't absorb/recycle")
local total=blocks.total;blocks:Emit(victim,e);assert(blocks.total==total,"Effect didn't reuse pool")
e.spawnRevision+=1;blocks:Update(.01);assert(#blocks.active==0,"Blocks followed a new life/slot")
blocks:Emit(victim,e);e.alive=false;blocks:Update(.01);assert(#blocks.active==0,"Blocks survived killer death")
e.alive=true;cfg.ReducedMotion=true;blocks:Emit(victim,e);assert(#blocks.active==0,"Reduced motion still emits blocks")
blocks:Destroy();assert(blocks.total==0 and #blocks.free==0,"Block pool wasn't destroyed")
root:Destroy();parent:Destroy()
print("[Paintland V43 TEST PASS] Ring tween targets/cancellation, matching-color READY/remaining charge, reduced motion, block following/pool bounds/death and teardown")
end
