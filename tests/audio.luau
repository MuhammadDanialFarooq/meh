local Cues=loadModule("AudioCues")
local cfg=table.clone(loadModule("Config"))
local fifthId,fifthPitch=Cues.Kill(cfg,5)
local previous=0
for streak=1,20 do
    local id,pitch,tier=Cues.Kill(cfg,streak)
    assert(tier==math.min(streak,5),"Wrong kill tier")
    if streak<=5 then assert(pitch>previous,"Kill pitches must ascend"); previous=pitch end
    if streak>=5 then assert(id==fifthId and pitch==fifthPitch,"Fifth cue must repeat unchanged") end
end
cfg.KillSoundIds={101,"rbxassetid://102",103,104,105}
for streak=1,8 do
    local id,pitch=Cues.Kill(cfg,streak)
    assert(id=="rbxassetid://" .. (100+math.min(streak,5)) and pitch==1,"Custom kill asset/pitch failed")
end
for _,case in ipairs({{0.001,0},{4.999,0},{5,1},{9.999,1},{10,2},{20,4},{25,5},{100,20}}) do
    local _,pitch,tier=Cues.Capture(cfg,case[1]*100,10000)
    assert(tier==case[2],"Wrong percentage tier at " .. case[1])
    assert(pitch>=0.5 and pitch<=3,"Capture pitch exceeded limits")
end
assert(Cues.Capture(cfg,0,10000)==nil and Cues.Capture(cfg,5,0)==nil,"Empty capture played audio")
cfg.CaptureSoundMetric="Tiles"
local _,_,tileTier=Cues.Capture(cfg,25,10000)
assert(tileTier==5,"Raw tile gain mode failed")

-- Controller runs against bounded Sound doubles, without emulating audio output.
local Audio=loadModule("AudioController")
cfg.SoundMutedByDefault=true
cfg.SoundMutedByDefault=true -- explicit muted policy test
local defaultAudio=Audio.new(cfg)
assert(defaultAudio.muted,"Configured muted default was ignored")
defaultAudio:Destroy()
cfg.SoundMutedByDefault=false
local a=Audio.new(cfg)
assert(#a.pools.Kill==5 and #a.pools.Capture==3,"Sound pools not bounded")
for i=1,100 do a:Kill(i); a:Capture(i,10000) end
assert(#a.pools.Kill==5 and #a.pools.Capture==3,"Sound instances grew on repeated events")
a:Reset()
for _,pool in pairs(a.pools) do for _,sound in ipairs(pool) do assert(not sound.Playing,"Reset left a voice playing") end end
a:Kill(1)
assert(a.pools.Kill[1].PlaybackSpeed==1,"Custom first-kill cue failed after reset")
a:SetMuted(true); a:Kill(5)
for _,sound in ipairs(a.pools.Kill) do assert(not sound.Playing,"Muted kill was played") end
a:SetMuted(false); a:Kill(5)
assert(a.pools.Kill[1].Playing,"Unmute did not restore audio")
a:Death()
assert(a.pools.Death[1].Playing and not a.pools.Kill[1].Playing,"Death did not clear old cues")
a:Spawn(); a:Victory()
assert(a.pools.Spawn[1].Playing and a.pools.Victory[1].Playing,"Spawn/victory cues missing")
-- Actual repeat cadence, interpolation and lifecycle behavior.
for _,case in ipairs({{.001,5},{.5,5},{.75,9},{1,13},{1.25,16},{1.5,20},{12,20}}) do
    assert(Cues.CaptureRepeats(case[1]*100,10000)==case[2],"Wrong repeat count for "..case[1])
end
assert(Cues.CaptureRepeats(0,100)==0 and Cues.CaptureRepeats(1,0)==0,"Invalid gain created notes")
cfg.CaptureSoundId=106879573498735
local played={}
local originalPlay=a.Play
a.Play=function(self,channel,id,pitch,volume)
    if channel=="Capture" then table.insert(played,{id=id,pitch=pitch}) end
    return originalPlay(self,channel,id,pitch,volume)
end
for _,case in ipairs({{.5,5},{1,13},{1.5,20}}) do
    a:Reset();table.clear(played)
    a:Capture(case[1]*100,10000)
    for _=1,30 do a:Update(.045) end
    assert(#played==case[2] and not a.captureSequence,"Sequence played wrong number of notes")
    assert(played[1].id=="rbxassetid://106879573498735","Capture ID not normalized")
    assert(played[1].pitch==1 and math.abs(played[#played].pitch-1.6)<1e-9,"Pitch endpoints wrong")
    for i=2,#played do assert(played[i].pitch>played[i-1].pitch,"Capture pitch did not rise") end
end
-- A second capture replaces remaining notes, with no queued backlog.
a:Reset();table.clear(played);a:Capture(200,10000);a:Capture(50,10000)
for _=1,30 do a:Update(.045) end
assert(#played==6,"Overlapping captures accumulated reward queues")
a:Reset();table.clear(played);a:Capture(150,10000);a:Update(10)
assert(#played==2,"Dropped frame caused simultaneous catch-up notes")
a:SetMuted(true);a:Update(10);assert(not a.captureSequence and #played==2,"Mute retained queue")
a:SetMuted(false);a:Capture(150,10000);a:Death();assert(not a.captureSequence,"Death retained queue")
a:Capture(150,10000);a:Reset();assert(not a.captureSequence,"Reset retained queue")
a:Capture(150,10000);cfg.SoundEnabled=false;a:Update(.1)
assert(not a.captureSequence,"Sound disable retained queue")
cfg.SoundEnabled=false
a:Reset();a:Kill(1)
assert(not a.pools.Kill[1].Playing,"Disabled audio played")
a:Destroy(); a:Destroy(); a:Kill(1)
assert(a.folder.Destroyed,"Audio folder not destroyed")
print("[Paintland V41 TEST PASS] Kill tiers, gain-to-5..20 repeat mapping, pitched capture sequence, bounded voices, overlap/stall and mute/reset/death/destroy cleanup")
