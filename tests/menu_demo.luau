local Demo=loadModule("MenuDemo")
local World=loadModule("World")
local cfg=table.clone(loadModule("Config"))
local renderer={swaps=0,dirty=0,
    SetWorld=function(self,w) self.world=w;self.swaps+=1 end,
    MarkCell=function(self) self.dirty+=1 end,
    ResetEntityVisual=function() end,ClearTrail=function() end,RemoveEntityVisual=function() end}
local resets,captures=0,0
local demo
local capturedWorld
local events={onReset=function() resets+=1 end,
    onCapture=function(_,count,_,w) if count>0 then captures+=1 end;capturedWorld=w end}
demo=Demo.new(cfg,renderer,events)
local first=demo:Start()
assert(demo.active and renderer.world==first and #first.entities==cfg.MenuDemoBots,"Menu did not create a demo world")
for _,e in ipairs(first.entities) do assert(not e.isHuman,"Menu world spawned a human") end
assert(demo.target and demo.target.alive,"Camera has no live demo target")
local original=first.entities[1].pos
for _=1,600 do demo:Update(1/60) end
assert(first.time>9 and (first.entities[1].pos-original).Magnitude>0,"Demo bots did not move")
assert(captures>0 and capturedWorld==first and renderer.dirty>0,"Demo did not capture/render land")
local e=first.entities[1]
local revision=e.spawnRevision
if e.alive then first:Eliminate(e,nil,"test") end
assert(e.respawnAt<math.huge,"Demo entity 1 entered a human revive flow")
for _=1,240 do demo:Update(1/60) end
assert(e.spawnRevision>revision,"Demo bot 1 never respawned")
local oldTarget=demo.target
oldTarget.alive=false;demo:Update(.01)
assert(demo.target and demo.target.alive,"Camera did not replace a dead target")
-- Reset at round completion keeps the menu alive without a victory overlay.
first.completed=true;demo:Update(.01)
assert(demo.world~=first and renderer.world==demo.world and resets==2,"Completed demo did not restart")
local second=demo.world
cfg.MenuDemoRoundSeconds=.1;demo:Update(.2)
assert(demo.world~=second and resets==3,"Timed demo rotation failed")
-- Stopping on Play must leave the next real world completely independent.
local stoppedWorld=demo.world
local stoppedTime=stoppedWorld.time
demo:Stop()
local real=World.new(cfg)
real:Start("Player",1)
renderer:SetWorld(real)
demo:Update(60)
assert(not demo.active and demo.world==nil and stoppedWorld.time==stoppedTime,"Demo kept simulating after Play")
assert(renderer.world==real and real.entities[1].isHuman and real.grid~=stoppedWorld.grid,"Demo leaked into real game")
print("[Paintland V35 TEST PASS] Bot-only menu captures/movement/respawns, camera retarget, round resets, clean Play handoff")
