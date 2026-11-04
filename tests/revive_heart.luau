-- Real heart rendering math and multiplayer request guards, using UI/Sound doubles.
local heartEnv=setmetatable({Instance={new=function(class)
    local instance=uiInstance.new(class)
    if class=="Sound" then
        function instance:Play() self.Playing=true;self.PlayCount=(self.PlayCount or 0)+1 end
        function instance:Stop() self.Playing=false end
    end
    return instance
end}}, {__index=getfenv(factories.UIController)})
setfenv(factories.ReviveHeart,heartEnv);cache.ReviveHeart=nil
local Heart=loadModule("ReviveHeart")
local heartCfg=table.clone(loadModule("Config"));heartCfg.SoundEnabled=true;heartCfg.ReviveCountdownSoundId=12345
local muted=false
local heart=Heart.new(screen,heartCfg,function() return muted end)
local bodySize=heart.body.Size
assert(heart.sound.SoundId=="rbxassetid://12345","Custom countdown sound was not normalized")
heart:Reset(4)
for second=4,1,-1 do
    heart:Update(.1,second,4,false)
    heart:Update(.1,second-.1,4,false)
end
assert(heart.beepCount==4,"Countdown should beep once per displayed positive second")
assert(heart.body.Size==bodySize,"Countdown pulse changed the main heart size")
heart:Update(.1,0,4,false)
for _,part in ipairs(heart.fillParts) do assert(not part.Visible,"Zero heart retained fill pixels") end
heart:Reset(4);heart:Update(.1,2,4,false)
assert(heart.fraction==.5,"Half countdown did not produce half-height fill")
for _,part in ipairs(heart.fillParts) do
    if part.Visible then assert(part.Position.Y.Scale>=.5,"Drained fill extends above its waterline") end
end
local notes=heart.beepCount
heart:Update(1,2,4,true)
assert(heart.beepCount==notes and not heart.sound.Playing and not heart.pulse.Visible,"Waiting state still beeped or pulsed")
heart:Update(.1,2,4,false)
assert(heart.beepCount==notes,"Resuming same second duplicated a beep")
muted=true;heart:Update(.1,1,4,false);assert(heart.beepCount==notes,"Muted heart beeped")
heartCfg.ReducedMotion=true;heart:Reset(4);heart:Update(0,4,4,false)
assert(not heart.pulse.Visible,"Reduced motion still pulses")
heart:Destroy();assert(heart.root.Destroyed and not heart.sound.Playing,"Heart cleanup failed")

services.MarketplaceService=services.MarketplaceService or {}
services.MarketplaceService.PromptProductPurchaseFinished=signal()
setfenv(factories.ReviveController,heartEnv);cache.ReviveController=nil
local ReviveUI=loadModule("ReviveController")
local localRevives,localEnds,serverRevives,serverDeclines=0,0,0,0
local revive=ReviveUI.new(screen,heartCfg,{isMuted=function() return false end,
    onRevive=function() localRevives+=1 end,onTimeout=function() localEnds+=1 end})
revive:OpenServer(4,1,function() serverRevives+=1 end,function() serverDeclines+=1 end)
for _,size in ipairs({{320,568},{390,844},{568,320},{640,360},{1280,720}}) do
    revive:Resize(Vector2.new(size[1],size[2]))
    assert(revive.adButton.Size.Y.Offset>=44 and revive.endButton.Size.Y.Offset>=44,"Server revive touch target too small")
    assert(revive.adButton.Position.Y.Offset+22<=revive.endButton.Position.Y.Offset-22,"Revive actions overlap")
    assert(revive.actions.Position.Y.Offset>=0,"Revive action panel starts outside card")
    assert(revive.actions.Position.Y.Offset+revive.actions.Size.Y.Offset<=revive.card.Size.Y.Offset,"Revive actions leave card")
end
assert(revive.adButton.Visible and not revive.buyButton.Visible and not revive.creditButton.Visible,
    "Multiplayer revive exposed purchase UI")
revive.adButton.Activated:Fire();revive.adButton.Activated:Fire()
assert(serverRevives==1 and localRevives==0,"Client granted or duplicated a server revive")
revive:Update(2);assert(revive.state=="waiting","Waiting for acknowledgement resumed local countdown")
revive:Close();revive:CompleteRevive();assert(localRevives==0,"Late acknowledgement revived closed UI")
revive:OpenServer(1,1,function() serverRevives+=1 end,function() serverDeclines+=1 end)
revive:Update(2);revive:Update(2)
assert(serverDeclines==1 and localEnds==0 and revive.state=="waiting","Server deadline was not dispatched exactly once")
revive:OpenServer(4,0,function() serverRevives+=1 end,function() serverDeclines+=1 end)
revive.adButton.Activated:Fire();assert(serverRevives==1,"Exhausted revive sent an invalid request")
revive.endButton.Activated:Fire();assert(serverDeclines==2,"No thanks did not request server result")
revive:Destroy();revive:Destroy()
assert(revive.root.Destroyed,"Revive teardown failed")
print("[Paintland V41 TEST PASS] Heart fill/outline/beeps, pending/mute/reduced motion, server revive guards and native touch layout")
