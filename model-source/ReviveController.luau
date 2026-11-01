-- Paintland v7: All revive controls are built in code and always visible.
-- No purchases or persistent reads/writes are triggered in Roblox Studio.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AdService = game:GetService("AdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Revive = {}
Revive.__index = Revive
local STUDIO = RunService:IsStudio()

local function make(parent, className, name, properties)
    local item = Instance.new(className)
    item.Name = name
    for key, value in pairs(properties) do item[key] = value end
    item.Parent = parent
    return item
end

local function round(parent, size)
    make(parent, "UICorner", "Corner", {CornerRadius = UDim.new(0, size)})
end

local function label(parent, name, text, y, height, fontSize, textColor)
    return make(parent, "TextLabel", name, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -28, 0, height),
        Position = UDim2.fromOffset(14, y),
        Text = text, TextSize = fontSize,
        TextColor3 = textColor, Font = Enum.Font.GothamBold,
        TextWrapped = true, ZIndex = 102,
    })
end

local function button(parent, name, text, y, color)
    local item = make(parent, "TextButton", name, {
        Size = UDim2.new(1, -36, 0, 44),
        Position = UDim2.fromOffset(18, y),
        Text = text, TextSize = 15, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(31, 51, 58),
        BackgroundColor3 = color, BackgroundTransparency = 0,
        BorderSizePixel = 0, ZIndex = 103, AutoButtonColor = true,
    })
    round(item, 9)
    return item
end

function Revive.new(screen, cfg, callbacks)
    local self = setmetatable({}, Revive)
    self.cfg, self.callbacks = cfg, callbacks
    self.active, self.state, self.action = false, "closed", nil
    self.remaining = cfg.ReviveWindowSeconds
    self.adsUsed, self.credits = 0, 0
    self.available, self.checkingAd = false, false
    self.purchasedProductId = 0
    self.runSerial, self.requestSerial, self.waitTime = 0, 0, 0
    self.isStudio = STUDIO
    self.network = nil

    local root = make(screen, "Frame", "ReviveOverlay", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(18, 37, 43),
        BackgroundTransparency = 0.30, BorderSizePixel = 0,
        Active = true, Visible = false, ZIndex = 100,
    })
    self.root = root

    local card = make(root, "Frame", "ReviveCard", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(370, STUDIO and 454 or 403),
        BackgroundColor3 = Color3.fromRGB(250, 253, 248),
        BorderSizePixel = 0, ZIndex = 101,
    })
    self.card = card
    round(card, 17)
    local cardStroke = make(card, "UIStroke", "CardBorder", {
        Color = Color3.fromRGB(219, 233, 226), Thickness = 1.5, Transparency = 0.15,
    })
    self.scale = make(card, "UIScale", "ResponsiveScale", {Scale = 1})
    self.resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local size = root.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
            self.scale.Scale = math.clamp(math.min(
                (size.X - 24)/370, (size.Y - 24)/(STUDIO and 454 or 403)
            ), 0.48, 1)
        end
    end)
    task.defer(function()
        if screen.Parent then
            local s = root.AbsoluteSize
            if s.X > 0 and s.Y > 0 then
                self.scale.Scale = math.clamp(math.min(
                    (s.X - 24)/370, (s.Y - 24)/(STUDIO and 454 or 403)
                ), 0.48, 1)
            end
        end
    end)

    local ink = Color3.fromRGB(31, 51, 58)
    self.heading = label(card, "Heading", "ONE MORE CHANCE", 18, 43, 27, ink)
    self.countdown = label(card, "Countdown", "5", 57, 48, 43, Color3.fromRGB(233, 139, 64))
    self.description = label(card, "Description", "Keep everything you captured", 104, 31, 13, Color3.fromRGB(94, 115, 121))
    self.adButton = button(card, "WatchAd", "CHECKING AD...", 142, Color3.fromRGB(255, 207, 77))
    self.buyButton = button(card, "BuyRevive", "REVIVE WITH ROBUX", 193, Color3.fromRGB(152, 225, 175))
    self.creditButton = button(card, "CreditRevive", "USE REVIVE CREDIT", 244, Color3.fromRGB(214, 229, 234))
    self.studioButton = button(card, "StudioTestRevive", "TEST REVIVE (STUDIO ONLY)", 295, Color3.fromRGB(255, 223, 143))
    self.studioButton.Visible = STUDIO
    self.endButton = button(card, "EndRun", "END RUN", STUDIO and 346 or 295, Color3.fromRGB(225,230,238))
    self.endButton.Size = UDim2.new(1,-36,0,36)
    self.endButton.Activated:Connect(function() self:EndRun() end)
    self.status = label(card, "Status", "", STUDIO and 390 or 339,
        STUDIO and 42 or 42, 12, Color3.fromRGB(82, 100, 110))

    for _, b in ipairs({self.adButton, self.buyButton, self.creditButton, self.studioButton}) do
        make(b, "UIStroke", "Border", {Color = Color3.fromRGB(132, 157, 151), Thickness = 1, Transparency = 0.62})
    end
    self.adButton.Activated:Connect(function() self:RequestAd() end)
    self.buyButton.Activated:Connect(function() self:RequestPurchase() end)
    self.creditButton.Activated:Connect(function() self:UseCredit() end)
    self.studioButton.Activated:Connect(function()
        if STUDIO and self.active and self.state == "countdown" then
            self:CompleteRevive()
        end
    end)

    self.purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
        function(userId, productId, purchased)
            if userId ~= Players.LocalPlayer.UserId or productId ~= self.purchasedProductId then return end
            if not self.active or self.action ~= "purchase" then return end
            if purchased then
                self.state = "waiting"
                self.waitTime = 0
                self.status.Text = "Verifying Roblox receipt..."
            else
                self:RestoreCountdown("Purchase cancelled")
            end
        end
    )

    self:RefreshButtons()
    -- Do not block game startup waiting for the server Script to initialize.
    task.spawn(function()
        local folder = ReplicatedStorage:WaitForChild("PaintlandRevive", 12)
        if not folder or not root.Parent then
            self.networkResolved=true
            return
        end
        self.network = folder
        self.updated = folder:WaitForChild("Updated", 10)
        self.beginRun = folder:WaitForChild("BeginRun", 10)
        self.consume = folder:WaitForChild("ConsumeCredit", 10)
        self.requestAd = folder:WaitForChild("RequestAd", 10)
        self.purchasedProductId = tonumber(folder:GetAttribute("ProductId")) or 0
        if self.updated then
            self.updateConnection = self.updated.OnClientEvent:Connect(function(message)
                self:OnServerMessage(message)
            end)
        end
        -- Synchronize again if the match started before the remote appeared.
        self:SyncRun(self.runSerial)
        self:RefreshButtons()
    end)
    return self
end

function Revive:RefreshButtons()
    -- Never hide the actual options. Explain why unavailable instead.
    self.adButton.Visible = true
    self.buyButton.Visible = true
    self.creditButton.Visible = true
    self.studioButton.Visible = STUDIO

    local waiting = self.state ~= "countdown"
    self.endButton.Active=self.active and not waiting
    self.endButton.AutoButtonColor=self.endButton.Active
    self.endButton.BackgroundTransparency=self.endButton.Active and 0 or 0.48
    local adReady = not STUDIO and self.available and self.requestAd ~= nil
        and self.purchasedProductId > 0
        and self.adsUsed < self.cfg.ReviveMaxAdsPerRun
    local buyReady = not STUDIO and self.purchasedProductId > 0
    local creditReady = self.consume ~= nil and self.credits > 0 and not STUDIO

    if STUDIO then
        self.adButton.Text = "ADS UNAVAILABLE IN STUDIO"
        self.buyButton.Text = "ROBUX DISABLED IN STUDIO"
    elseif self.purchasedProductId <= 0 then
        self.adButton.Text = "ADS: SET PRODUCT ID"
        self.buyButton.Text = "ROBUX: SET PRODUCT ID"
    elseif self.adsUsed >= self.cfg.ReviveMaxAdsPerRun then
        self.adButton.Text = "AD LIMIT REACHED (2/2)"
    elseif self.checkingAd then
        self.adButton.Text = "CHECKING AD AVAILABILITY..."
    elseif self.available then
        self.adButton.Text = string.format("WATCH AD (%d LEFT)",
            self.cfg.ReviveMaxAdsPerRun - self.adsUsed)
    else
        self.adButton.Text = "AD NOT AVAILABLE"
    end
    if not STUDIO and buyReady then self.buyButton.Text = "REVIVE WITH ROBUX" end
    self.creditButton.Text = string.format("USE REVIVE CREDIT (%d)", self.credits)

    self.adButton.Active = self.active and not waiting and adReady
    self.buyButton.Active = self.active and not waiting and buyReady
    self.creditButton.Active = self.active and not waiting and creditReady
    self.adButton.AutoButtonColor = self.adButton.Active
    self.buyButton.AutoButtonColor = self.buyButton.Active
    self.creditButton.AutoButtonColor = self.creditButton.Active
    self.adButton.BackgroundTransparency = self.adButton.Active and 0 or 0.48
    self.buyButton.BackgroundTransparency = self.buyButton.Active and 0 or 0.48
    self.creditButton.BackgroundTransparency = self.creditButton.Active and 0 or 0.48
    self.studioButton.Active = self.active and self.state == "countdown"
end

function Revive:SyncRun(serial)
    if not self.beginRun or serial ~= self.runSerial then return end
    self.networkResolved=false -- credit availability is unknown until the server replies
    task.spawn(function()
        local ok, result = pcall(function() return self.beginRun:InvokeServer() end)
        if ok and type(result) == "table" and serial == self.runSerial then
            self.networkResolved=true
            self.adsUsed = tonumber(result.adsUsed) or 0
            self.credits = tonumber(result.credits) or 0
            self.purchasedProductId = tonumber(result.productId) or self.purchasedProductId
            self:RefreshButtons()
        end
    end)
end

function Revive:NewRun()
    self.runSerial += 1
    self.requestSerial += 1
    self.active = false
    self.root.Visible = false
    self.state = "closed"
    self.action = nil
    self.adsUsed = 0
    self.available, self.checkingAd = false, false
    self:SyncRun(self.runSerial)
    self:RefreshButtons()
end

-- Hide revive prompts without granting credits or resetting the run.
function Revive:Close()
    self.active = false
    self.state = "closed"
    self.action = nil
    self.requestSerial += 1
    self.root.Visible = false
end

function Revive:Open()
    self.active = true
    self.state = "countdown"
    self.remaining = self.cfg.ReviveWindowSeconds
    self.action, self.waitTime = nil, 0
    self.root.Visible = true
    self.status.Text = STUDIO and "Studio test: no player data loads or saves" or
        "Choose an option before the timer ends"
    self.available = false
    self.checkingAd = not STUDIO and self.purchasedProductId > 0
        and self.adsUsed < self.cfg.ReviveMaxAdsPerRun
    self.requestSerial += 1
    local serial = self.requestSerial
    self:RefreshButtons()

    if not self.checkingAd then return end
    task.spawn(function()
        local ok, result = pcall(function()
            return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
        end)
        if not self.active or serial ~= self.requestSerial then return end
        self.checkingAd = false
        self.available = ok and type(result) == "table"
            and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
        self:RefreshButtons()
    end)
end

function Revive:RestoreCountdown(message)
    if not self.active then return end
    self.state = "countdown"
    self.action = nil
    self.status.Text = message or "Choose a revive option"
    self:RefreshButtons()
end

function Revive:RequestAd()
    if not self.adButton.Active then return end
    self.state, self.action, self.waitTime = "waiting", "ad", 0
    self.status.Text = "Opening rewarded video..."
    self:RefreshButtons()
    self.requestAd:FireServer()
end

function Revive:RequestPurchase()
    if not self.buyButton.Active then return end
    self.state, self.action, self.waitTime = "waiting", "purchase", 0
    self.status.Text = "Opening purchase prompt..."
    self:RefreshButtons()
    local ok = pcall(function()
        MarketplaceService:PromptProductPurchase(Players.LocalPlayer, self.purchasedProductId)
    end)
    if not ok then self:RestoreCountdown("Robux prompt failed to open") end
end

function Revive:CompleteRevive()
    if not self.active then return end
    self.active, self.state, self.action = false, "closed", nil
    self.requestSerial += 1
    self.root.Visible = false
    self.callbacks.onRevive()
end

function Revive:UseCredit()
    if not self.creditButton.Active then return end
    self.state, self.action, self.waitTime = "consuming", "credit", 0
    self.status.Text = "Confirming credit..."
    self:RefreshButtons()
    task.spawn(function()
        local ok, result = pcall(function() return self.consume:InvokeServer() end)
        if not self.active then return end
        if ok and type(result) == "table" and result.success then
            self.credits = result.credits or 0
            self:CompleteRevive()
        else
            self:RestoreCountdown("Revive credit couldn't be confirmed")
        end
    end)
end

function Revive:OnServerMessage(message)
    if type(message) ~= "table" then return end
    if message.credits ~= nil then self.credits = message.credits end
    if message.adsUsed ~= nil then self.adsUsed = message.adsUsed end
    if message.kind == "Credit" and self.active then
        if self.action == "ad" or self.action == "purchase" then
            self.state = "countdown"
            self.action = nil
            self:RefreshButtons()
            self:UseCredit()
            return
        end
    elseif message.kind == "AdResult" and self.active and self.action == "ad" then
        if not message.completed then
            self.available = false
            self:RestoreCountdown("Ad unavailable or not completed")
        else
            self.status.Text = "Ad completed; waiting for receipt..."
        end
    end
    self:RefreshButtons()
end

function Revive:HasReviveOption()
    return STUDIO or self.checkingAd or self.adButton.Active
        or self.buyButton.Active or self.creditButton.Active
end

-- Do not abandon a pending purchase/ad/credit confirmation through this button.
function Revive:EndRun()
    if not self.active or self.state~="countdown" then return end
    self:Close()
    self.callbacks.onTimeout()
end

function Revive:Update(dt)
    if not self.active then return end
    if self.state == "countdown" then
        -- Only skip the prompt once capability discovery has actually finished.
        if self.networkResolved and not self:HasReviveOption() then
            self:EndRun()
            return
        end
        self.remaining = math.max(0, self.remaining - dt)
        self.countdown.Text = tostring(math.ceil(self.remaining))
        if self.remaining <= 0 then
            self:EndRun()
        end
    elseif self.state == "waiting" or self.state == "consuming" then
        self.countdown.Text = "···"
        self.waitTime += dt
        if self.waitTime > self.cfg.ReviveTransactionTimeout then
            self:RestoreCountdown("Verification timed out. Late credits remain saved.")
        end
    end
end

function Revive:Destroy()
    if self.resize then self.resize:Disconnect() end
    if self.updateConnection then self.updateConnection:Disconnect() end
    if self.purchaseConnection then self.purchaseConnection:Disconnect() end
    self.root:Destroy()
end

return Revive
