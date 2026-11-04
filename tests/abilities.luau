do
local service=loadModule("AbilityService").new(netCfg)
local captured=0
local world=MW.new(netCfg,function() end,{onCapture=function(e,n) captured+=n;service:Capture(e,n,1000) end},2)
world:AddPlayer(1,31,"Painter",1);world:AddPlayer(2,32,"Rival",2)
local actor=world.entities[1]
assert(not service:Use(world,actor,"Dash",true),"Un-equipped ability accepted")
service:Equip(actor,"Splash")
assert(not service:Use(world,actor,"Splash",true),"Empty charge activated")
world.time+=100;assert(not service:State(world,actor).ready,"Waiting passively recharged ability")
service:Capture(actor,10,1000);assert(actor.abilityCharge==20,"Capture charge rate incorrect")
service:Kill(actor);assert(actor.abilityCharge==55,"Kill charge rate incorrect")
service:Grant(actor,1000);assert(actor.abilityCharge==100,"Charge exceeded cap")
assert(not service:Use(world,actor,"Dash",true),"Second ability bypassed one-slot restriction")
assert(not service:Use(world,actor,"Splash",false),"Ability worked in lobby")
local before=world.grid.counts[1]
assert(service:Use(world,actor,"Splash",true))
assert(captured>0 and world.grid.counts[1]==before+captured,"Splash gain differs from owned cells")
assert(actor.abilityCharge==0,"Splash recharged itself through its own capture")
service:Grant(actor,100)
assert(not service:Use(world,actor,"Splash",true) and actor.abilityCharge==100,"No-op Splash consumed charge")
actor.drawing=true;assert(not service:Use(world,actor,"Splash",true),"Splash rescued exposed trail");actor.drawing=false
service:Equip(actor,"Dash");service:Grant(actor,100)
actor.pos=Vector2.zero;actor.heading=0;actor.targetHeading=0
assert(service:Use(world,actor,"Dash",true))
local Movement=loadModule("Movement")
Movement.Step(actor,.4,netCfg,world.grid.half);Movement.Step(actor,.4,netCfg,world.grid.half)
local distance=netCfg.PlayerSpeed*(netCfg.DashDurationSeconds*netCfg.DashSpeedMultiplier+.8-netCfg.DashDurationSeconds)
assert(math.abs(actor.pos.X-distance)<1e-5 and actor.dashRemaining==0,"Dash expiry changed with frame rate")
service:Grant(actor,100);world:Eliminate(actor,world.entities[2],"trail")
assert(actor.abilityCharge==0 and not service:Use(world,actor,"Dash",true),"Death retained charge/activation")
assert(world:RevivePlayer(1) and actor.dashRemaining==0 and actor.abilityCharge==0,"Revive retained boost or charge")
world:RemovePlayer(1);world:AddPlayer(1,33,"New player",3)
assert(actor.equippedAbility=="" and actor.abilityCharge==0,"Replacement inherited loadout")
world.completed=true;assert(not service:Use(world,actor,"Dash",true),"Ability changed finished game")
local swept=MW.new(netCfg,function() end,{},2)
swept:AddPlayer(1,41,"Dasher",1);swept:AddPlayer(2,42,"Rival",2)
local dasher,rival=swept.entities[1],swept.entities[2]
dasher.pos=Vector2.new(-10,0);dasher.heading=0;dasher.targetHeading=0
swept.trails:Begin(rival,Vector2.new(0,-10));swept.trails:Register(rival,swept.grid:At(Vector2.zero),Vector2.zero,0)
service:Equip(dasher,"Dash");service:Grant(dasher,100);assert(service:Use(swept,dasher,"Dash",true))
swept:Step(.3,function() return 0 end);assert(not rival.alive,"Dash skipped exposed trail")

local requests=0
local hud=loadModule("AbilityHUD").new(screen,netCfg,function(id) assert(id=="Dash");requests+=1 end)
hud:SetState({equipped="Dash",charge=100,required=100,ready=true})
hud:Request();assert(requests==0,"Hidden HUD activated")
hud:SetActive(true)
services.UserInputService.InputBegan:Fire({KeyCode="Space"},true);assert(requests==0,"Processed space activated")
services.UserInputService.InputBegan:Fire({KeyCode="Space"},false);hud:Request()
assert(requests==1,"Space failed or pending request flooded")
hud:SetState({id="Dash",equipped="Dash",charge=0,required=100,ready=false});hud:Update(100)
assert(not hud.state.ready,"HUD timer fabricated charge")
local keyConnection=hud.input.connections[1];hud:Destroy();assert(not keyConnection.Connected,"Input connection leaked")
local now,activations=10,0
local input=loadModule("AbilityInput").new(netCfg,function() activations+=1 end,services.UserInputService,function() return now end)
input:SetActive(true)
local function finger(x,y) return {UserInputType="Touch",Position={X=x,Y=y}} end
local function tap(x,y)
    local f=finger(x,y);input:Begin(f,false);now+=.06;input:End(f,false);now+=.04
end
tap(100,100);assert(activations==0);tap(110,100);assert(activations==1,"Double tap failed")
tap(100,100);now+=.4;tap(100,100);assert(activations==1,"Slow taps activated")
input:Reset();local f=finger(100,100);input:Begin(f,false);f.Position.X=180;input:Move(f);f.Position.X=100;input:End(f,false)
tap(100,100);assert(activations==1,"Returning drag counted as tap")
input:Reset();tap(100,100);input:Begin(finger(100,100),true);tap(100,100);assert(activations==1,"UI touch completed double tap")
input:Reset();f=finger(100,100);input:Begin(f,false);input:Begin(finger(110,110),false);input:End(f,false);tap(100,100)
assert(activations==1,"Multitouch steering counted as double tap")
services.UserInputService.GetFocusedTextBox=function() return {} end
input:Begin({KeyCode="Space"},false);assert(activations==1,"Chat input activated ability")
services.UserInputService.GetFocusedTextBox=function() return nil end
input:Destroy()
print("[Paintland V43 TEST PASS] Single equipped slot, capture/kill charge only, no self recharge, death reset, swept Dash, Space/double-tap/UI/drag guards")
end
