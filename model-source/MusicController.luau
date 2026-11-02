-- One continuous playlist, independent of the effects mute/pools. Menu muffling
-- is EQ + volume only; switching modes never restarts or pitch-shifts the song.
local SoundService=game:GetService("SoundService")
local TweenService=game:GetService("TweenService")
local Music={}
Music.__index=Music
local function asset(value)
    if type(value)=="number" and value>0 then return "rbxassetid://"..math.floor(value) end
    if type(value)=="string" then
        if value:match("^%d+$") and tonumber(value)>0 then return "rbxassetid://"..value end
        if value:match("^rbxassetid://%d+$") then return value end
    end
    return nil
end
function Music.new(cfg)
    local self=setmetatable({cfg=cfg,tracks={},trackVolumes={},failed={},index=1,mode="menu",waitAge=0,
        muted=cfg.MusicMutedByDefault==true,destroyed=false},Music)
    for n,value in ipairs(cfg.MusicTrackIds or {}) do
        local id=asset(value)
        if id then
            self.tracks[#self.tracks+1]=id
            self.trackVolumes[#self.tracks]=math.clamp((cfg.MusicTrackVolumes or {})[n] or 1,0,1)
        end
    end
    self.group=Instance.new("SoundGroup")
    self.group.Name="PaintlandMusic";self.group.Volume=0;self.group.Parent=SoundService
    self.equalizer=Instance.new("EqualizerSoundEffect")
    self.equalizer.Name="MenuMuffle";self.equalizer.LowGain=0
    self.equalizer.Parent=self.group
    self.sound=Instance.new("Sound")
    self.sound.Name="PaintlandPlaylist";self.sound.Volume=1;self.sound.PlaybackSpeed=1
    self.sound.SoundGroup=self.group;self.sound.Looped=#self.tracks==1;self.sound.Parent=SoundService
    self.ended=self.sound.Ended:Connect(function()
        if not self.destroyed and #self.tracks>0 then
            self:NextTrack()
        end
    end)
    self:ApplyMix()
    self:PlayTrack()
    return self
end
function Music:PlayTrack()
    if self.destroyed or self.cfg.MusicEnabled==false or self.stalled or #self.tracks==0 then return end
    self.waitAge=0
    self.sound.SoundId=self.tracks[self.index]
    self.sound.Volume=self.trackVolumes[self.index]
    self.sound.TimePosition=0
    self.sound:Play()
end
function Music:NextTrack()
    if self.destroyed or #self.tracks==0 then return end
    for _=1,#self.tracks do
        self.index=self.index%#self.tracks+1
        if not self.failed[self.index] then self:PlayTrack();return end
    end
    self.stalled=true
    self.sound:Stop()
    self:ApplyMix()
end
function Music:Update(dt)
    if self.destroyed or self.stalled or self.cfg.MusicEnabled==false or #self.tracks==0 then return end
    if self.sound.IsLoaded then self.waitAge=0;return end
    self.waitAge+=math.max(0,dt)
    if self.waitAge>=(self.cfg.MusicLoadTimeoutSeconds or 12) then
        self.failed[self.index]=true
        warn("[Paintland] Music track could not load; skipping. Check experience audio permissions in Studio.")
        self:NextTrack()
    end
end
function Music:ApplyMix()
    if self.destroyed then return end
    if self.volumeTween then self.volumeTween:Cancel() end
    if self.eqTween then self.eqTween:Cancel() end
    local menu=self.mode~="playing"
    local enabled=self.cfg.MusicEnabled~=false and not self.muted and not self.stalled and #self.tracks>0
    local volume=menu and (self.cfg.MusicMenuVolume or .09) or (self.cfg.MusicPlayVolume or .32)
    local duration=math.max(0,self.cfg.MusicFadeSeconds or .65)
    local info=TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
    self.volumeTween=TweenService:Create(self.group,info,{Volume=enabled and math.clamp(volume,0,1) or 0})
    self.eqTween=TweenService:Create(self.equalizer,info,{
        HighGain=menu and math.clamp(self.cfg.MusicMenuHighGain or -25,-80,10) or 0,
        MidGain=menu and math.clamp(self.cfg.MusicMenuMidGain or -10,-80,10) or 0})
    self.volumeTween:Play();self.eqTween:Play()
end
function Music:SetMode(mode)
    if self.mode==mode then return end
    self.mode=mode;self:ApplyMix()
end
function Music:SetMuted(muted)
    self.muted=muted==true;self:ApplyMix()
end
function Music:Destroy()
    if self.destroyed then return end
    self.destroyed=true
    if self.ended then self.ended:Disconnect() end
    if self.volumeTween then self.volumeTween:Cancel() end
    if self.eqTween then self.eqTween:Cancel() end
    self.sound:Stop();self.sound:Destroy();self.group:Destroy()
end
return Music
