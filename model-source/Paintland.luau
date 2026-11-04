-- Full bootstrap guard. If a required module crashes, print the error on screen
-- instead of leaving players staring at an empty arena.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function showStartupError(message)
    warn("[Paintland V42] " .. tostring(message))
    local old = playerGui:FindFirstChild("PaintlandStartupError")
    if old then old:Destroy() end
    local gui = Instance.new("ScreenGui")
    gui.Name = "PaintlandStartupError"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Parent = playerGui
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Size = UDim2.new(0.85, 0, 0, 155)
    label.BackgroundColor3 = Color3.fromRGB(28, 43, 51)
    label.TextColor3 = Color3.fromRGB(255, 241, 236)
    label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
    label.TextSize = 17
    label.TextWrapped = true
    label.Text = "PAINTLAND STARTUP ERROR\n" .. tostring(message)
        .. "\nCheck View > Output in Roblox Studio."
    label.Parent = gui
end

local ok, errorMessage = xpcall(function()
    local modules = ReplicatedStorage:WaitForChild("PaintlandModules", 15)
    assert(modules, "Install PaintlandModules under ReplicatedStorage (V42 uses shared modules)")
    local loader = require(modules:WaitForChild("GameLoader", 10))
    loader.Start()
end, debug.traceback)
if not ok then showStartupError(errorMessage) end
