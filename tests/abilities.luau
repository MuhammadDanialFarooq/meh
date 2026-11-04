do
local AbilityService=loadModule("AbilityService")
local cfg=table.clone(netCfg)
local service=AbilityService.new(cfg)
local captured=0
local world=MW.new(cfg,function() end,{onCapture=function(_,count) captured+=count end},3)
world:AddPlayer(1,31,"Painter",1);world:AddPlayer(2,32,"Rival",2)
local actor=world.entities[1]
assert(not service:Use(world,actor,"Dash",false),"Ability worked in a lobby")
assert(not service:Use(world,actor,"Unregistered",true),"Unknown ability accepted")
local before=world.grid.counts[1]
assert(service:Use(world,actor,"Splash",true),"Splash failed from owned spawn land")
assert(captured>0 and world.grid.counts[1]==before+captured,"Splash reward differs from actual captured cells")
assert(not service:Use(world,actor,"Splash",true),"Splash cooldown was bypassed")
world.time+=cfg.SplashCooldownSeconds
assert(not service:Use(world,actor,"Splash",true),"Splash rewarded a circle already owned")
assert(service:State(world,actor).Splash==0,"Failed Splash consumed cooldown")
actor.drawing=true;assert(not service:Use(world,actor,"Splash",true),"Splash rescued exposed trail")
actor.drawing=false
actor.pos=Vector2.zero;actor.heading=0;actor.targetHeading=0
assert(service:Use(world,actor,"Dash",true),"Dash failed")
local Movement=loadModule("Movement")
Movement.Step(actor,.4,cfg,world.grid.half)
assert(math.abs(actor.pos.X-cfg.PlayerSpeed*.4*cfg.DashSpeedMultiplier)<1e-5,"Dash speed incorrect")
Movement.Step(actor,.4,cfg,world.grid.half)
local distance=cfg.PlayerSpeed*(cfg.DashDurationSeconds*cfg.DashSpeedMultiplier+.8-cfg.DashDurationSeconds)
assert(math.abs(actor.pos.X-distance)<1e-5 and actor.dashRemaining==0,"Dash expiry is frame-dependent or permanent")
assert(not service:Use(world,actor,"Dash",true),"Dash retriggered in cooldown")
world:Eliminate(actor,world.entities[2],"trail")
assert(not service:Use(world,actor,"Splash",true),"Dead player used ability")
local cooldown=service:State(world,actor).Dash
assert(world:RevivePlayer(1) and actor.dashRemaining==0,"Revive retained Dash boost")
assert(service:State(world,actor).Dash==cooldown,"Revive reset ability cooldown")
world:RemovePlayer(1);world:AddPlayer(1,33,"New player",3)
assert(service:State(world,actor).Dash==0,"Replacement player inherited cooldown")
world.completed=true;assert(not service:Use(world,actor,"Dash",true),"Ability changed completed match")

local swept=MW.new(cfg,function() end,{},2)
swept:AddPlayer(1,41,"Dasher",1);swept:AddPlayer(2,42,"Trail owner",2)
local dasher,rival=swept.entities[1],swept.entities[2]
dasher.pos=Vector2.new(-10,0);dasher.heading=0;dasher.targetHeading=0
swept.trails:Begin(rival,Vector2.new(0,-10))
swept.trails:Register(rival,swept.grid:At(Vector2.zero),Vector2.zero,0)
assert(service:Use(swept,dasher,"Dash",true))
swept:Step(.3,function() return 0 end)
assert(not rival.alive and dasher.kills==1,"Dash skipped an exposed trail during movement sweep")

local requested={}
local hud=loadModule("AbilityHUD").new(screen,cfg,function(id) requested[#requested+1]=id end)
hud:Request("Dash");assert(#requested==0,"Hidden HUD activated ability")
hud:SetActive(true)
hud.buttons.Dash.button.Activated:Fire();hud.buttons.Dash.button.Activated:Fire()
assert(#requested==1 and requested[1]=="Dash","Touch/button request flooded before server reply")
hud:SetState({id="Dash",cooldowns={Dash=8,Splash=0}});hud:Update(1)
assert(hud.buttons.Dash.status.Text=="7s","Cooldown display did not advance")
services.UserInputService.InputBegan:Fire({KeyCode="Q"},true)
assert(#requested==1,"Typing/processed key activated Splash")
services.UserInputService.InputBegan:Fire({KeyCode="Q"},false)
assert(#requested==2 and requested[2]=="Splash","Keyboard activation missing")
services.UserInputService.GetFocusedTextBox=function() return {} end
hud:Update(2);services.UserInputService.InputBegan:Fire({KeyCode="Q"},false)
assert(#requested==2,"Focused chat/textbox activated ability")
services.UserInputService.GetFocusedTextBox=function() return nil end
local keyConnection=hud.input;hud:Destroy();assert(not keyConnection.Connected,"Ability input leaked after teardown")

local wallet=loadModule("WalletHUD").new(screen,cfg)
wallet:Set({loaded=false,coins=100,gems=2});assert(wallet.values[1].Text=="…","Unloaded wallet displayed an assumed balance")
wallet:Set({loaded=true,coins=12345,gems=2,deltaCoins=25,persistent=true})
assert(wallet.values[1].Text=="12.3K" and wallet.captions[1].Text=="+25 COINS","Wallet formatting/reward feedback incorrect")
wallet:Update(3);assert(wallet.captions[1].Text=="COINS","Reward feedback did not clear")
wallet:Set({loaded=true,coins=12345,gems=2,saving=true})
assert(wallet.captions[1].Text=="SAVE PENDING","Save failure hidden from player")
wallet:Destroy()
print("[Paintland V42 TEST PASS] Splash claims/cooldown, Dash distance/expiry, death/revive/slot reset; ability controls, cooldown UI and wallet states")
end
