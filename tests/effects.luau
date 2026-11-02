-- Actual effect controllers, with value/UI doubles. No rendering claim.
function Color3.new(r,g,b)
    local c={R=r,G=g,B=b}
    function c:Lerp(other,t)
        return Color3.new(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t)
    end
    return c
end
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
for _,name in ipairs({"KillFeedback","ArcadeEffects","LandMergeEffects"}) do
    setfenv(factories[name],setmetatable({UDim=UDim,Enum=enums,Instance=uiInstance,
        Vector3=Vector3,task=taskDouble,TweenInfo={new=function() return {} end}},
        {__index=getfenv(factories[name])}))
end
local fxCfg=table.clone(loadModule("Config"))
local feedback=loadModule("KillFeedback").new(screen,fxCfg)
feedback.layer.AbsoluteSize=Vector2.new(640,480)
local killer={color=Color3.new(0,1,.5),pos=Vector2.new(10,10),killStreak=1,isHuman=true,alive=true}
local victim={color=Color3.new(1,0,.5),pos=Vector2.new(30,30),name="Rival"}
feedback:OnKill(victim,killer)
assert(feedback.primary.Text=="ELIMINATED","First kill callout incorrect")
feedback:Update(.2);killer.killStreak=2;feedback:OnKill(victim,killer)
assert(feedback.primary.Text=="DOUBLE KILL","Rapid double kill not detected")
feedback:Update(.2);killer.killStreak=3;feedback:OnKill(victim,killer)
assert(feedback.primary.Text=="TRIPLE KILL","Rapid triple kill not detected")
feedback:Update(4);killer.killStreak=4;feedback:OnKill(victim,killer)
assert(feedback.primary.Text=="ELIMINATED","Distant kills counted as a multi-kill")
feedback:Reset();feedback:OnKill(victim,killer)
assert(feedback.combo==1,"New life kept a visual combo")
fxCfg.ReducedMotion=true;feedback:Update(.01)
assert(feedback.scale.Scale==1 and feedback.group.Position.Y.Offset==0,"Reduced motion retained kill bounce")
feedback:Destroy()
fxCfg.ReducedMotion=false
local folder=uiInstance.new("Folder")
folder.Parent={}
local projected=0
local effectRenderer={screen=screen,viewport={AbsoluteSize=Vector2.new(640,480)},pixelScale=4,
    arena={effectsFolder=folder},world={entities={killer}},
    GetPlayerScreenPosition=function(_,point,height)
        projected+=1
        assert(height==.5,"Ground effect projected at wrong height")
        return Vector2.new(200+point.X,200+point.Y)
    end}
local cut=Vector2.new(3,4)
local arcade=loadModule("ArcadeEffects").new(effectRenderer,fxCfg)
arcade:Elimination(victim,killer,{position=cut})
assert(#arcade.activeRings==2 and arcade.activeRings[1].pos==cut,"Kill burst did not use cut position")
assert(#arcade.activeSparks>0 and arcade.activeSparks[1].pos==cut,"Kill sparks spawned at victim head")
arcade:Update(.05)
assert(projected>0,"Effects bypassed real camera projection")
for _=1,50 do arcade:Elimination(victim,killer,{position=cut}) end
assert(arcade.totalRings<=fxCfg.ImpactMaxRings and arcade.totalSparks<=fxCfg.ImpactMaxSparks,"Impact pools unbounded")
arcade:Clear();assert(#arcade.activeRings==0 and #arcade.activeSparks==0,"Impact reset left active objects")
fxCfg.ReducedMotion=true;arcade:Elimination(victim,killer,{position=cut})
assert(#arcade.activeRings==0 and #arcade.activeSparks==0,"Reduced motion retained burst")
arcade:Destroy();fxCfg.ReducedMotion=false
fxCfg.WorkspaceMergePartLimit=4;fxCfg.TerritoryMergeOverlayLimit=4
local merge=loadModule("LandMergeEffects").new(effectRenderer,fxCfg)
local changed={[1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[11]=true}
merge:Emit(killer,victim,changed,{position=cut})
assert(#merge.active<=4 and #merge.active>0,"Merge overlay budget broken")
for _,item in ipairs(merge.active) do assert(item.part.Position.Y>.34,"Merge overlay hidden inside land surface") end
for _=1,30 do merge:Update(.1) end
assert(#merge.active==0 and #merge.pool<=4,"Merge did not finish/recycle")
local allocated=#folder.children
merge:Emit(killer,victim,changed,{position=cut});merge:Clear()
assert(#folder.children==allocated,"Merge failed to reuse its pool")
assert(changed[1] and changed[11],"Effect modified capture cell set")
merge:Destroy()
print("[Paintland V32 TEST PASS] Timed double/triple kills, cut-position bursts, camera projection, overlay height, pooling, reduced motion")
