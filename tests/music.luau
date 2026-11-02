local MusicInstance={new=function(class)
    local sound=signal()
    return {ClassName=class,Ended=sound,IsLoaded=true,Playing=false,PlayCount=0,
        Play=function(self) self.Playing=true;self.PlayCount+=1 end,
        Stop=function(self) self.Playing=false end,
        Destroy=function(self) self.Destroyed=true end}
end}
Instance=MusicInstance
setfenv(factories.MusicController,setmetatable({Instance=MusicInstance,Enum=enums,
    TweenInfo={new=function() return {} end}},{__index=getfenv(factories.MusicController)}))
local Music=loadModule("MusicController")
local cfg=table.clone(loadModule("Config"))
local m=Music.new(cfg)
assert(#m.tracks==8 and m.sound.SoundId=="rbxassetid://1846088038","Uploaded songs not configured")
assert(m.tracks[7]=="rbxassetid://138649427280723" and m.tracks[8]=="rbxassetid://139980780754211","Songs not ordered by name")
assert(m.sound.Playing and m.group.Volume==cfg.MusicMenuVolume,"Menu music not playing quietly")
assert(m.equalizer.HighGain<0 and m.equalizer.MidGain<0,"Menu music not muffled")
m.sound.TimePosition=42
local plays=m.sound.PlayCount
m:SetMode("playing")
assert(m.group.Volume==cfg.MusicPlayVolume and m.equalizer.HighGain==0 and m.equalizer.MidGain==0,"Gameplay mix not restored")
assert(m.sound.TimePosition==42 and m.sound.PlayCount==plays,"Mode transition restarted music")
m:SetMode("defeat")
assert(m.group.Volume==cfg.MusicMenuVolume and m.sound.TimePosition==42,"Defeat restarted music or failed to duck")
m:SetMuted(true)
assert(m.group.Volume==0 and m.sound.Playing,"Mute must silence without rewinding")
m:SetMode("playing");assert(m.group.Volume==0,"Mode transition ignored mute")
m:SetMuted(false);assert(m.group.Volume==cfg.MusicPlayVolume,"Unmute lost gameplay mix")
for _=1,4 do m.sound.Ended:Fire() end
assert(m.index==5 and m.sound.Volume==.4,"Relative uploaded song volume lost")
for _=1,4 do m.sound.Ended:Fire() end
assert(m.index==1 and m.sound.PlaybackSpeed==1,"Playlist did not wrap or changed song pitch")
m.sound.IsLoaded=false;m:Update(13)
assert(m.index==2 and m.failed[1],"Unplayable song not skipped")
m.sound.IsLoaded=true
m:Destroy();m:Destroy();m:SetMode("menu")
assert(m.sound.Destroyed and m.group.Destroyed,"Music teardown leaked instances")
local emptyCfg=table.clone(cfg);emptyCfg.MusicTrackIds={}
local empty=Music.new(emptyCfg)
assert(not empty.sound.Playing and empty.group.Volume==0,"Empty playlist played a placeholder")
empty:Destroy()
local singleCfg=table.clone(cfg);singleCfg.MusicTrackIds={"rbxassetid://123"}
local one=Music.new(singleCfg)
assert(one.sound.Looped,"Single song did not loop")
one.sound.IsLoaded=false;one:Update(13)
assert(one.stalled and not one.sound.Playing and one.group.Volume==0,"All-failed playlist did not stop safely")
one:Destroy()
print("[Paintland V38 TEST PASS] 8 imported songs, relative levels, playlist wrap, menu EQ, uninterrupted mode/mute transitions, failed-track skip and teardown")
