local Config = {}

Config.Grid = 112
Config.Cell = 4
Config.Chunk = 28
Config.BotCount = 12
-- V14 input and HUD: one-finger drag steering, clean mobile presentation.
Config.TouchDeadzone = 18
Config.MouseDeadzone = 15
Config.LeaderboardRows = 4
Config.MinimapPhoneSize = 144
Config.MinimapDesktopSize = 190
Config.MinimapUpdateRate = 0.12


-- REVIVE WINDOW: game stays frozen while a real ad / Robux prompt is active.
Config.ReviveWindowSeconds = 5
Config.ReviveMaxAdsPerRun = 2
Config.ReviveTransactionTimeout = 90


-- === ARENA APPEARANCE (all generated at runtime) ===
-- Paste your uploaded Roblox image/decal ID here, e.g. 1234567890,
-- or "rbxassetid://1234567890". Keep 0 for the built-in subtle dotted floor.
Config.FloorTextureId = 0
Config.FloorTextureTileStuds = 32
Config.FloorTextureTransparency = 0.42
Config.FloorTextureTint = Color3.fromRGB(255, 255, 255)
Config.FloorColor = Color3.fromRGB(251, 249, 246)
Config.FloorDotColor = Color3.fromRGB(170, 206, 184)
Config.OutsideColor = Color3.fromRGB(174, 213, 222)
Config.BorderOuterColor = Color3.fromRGB(45, 50, 87)
Config.BorderInnerColor = Color3.fromRGB(250, 146, 114)
Config.BorderOuterThickness = 13 -- pixels at any zoom
Config.BorderInnerThickness = 5  -- pixels at any zoom
-- Toggle off only for debugging; exposed enemy trails are part of the gameplay.
Config.ShowBotTrails = true


-- Sample existing Roblox accounts, then use their verified display names.
-- An invalid ID is silently ignored by UserService. These are not live players.
Config.RandomUserIdMin = 10000000
Config.RandomUserIdMax = 2000000000
Config.NameLookupBatchSize = 44
Config.NameLookupAttempts = 3
Config.PlayerSpeed = 29
Config.BotSpeed = 27
Config.TurnRate = math.rad(610)
Config.TrailThickness = 3.3
Config.WorkspaceMergePartLimit = 26
Config.TrailSpacing = 3.5
Config.HitRadius = 3.4
Config.SpawnRadiusCells = 4
Config.RespawnDelay = 2.6
-- Safe-spawn: dead bots WAIT if no unclaimed, trail-free space exists.
Config.SpawnPaddingCells = 2
Config.SpawnMinEntityDistance = 36
Config.SpawnRetrySeconds = 2.5

-- Kill streaks: spring bounce and restrained arcade typography.
Config.KillPopupSpring = 17
Config.KillPopupDuration = 0.9
Config.KillComboWindowSeconds = 3
Config.KillCameraEnabled = true
Config.KillCameraImpulse = 5
Config.SimulationSubstep = 1 / 60
Config.MaxSubsteps = 4
Config.MaxChunksPerFrame = 6
-- V8 capture feedback: subtle world-space camera impulse; no strong shakes or zooms.
Config.CameraSpringFrequency = 25
Config.CameraKickSpringFrequency = 14
Config.CaptureCameraEnabled = true
Config.CaptureCameraImpulse = 18
Config.CameraKickMaxVelocity = 18
-- V8 cosmetic sparks originate in newly captured cells and curve toward the actor.
Config.CaptureParticlesEnabled = true
Config.CaptureParticlesPlayerCount = 19
Config.CaptureParticlesBotCount = 6
Config.CaptureParticlePoolLimit = 96
Config.CaptureParticleMaxDistance = 100
-- V12 arcade polish: all visual, pooled and mobile-aware.
Config.ImpactEffectsEnabled = true
Config.ReducedMotion = false -- disable moving sparks and trailing motes
Config.ImpactMaxRings = 14
Config.ImpactMaxSparks = 64
Config.ImpactShowBotCaptures = true
Config.MotionEffectsEnabled = true
Config.MotionDustPool = 14
Config.MotionDustInterval = 0.095
-- V31: Trail kills connect via recorded trails; other inheritance transfers directly.
-- The local HUMAN's land is reserved during their revive decision.
Config.DeathLandMergeMode = "TrailTakeover"
Config.TerritoryMergeEffectsEnabled = true
Config.TerritoryMergeOverlayLimit = 170
Config.TerritoryMergeDuration = 0.45
Config.TerritoryMergeWaveDelay = 0.25
-- Old all-land inheritance options are intentionally disabled.
Config.EnclosureTransfersAllLand = true
Config.TrailKillTransfersLand = true
Config.SelfTrailKills = true

-- V21 presentation: toy arena and stable phone framing.
Config.ArenaTileStuds = 16
Config.ArenaGridThickness = 0.10
Config.ArenaGridColor = Color3.fromRGB(219, 222, 228)
Config.CameraTiltDegrees = 21
Config.MobileWorldViewHeight = 144
Config.MouseWorldDeadzone = 2.5
Config.Colors = {
    Color3.fromRGB(23, 196, 158),
    Color3.fromRGB(253, 119, 95),
    Color3.fromRGB(70, 150, 250),
    Color3.fromRGB(172, 107, 250),
    Color3.fromRGB(253, 195, 65),
    Color3.fromRGB(250, 105, 163),
    Color3.fromRGB(98, 205, 101),
    Color3.fromRGB(60, 202, 221),
    Color3.fromRGB(235, 147, 85),
    Color3.fromRGB(127, 137, 248),
    Color3.fromRGB(188, 205, 57),
    Color3.fromRGB(234, 106, 190),
    Color3.fromRGB(81, 174, 116),
}

Config.BotNames = {
    "NeonFox", "SlyFox", "PixelKing", "Tornado", "Rex", "Doodle",
    "Pancake", "Shadow", "Flash", "Banana", "Squiggle", "Nova",
    "Orbit", "Goblin", "Vortex", "Jelly", "Cosmic", "Kiki",
}

Config.BotStyles = {"Farmer", "Aggressive", "Greedy", "Defensive", "Opportunist"}
-- V16: Smooth *curved* territories, not faceted polygons. The hidden
-- ownership grid still determines kills and scoring. Only the paint is softened.
Config.SmoothTerritoryEdges = true
Config.SmoothPixelsPerCell = 5          -- 560x560 image on desktop (112x5)
Config.SmoothPixelsPerCellMobile = 3    -- 336x336 on low-resolution phones
Config.SmoothDistanceBlur = 0.95      -- signed-distance smoothing; larger = rounder
Config.SmoothThinLandProtection = 0.35 -- keep narrow 1-cell land connections visible
Config.SmoothEdgeFeather = 0.15        -- antialias distance (cell units)
Config.SmoothCanvasInterval = 0.16     -- seconds between desktop canvas updates
Config.SmoothCanvasIntervalMobile = 0.32 -- less expensive on phones
-- V17 world-space character and camera. Real Parts live in Workspace.PaintlandRuntime.
Config.WorkspacePixelsPerStud = 4 -- legacy; no world SurfaceGui used
Config.Use3DTerritoryBackup = true -- single 3D land layer only
Config.WorkspaceBorderWidth = 6
Config.WorkspaceBorderInnerWidth = 2
Config.WorkspaceCameraFOV = 48
Config.WorldViewHeightStuds = 124
Config.CharacterHeight = 3.7
Config.DisableMobileCameraKick = true
Config.CameraSpringFrequency = 14
Config.CaptureCameraImpulse = 1.6
Config.KillCameraImpulse = 1.1
Config.CameraKickMaxVelocity = 4
-- Change these to accessible image/decal IDs, or 0 to leave the face empty.
Config.PlayerCosmetics = {
    Hat = "None",            -- "None", "Cap", "Crown", "TopHat"
    HatColor = Color3.fromRGB(42, 94, 210),
    FaceImageId = 0,        -- Image visible on top AND front of the character
    HatImageId = 0,         -- Optional image icon attached above the hat
}
Config.BotCosmetics = {Hat = "None", FaceImageId = 0, HatImageId = 0}

-- V22: circular playable arena and localized capture feedback
Config.CircleArena = true
Config.ArenaRadius = Config.Grid * Config.Cell * 0.5 - Config.Cell * 2
Config.ArenaBoundaryMargin = Config.Cell * 0.85
Config.CircleBorderStuds = 8
Config.CaptureWorldPopupDuration = 0.8
Config.CaptureWorldPopupMinCells = 3
Config.CaptureFlashMaxRegions = 24
Config.CaptureFlashMaxActive = 72
Config.CaptureFlashDuration = 0.24
Config.ExpandComboWindow = 6
Config.ExpandComboMax = 99
Config.ShowBotLandBillboards = false

-- Circular edge assist (must be declared BEFORE return).
Config.BoundaryAssistDepthCells = 2.5
Config.BoundaryAssistInwardCells = 2

-- Completion celebration; limited effects for mobile devices.
Config.VictoryEffectsEnabled = true
Config.VictoryConfettiCount = 34
Config.VictoryConfettiCountMobile = 20
Config.VictoryWorldSparkCount = 22
Config.VictoryWorldSparkCountMobile = 12
Config.VictoryTransitionSeconds = 0.35
-- Studio-only quick victory check; always ignored in published servers.
Config.StudioVictoryTest = false

-- Studio-only deterministic test for the 74%-to-0% ownership regression.
Config.RunVictoryRegressionTests = true

-- V28 local arcade audio. Five kill tiers; tier five repeats for streaks >= 5.
Config.SoundEnabled = true
Config.SoundMutedByDefault = true -- Toggle SOUND in the UI to enable; replace the placeholder pings below.
Config.SoundMasterVolume = 0.65
Config.SoundBaseId = "rbxasset://sounds/electronicpingshort.wav"
Config.KillSoundIds = {} -- Optional five permitted rbxassetid:// IDs; custom cues play at native pitch.
Config.KillSoundPitches = {0.9, 1.01, 1.13, 1.35, 1.51}
Config.KillSoundVolume = 0.75
Config.CaptureSoundId = Config.SoundBaseId
Config.CaptureSoundVolume = 0.22
Config.SpawnSoundId = Config.SoundBaseId
Config.DeathSoundId = Config.SoundBaseId
Config.VictorySoundId = Config.SoundBaseId
Config.CaptureSoundMetric = "Percentage" -- "Tiles" uses raw cell gain instead.
Config.CaptureSoundStep = 5 -- 0..<5, 5..<10, 10..<15 percentage points gained per capture.
Config.CaptureSoundBasePitch = 0.9
Config.CaptureSoundSemitonesPerStep = 0.6

-- Optional full-image replacements for the death buttons. Empty = Material sprite icons.
Config.DefeatPlayIconId = ""
Config.DefeatMenuIconId = ""

return Config
