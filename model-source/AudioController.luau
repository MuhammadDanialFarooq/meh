-- Local, bounded, non-spatial arcade feedback. No downloaded assets are required
-- for the default bundled Roblox ping. Replace cue IDs with permitted audio.
local SoundService = game:GetService("SoundService")
local Cues = require(script.Parent.AudioCues)
local Audio = {}
Audio.__index = Audio

function Audio.new(cfg)
    local self = setmetatable({cfg=cfg, muted=cfg.SoundMutedByDefault==true, destroyed=false, pools={}, cursors={}}, Audio)
    self.folder = Instance.new("Folder")
    self.folder.Name = "PaintlandAudio"
    self.folder.Parent = SoundService
    self.group = Instance.new("SoundGroup")
    self.group.Name = "PaintlandEffects"
    self.group.Volume = math.clamp(cfg.SoundMasterVolume or 0.65, 0, 1)
    self.group.Parent = SoundService
    for _, channel in ipairs({"Kill", "Capture", "Spawn", "Death", "Victory"}) do
        local pool = {}
        self.pools[channel] = pool
        for i=1, (channel == "Kill" and 5 or channel == "Capture" and 3 or 1) do
            local sound = Instance.new("Sound")
            sound.Name = channel .. i
            sound.SoundGroup = self.group
            sound.Looped = false
            sound.Parent = self.folder
            pool[i] = sound
        end
        self.cursors[channel] = 0
    end
    return self
end

function Audio:Play(channel, id, pitch, volume)
    if self.destroyed or self.muted or self.cfg.SoundEnabled == false or not id or id == "" then return end
    local pool = self.pools[channel]
    if not pool then return end
    local cursor = self.cursors[channel] % #pool + 1
    self.cursors[channel] = cursor
    local sound = pool[cursor]
    -- A channel reuses its oldest voice rather than allocating on every event.
    sound:Stop()
    sound.SoundId = tostring(id):match("^%d+$") and ("rbxassetid://" .. id) or id
    sound.PlaybackSpeed = math.clamp(pitch or 1, 0.5, 3)
    sound.Volume = math.clamp(volume or 0.5, 0, 1)
    sound.TimePosition = 0
    sound:Play()
end

function Audio:Kill(streak)
    local id, pitch = Cues.Kill(self.cfg, streak)
    self:Play("Kill", id, pitch, self.cfg.KillSoundVolume or 0.75)
end

function Audio:Capture(count, playableTotal)
    if self.destroyed or self.muted or self.cfg.SoundEnabled==false then return end
    local repeats=Cues.CaptureRepeats(count,playableTotal)
    local id=Cues.Capture(self.cfg,count,playableTotal)
    if repeats==0 or not id or id=="" then return end
    -- Replace the unfinished reward instead of accumulating asynchronous jobs.
    for _,sound in ipairs(self.pools.Capture) do sound:Stop() end
    self.captureSequence={id=id,total=repeats,played=0,wait=0,
        interval=math.clamp(self.cfg.CaptureRepeatInterval or .045,.03,.15),
        startPitch=math.clamp(self.cfg.CaptureSequenceStartPitch or 1,.5,3),
        endPitch=math.clamp(self.cfg.CaptureSequenceEndPitch or 1.6,.5,3)}
    self:Update(0)
end

function Audio:Update(dt)
    if self.destroyed or not self.captureSequence then return end
    if self.muted or self.cfg.SoundEnabled==false then
        self.captureSequence=nil
        for _,sound in ipairs(self.pools.Capture) do sound:Stop() end
        return
    end
    if type(dt)~="number" or dt~=dt or dt<0 then return end
    local sequence=self.captureSequence
    sequence.wait-=dt
    if sequence.wait>0 then return end
    -- At most one note per rendered frame. A stall stretches the sequence;
    -- it never fires a pile of overdue sounds in one frame.
    local t=sequence.played/math.max(1,sequence.total-1)
    self:Play("Capture",sequence.id,sequence.startPitch+(sequence.endPitch-sequence.startPitch)*t,
        self.cfg.CaptureSoundVolume or .35)
    sequence.played+=1
    sequence.wait=sequence.interval
    if sequence.played>=sequence.total then self.captureSequence=nil end
end

function Audio:Spawn()
    self:Play("Spawn", self.cfg.SpawnSoundId or self.cfg.SoundBaseId, 1.1, 0.3)
end

function Audio:Death()
    self:Reset()
    self:Play("Death", self.cfg.DeathSoundId or self.cfg.SoundBaseId, 0.55, 0.45)
end

function Audio:Victory()
    self:Play("Victory", self.cfg.VictorySoundId or self.cfg.SoundBaseId, 1.8, 0.6)
end

function Audio:Reset()
    if self.destroyed then return end
    self.captureSequence=nil
    for channel, pool in pairs(self.pools) do
        for _, sound in ipairs(pool) do sound:Stop() end
        self.cursors[channel] = 0
    end
end

function Audio:SetMuted(muted)
    self.muted = muted == true
    if self.muted then self:Reset() end
end

function Audio:Destroy()
    if self.destroyed then return end
    self:Reset()
    self.destroyed = true
    self.folder:Destroy()
    self.group:Destroy()
end

return Audio
