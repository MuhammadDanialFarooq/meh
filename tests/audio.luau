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
local defaultAudio=Audio.new(cfg)
assert(defaultAudio.muted,"Default placeholder sounds should start muted")
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
cfg.SoundEnabled=false
a:Reset();a:Kill(1)
assert(not a.pools.Kill[1].Playing,"Disabled audio played")
a:Destroy(); a:Destroy(); a:Kill(1)
assert(a.folder.Destroyed,"Audio folder not destroyed")
print("[Paintland V28 TEST PASS] Kill tiers 1..20, custom IDs, 5-point capture thresholds, tiles mode, bounded pools, mute/reset/death/destroy")
