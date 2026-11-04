-- Pure cue selection, shared by the controller and deterministic tests.
local Cues = {}

function Cues.Kill(cfg, streak)
    local tier = math.clamp(math.floor(streak or 1), 1, 5)
    local ids = cfg.KillSoundIds or {}
    local custom = ids[tier]
    if custom and custom ~= "" and custom ~= 0 then
        return tostring(custom):match("^%d+$") and ("rbxassetid://" .. custom) or custom, 1, tier
    end
    local pitches = cfg.KillSoundPitches or {0.9, 1.01, 1.13, 1.35, 1.51}
    return cfg.SoundBaseId or "rbxasset://sounds/electronicpingshort.wav", pitches[tier], tier
end

function Cues.Capture(cfg, count, playableTotal)
    if not count or count <= 0 or not playableTotal or playableTotal <= 0 then return nil end
    local gain = cfg.CaptureSoundMetric == "Tiles" and count or count / playableTotal * 100
    local step = math.max(0.001, cfg.CaptureSoundStep or 5)
    -- Thresholds are per completed capture, not total territory held.
    local tier = math.floor(gain / step + 1e-9)
    local pitch = math.clamp((cfg.CaptureSoundBasePitch or 0.9)
        * 2 ^ (tier * (cfg.CaptureSoundSemitonesPerStep or 0.6) / 12), 0.5, 3)
    local id = cfg.CaptureSoundId or cfg.SoundBaseId or "rbxasset://sounds/electronicpingshort.wav"
    if tostring(id):match("^%d+$") then id = "rbxassetid://" .. id end
    return id, pitch, tier
end

-- Positive net percentage-point gain determines the number of reward notes.
-- 0.5 points -> 5, 1.0 -> 13 (rounded), 1.5 or more -> 20.
function Cues.CaptureRepeats(count, playableTotal)
    if type(count)~="number" or type(playableTotal)~="number"
        or count~=count or playableTotal~=playableTotal or count<=0 or playableTotal<=0
        or count==math.huge or playableTotal==math.huge then return 0 end
    local gain=count/playableTotal*100
    return math.floor(5+15*math.clamp((gain-.5),0,1)+.5)
end

return Cues
