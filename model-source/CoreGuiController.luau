-- Hide Roblox's default player-list leaderboard, while preserving the
-- Roblox menu and accessibility/platform controls.
local StarterGui = game:GetService("StarterGui")

local CoreGuiController = {}

function CoreGuiController.DisablePlayerList()
    -- CoreGui may not be initialized on the first client frame.
    task.spawn(function()
        for attempt = 1, 12 do
            local ok = pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
            end)
            if ok then return end
            task.wait(0.3)
        end
        warn("[Paintland] Could not hide Roblox player list")
    end)
end

return CoreGuiController
