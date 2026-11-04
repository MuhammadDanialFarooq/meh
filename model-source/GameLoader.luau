local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = script.Parent
local Config = require(Modules.Config)
local Renderer = require(Modules.Renderer)
local CameraController = require(Modules.CameraController)
local InputController = require(Modules.InputController)
local UIController = require(Modules.UIController)
local World = require(Modules.World)
local NameService = require(Modules.NameService)
local ReviveController = require(Modules.ReviveController)
local CaptureParticles = require(Modules.CaptureParticles)
local KillFeedback = require(Modules.KillFeedback)
local LandMergeEffects = require(Modules.LandMergeEffects)
local ArcadeEffects = require(Modules.ArcadeEffects)
local MotionEffects = require(Modules.MotionEffects)
local CoreGuiController = require(Modules.CoreGuiController)
local CosmeticController = require(Modules.CosmeticController)
local ToyWorldFX = require(Modules.ToyWorldFX)
local ExpandComboController = require(Modules.ExpandComboController)
local TerritoryVFX = require(Modules.TerritoryVFX)
local VictoryController = require(Modules.VictoryController)
local VictoryWorldFX = require(Modules.VictoryWorldFX)

local AudioController = require(Modules.AudioController)

local MenuDemo = require(Modules.MenuDemo)
local MultiplayerClient = require(Modules.MultiplayerClient)
local AbilityService = require(Modules.AbilityService)
local MatchmakingUI = require(Modules.MatchmakingUI)

local Loader = {}

function Loader.Start()
    CoreGuiController.DisablePlayerList()
    local audio = AudioController.new(Config)
    if RunService:IsStudio() and Config.RunVictoryRegressionTests == true then
        local ok, err = xpcall(function()
            require(Modules.RegressionTests).Run(Config)
        end, debug.traceback)
        if not ok then warn("[Paintland V26 TEST FAILED] " .. tostring(err)) end
    end
    local localPlayer = Players.LocalPlayer
    local renderer = Renderer.new(Config, localPlayer:WaitForChild("PlayerGui"))
    CosmeticController.Bind(renderer)
    local camera = CameraController.new(Config)
    local particles = CaptureParticles.new(renderer, Config)
    local killFeedback = KillFeedback.new(renderer.screen, Config)
    local mergeEffects = LandMergeEffects.new(renderer, Config)
    local arcadeEffects = ArcadeEffects.new(renderer, Config)
    local motionEffects = MotionEffects.new(renderer, Config)
    local toyFX = ToyWorldFX.new(renderer, Config)
    local expandCombo = ExpandComboController.new(renderer.screen, Config)
    local territoryVFX = TerritoryVFX.new(renderer, Config)
    local input = InputController.new(Config)
    local world = nil
    local nameService = NameService.new(Config)
    local running, frozenForRevive = false, false
    local hudTimer = 0
    local ui, revive, victory, network, matchmaking
    local practiceAbilities=AbilityService.new(Config)
    local victoryFX = VictoryWorldFX.new(renderer, Config)
    local newMatch, startMenu
    local function clearPresentation()
        victoryFX:Clear();particles:Clear();mergeEffects:Clear();audio:Reset()
        killFeedback:Reset();arcadeEffects:Clear();motionEffects:Clear();toyFX:Clear()
        expandCombo:Reset();territoryVFX:Clear()
    end
    local demo=MenuDemo.new(Config,renderer,{
        onReset=clearPresentation,
        onCapture=function(e,count,cells,demoWorld)
            if count>0 then
                territoryVFX:Play(e,count,cells,demoWorld.grid)
                toyFX:Capture(e,count)
            end
        end,
        onMerge=function(killer,victim,cells,hit)
            mergeEffects:Emit(killer,victim,cells,hit)
        end,
        onEliminate=function(victim,killer,_,hit)
            toyFX:Elimination(victim,killer,hit)
        end,
    })
    startMenu=function()
        if network and network.room and network.accepting~=false then network:Command("leave") end
        if matchmaking then matchmaking:Hide() end
        running=false;frozenForRevive=false
        if revive then revive:Close() end
        if victory then victory:Hide() end
        world=demo:Start()
        camera:Reset(demo.focus)
        ui:SetMode("menu")
    end

    -- A fresh game clears all previous actors, bots, trails, land and minimap data.
    newMatch = function(skin)
        if Config.MultiplayerEnabled~=false then
            demo:Stop();running=false;frozenForRevive=false
            if revive then revive:Close() end
            if victory then victory:Hide() end
            ui:NewRun();ui:SetMode("lobby")
            matchmaking:Show({private=false,code="",players={},capacity=Config.MultiplayerMaxPlayers or 8,state="lobby"})
            matchmaking:SetStatus("Connecting to an arena…")
            network:Command(network.room and "replay" or "quick",{skin=skin})
            return
        end
        -- Replay is the ONLY action that discards a completed arena.
        if victory then victory:Hide() end
        demo:Stop()
        frozenForRevive = false
        clearPresentation()
        if ui then ui:NewRun() end
        running = true
        if revive then revive:NewRun() end
        local nextWorld = World.new(Config, function(index)
            renderer:MarkCell(index)
            if ui and ui.minimap then ui.minimap:MarkCell(index) end
        end, {
            onSpawn = function(entity)
                renderer:ResetEntityVisual(entity.id)
                if entity.isHuman then
                    audio:Spawn()
                    camera:Reset(entity.pos)
                    arcadeEffects:Spawn(entity)
                    toyFX:Spawn(entity)
                    ui:SetMode("playing")
                    ui:Toast("CAPTURE THE ARENA!", entity.color)
                end
            end,
            onCapture = function(entity, count, changedCells)
                if entity.isHuman then audio:Capture(count, world.grid.playableTotal) end
                renderer:ClearTrail(entity.id)
                if count > 0 then
                    territoryVFX:Play(entity, count, changedCells, world.grid)
                    particles:Emit(entity, world.grid, changedCells, camera.position)
                    arcadeEffects:Capture(entity, count)
                    toyFX:Capture(entity, count)
                end
                if entity.isHuman and count > 0 then
                    camera:CapturePulse(entity.heading, count)
                    expandCombo:Show(count / world.grid.playableTotal * 100, entity.color)
                end
            end,
            onMerge = function(killer, victim, takenCells, hit)
                mergeEffects:Emit(killer, victim, takenCells, hit)
                arcadeEffects:Merge(killer, takenCells, world.grid)
            end,
            onAbsorb = function(killer, amount, takenCells)
                if amount > 0 then
                    particles:Emit(killer, world.grid, takenCells, camera.position)
                    territoryVFX:Play(killer, amount, takenCells, world.grid)
                    if killer.isHuman then
                        camera:CapturePulse(killer.heading, amount)
                    end
                end
            end,
            onVictory = function(winner, wonWorld)
                audio:Victory()
                -- Irreversible game state. Do not let later callbacks restart it.
                running = false
                frozenForRevive = false
                print(string.format("[Paintland V26] Win event: %d/%d cells, alive=%s",
                    wonWorld.grid.counts[winner.id] or 0, wonWorld.grid.playableTotal,
                    tostring(winner.alive)))

                local function visual(actionName, callback)
                    local ok, err = xpcall(callback, debug.traceback)
                    if not ok then
                        warn("[Paintland V26] " .. actionName .. " failed: " .. tostring(err))
                    end
                    return ok
                end
                visual("CloseRevive", function() if revive then revive:Close() end end)
                visual("VictoryMode", function() ui:SetMode("victory") end)
                -- Show the result FIRST, so broken particles cannot hide it.
                local shown = visual("VictoryScreen", function()
                    assert(victory, "VictoryController not ready")
                    victory:Show(wonWorld)
                end)
                if not shown then
                    visual("HideBrokenVictoryScreen", function()
                        if victory then victory:Hide() end
                    end)
                    visual("VictoryFallback", function() ui:SetMode("win") end)
                end
                visual("FreezeHudAt100", function()
                    ui:Update(wonWorld)
                    ui.progress:Update(100, winner.color)
                end)
                visual("VictoryWorldParticles", function() victoryFX:Play(winner) end)
            end,
            onEliminate = function(victim, killer, cause, hit)
                if victim.isHuman then ui:RecordDefeat(world) end
                if killer and killer.isHuman and killer ~= victim and killer.alive then
                    audio:Kill(killer.killStreak)
                end
                if victim.isHuman then audio:Death() end
                arcadeEffects:Elimination(victim, killer, hit)
                toyFX:Elimination(victim, killer, hit)
                renderer:RemoveEntityVisual(victim.id)
                if killer and killer.isHuman and killer ~= victim and killer.alive then
                    killFeedback:OnKill(victim, killer)
                    camera:KillPulse(killer.heading, killer.killStreak)
                end
                if victim.isHuman then
                    killFeedback:Reset()
                    expandCombo:Reset()
                    -- Do not advance bots, captures or respawn timers while choosing.
                    frozenForRevive = true
                    ui:SetMode("revive")
                    revive:Open()
                end
            end,
        })
        world = nextWorld
        renderer:SetWorld(world)
        world:Start(localPlayer.DisplayName, skin)
        ui.minimap:SetWorld(world)
        nameService:Assign(world)
        ui:SetMode("playing")
        ui:Update(world)
        -- An optional Studio-only end-state test; disabled in published play.
        if RunService:IsStudio() and Config.StudioVictoryTest == true then
            for index = 1, world.grid.total do
                if world.grid.mask[index] then world.grid:Set(index, 1) end
            end
            world:CheckVictory()
        end
        if RunService:IsStudio() then
            local auditedWorld = world
            task.delay(2.5, function()
                if world ~= auditedWorld or not renderer.arena then return end
                local count = 0
                for _, actor in ipairs(auditedWorld.entities) do
                    if actor.alive then count += 1 end
                end
                local models = #renderer.arena.actorsFolder:GetChildren()
                local physicalLand = #renderer.arena.landFolder:GetChildren()
                local trails3d = #renderer.arena.trailFolder:GetChildren()
                print(string.format(
                    "[Paintland V22 Render Audit] alive=%d models=%d landParts=%d trailParts=%d camera=%s",
                    count, models, physicalLand, trails3d,
                    workspace.CurrentCamera and tostring(workspace.CurrentCamera.CameraType) or "nil"
                ))
                if count > 0 and models == 0 then
                    warn("[Paintland V22] World has live actors but no 3D models: check CharacterVisuals errors")
                end
                if physicalLand == 0 then
                    warn("[Paintland V22] No physical land geometry: check renderer chunk updates")
                end
            end)
        end
    end

    ui = UIController.new(renderer, Config, {
        onAbility=function(id)
            if not running or frozenForRevive or not world then return end
            if network then network:UseAbility(id)
            else
                local actor=world.entities[1]
                local accepted,result=practiceAbilities:Use(world,actor,id,true)
                ui:SetAbilityState({id=id,accepted=accepted,reason=not accepted and result or nil,
                    cooldowns=practiceAbilities:State(world,actor)})
                if accepted then arcadeEffects:Ability(id,actor,result) end
            end
        end,
        onSoundToggle = function(muted) audio:SetMuted(muted) end,
        onMainMenu = function() startMenu() end,
        onRooms = function(action)
            if not network then return end
            ui:SetMode("lobby")
            matchmaking:Show(nil)
            if action=="create" then
                matchmaking:SetStatus("Creating your private room…")
                network:Command("create",{skin=ui.skin})
            end
        end,
        onPlay = function(skin)
            local ok, err = xpcall(function()
                newMatch(skin)
            end, debug.traceback)
            if not ok then
                warn("[Paintland V22] Match creation failed: " .. tostring(err))
                ui:Toast("MATCH ERROR — CHECK STUDIO OUTPUT", Color3.fromRGB(240, 85, 83))
            end
        end,
    })
    victory = VictoryController.new(renderer.screen, Config, function()
        newMatch(ui.skin)
    end)
    revive = ReviveController.new(renderer.screen, Config, {
        isMuted = function() return audio.muted end,
        onRevive = function()
            if world and world:ReviveHuman() then
                frozenForRevive = false
                ui:SetMode("playing")
                ui:Toast("REVIVED!", world.entities[1].color)
            end
        end,
        onTimeout = function()
            if world and (world.completed or world:CheckVictory()) then return end
            -- End the run without silently launching another match.
            running=false
            frozenForRevive=false
            revive:Close()
            audio:Reset()
            ui:ShowDefeat(world)
        end,
    })

    if Config.MultiplayerEnabled~=false then
        matchmaking=MatchmakingUI.new(renderer.screen,Config,function(action,fields)
            fields=fields or {};fields.skin=ui.skin
            if action=="leave" then network:Command("leave");startMenu() else network:Command(action,fields) end
        end)
        local function showNetworkResult(snapshot)
            revive:Close();running=false;frozenForRevive=false;matchmaking:Hide()
            audio:Reset();ui.defeatStats=snapshot;ui:ShowDefeat(world)
        end
        network=MultiplayerClient.new(Config,{
            onWallet=function(wallet) ui:SetWallet(wallet) end,
            onAbilityState=function(state) ui:SetAbilityState(state) end,
            onAbility=function(id,actorId,effect)
                arcadeEffects:Ability(id,world and world.entities[actorId],effect)
            end,
            onChanged=function(index)
                renderer:MarkCell(index);ui.minimap:MarkCell(index)
            end,
            onWorld=function(replica)
                demo:Stop();clearPresentation();world=replica
                renderer:SetWorld(world);ui.minimap:SetWorld(world)
                camera:Reset(world.entities[1].pos)
            end,
            onRespawn=function(entity)
                renderer:ResetEntityVisual(entity.id)
                if entity.id==1 then camera:Reset(entity.pos) end
            end,
            onLobby=function(lobby)
                if lobby.state=="running" then
                    matchmaking:Hide()
                    if ui.mode=="lobby" or ui.mode=="menu" then ui:SetMode("playing");running=true end
                elseif lobby.state=="lobby" then
                    demo:Stop();ui:SetMode("lobby");matchmaking:Show(lobby);running=false
                end
            end,
            onSnapshot=function(replica)
                world=replica
                if replica.roomState=="running" and ui.mode=="lobby" then
                    matchmaking:Hide();ui:SetMode("playing");running=true
                end
            end,
            onDeath=function(snapshot,remaining,credits)
                running=false;frozenForRevive=true;ui.defeatStats=snapshot;audio:Death()
                ui:SetMode("revive");killFeedback:Reset();expandCombo:Reset()
                revive:OpenServer(remaining,credits,function() network:Command("revive") end,
                    function() network:Command("decline") end)
            end,
            onResult=showNetworkResult,
            onRevived=function()
                revive:Close();frozenForRevive=false;running=true;ui:SetMode("playing");audio:Spawn()
            end,
            onCapture=function(id,count,total)
                if world and id==1 then
                    audio:Capture(count,total);expandCombo:Show(count/math.max(1,total)*100,world.entities[1].color)
                    camera:CapturePulse(world.entities[1].heading,count)
                end
            end,
            onElimination=function(victimId,killerId)
                local victim=world and world.entities[victimId]
                local killer=world and killerId and world.entities[killerId]
                if victim then renderer:RemoveEntityVisual(victimId) end
                if killerId==1 and victimId~=1 and killer then
                    audio:Kill((killer.killStreak or 0)+1);killFeedback:OnKill(victim,killer)
                    camera:KillPulse(killer.heading,(killer.killStreak or 0)+1)
                end
            end,
            onVictory=function(winnerId,replica)
                world=replica;running=false;frozenForRevive=false;revive:Close();matchmaking:Hide()
                if winnerId==1 then
                    ui:SetMode("victory");victory:Show(world);audio:Victory();victoryFX:Play(world.entities[1])
                else
                    ui:RecordDefeat(world);showNetworkResult(ui.defeatStats)
                end
            end,
            onJoining=function(message) ui:SetMode("lobby");matchmaking:Show(nil);matchmaking:SetStatus(message) end,
            onError=function(message)
                if revive.active and revive.serverMode then revive:ServerRejected(message) end
                if matchmaking.root.Visible then matchmaking:SetStatus(message)
                else ui:Toast(message,Color3.fromRGB(255,210,180)) end
            end,
            onLeft=function() startMenu() end,
        })
    end
    startMenu()

    local lastFrameError = nil
    local function updateFrame(dt)
        if not renderer.screen.Parent then return end
        local realDt = dt
        dt = math.min(dt, 0.08)
        if network and network:GetWorld() and network.accepting~=false then
            network:Update(realDt,function(entity) return input:GetHeading(entity,renderer,camera) end)
            world=network:GetWorld()
        elseif demo.active then
            demo:Update(realDt)
            world=demo.world
            camera:Update(demo.focus,dt)
        elseif running and not frozenForRevive and world then
            local steps = math.min(Config.MaxSubsteps,
                math.max(1, math.ceil(dt / Config.SimulationSubstep)))
            local each = math.min(dt / steps, Config.SimulationSubstep)
            for _ = 1, steps do
                world:Step(each, function(e)
                    return input:GetHeading(e, renderer, camera)
                end)
                if frozenForRevive or (world and world.completed) then break end
            end
        end
        if world and not demo.active then
            local player = world.entities[1]
            if player and player.alive then camera:Update(player.pos, dt) end
        end
        camera:Apply()
        toyFX:Update(realDt)
        renderer:Render(camera.position, realDt)
        arcadeEffects:Update(realDt, camera.position)
        motionEffects:Update(realDt, world and world.entities[1] or nil,
            camera.position, running and not frozenForRevive)
        if not frozenForRevive then
            particles:Update(realDt, camera.position)
            killFeedback:Update(realDt)
            mergeEffects:Update(realDt)
        end
        if not demo.active and world and world.completed and victory and not victory.active then
            -- Backup if an earlier presentation callback was interrupted.
            running = false
            local ok, err = pcall(function() victory:Show(world) end)
            if not ok then warn("[Paintland V26] Victory screen retry failed: " .. tostring(err)) end
        end
        if not demo.active then ui.minimap:Render(dt, camera.position) end
        if victory then victory:Update(realDt) end
        -- Countdown uses real elapsed frame time, not capped simulation delta.
        revive:Update(realDt)
        audio:Update(realDt)
        ui:UpdatePresentation(realDt)
        if not network and running and world and world.entities[1] then
            ui:SetAbilityState({cooldowns=practiceAbilities:State(world,world.entities[1])})
        end
        if world and not demo.active then
            -- Diagnostic only when near completion. Actual completion is
            -- inside World and never depends on this HUD refresh.
            hudTimer += dt
            if hudTimer >= 0.25 then
                hudTimer = 0
                ui:Update(world)
                -- Winning is settled by World:CheckVictory, not a HUD timer.
            end
        end
    end

    RunService:BindToRenderStep("PaintlandWorldRenderV24", Enum.RenderPriority.Camera.Value + 2, function(dt)
        local ok, err = xpcall(function()
            updateFrame(dt)
        end, debug.traceback)
        if not ok and err ~= lastFrameError then
            lastFrameError = err
            warn("[Paintland V22] Render error: " .. tostring(err))
            if ui then
                ui:Toast("RENDER ERROR — CHECK STUDIO OUTPUT", Color3.fromRGB(240, 85, 83))
            end
        end
    end)
    return {Network=network,Matchmaking=matchmaking,MenuDemo = demo, Audio = audio, UI = ui, Input = input, Renderer = renderer, Revive = revive,
        Particles = particles, Camera = camera, KillFeedback = killFeedback,
        LandMergeEffects = mergeEffects, ArcadeEffects = arcadeEffects, MotionEffects = motionEffects,
        ExpandCombo = expandCombo, TerritoryVFX = territoryVFX, Cosmetics = CosmeticController,
        Victory = victory, VictoryFX = victoryFX}
end

return Loader
