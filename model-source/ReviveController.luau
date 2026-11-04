-- V41: blue arcade revive overlay, fixed draining heart and responsive actions.
-- No purchases or persistent reads/writes are triggered in Roblox Studio.
local Fonts=require(script.Parent.Fonts)
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AdService = game:GetService("AdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ButtonEffects = require(script.Parent.ButtonEffects)
local ReviveHeart = require(script.Parent.ReviveHeart)
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
        TextColor3 = textColor, FontFace = Fonts.Bold,
        TextWrapped = true, ZIndex = 102,
    })
end

local function button(parent, name, text, y, color)
    local item = make(parent, "TextButton", name, {
        Size = UDim2.new(1, -36, 0, 44),
        Position = UDim2.fromOffset(18, y),
        Text = text, TextSize = 15, FontFace = Fonts.Bold,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextStrokeColor3=Color3.fromRGB(20,35,119),TextStrokeTransparency=0,
        AnchorPoint=Vector2.new(.5,.5),
        BackgroundColor3 = color, BackgroundTransparency = 0,
        BorderSizePixel = 0, ZIndex = 103, AutoButtonColor = true,
    })
    round(item, 14)
    make(item,"UIStroke","ButtonOutline",{Color=Color3.fromRGB(20,35,119),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    return item
end

function Revive.new(screen, cfg, callbacks)
    local self = setmetatable({}, Revive)
    self.cfg, self.callbacks = cfg, callbacks
    self.active, self.state, self.action = false, "closed", nil
    self.serverMode=false;self.destroyed=false
    self.remaining = cfg.ReviveWindowSeconds
    self.adsUsed, self.credits = 0, 0
    self.available, self.checkingAd = false, false
    self.purchasedProductId = 0
    self.runSerial, self.requestSerial, self.waitTime = 0, 0, 0
    self.isStudio = STUDIO
    self.network = nil

    local root=make(screen,"Frame","ReviveOverlay",{Size=UDim2.fromScale(1,1),
        BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.04,BorderSizePixel=0,
        Active=true,Visible=false,ZIndex=100})
    self.root=root
    make(root,"UIGradient","BlueAtmosphere",{Rotation=65,Color=ColorSequence.new(
        Color3.fromRGB(8,82,227),Color3.fromRGB(0,201,232))})
    local card=make(root,"Frame","ReviveContent",{AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(760,500),
        BackgroundTransparency=1,BorderSizePixel=0,ZIndex=101})
    self.card=card
    self.hero=make(card,"Frame","HeartHero",{BackgroundTransparency=1,BorderSizePixel=0,ZIndex=102})
    self.actions=make(card,"Frame","ReviveActions",{BackgroundTransparency=1,BorderSizePixel=0,ZIndex=102})
    self.heading=label(self.hero,"Heading","Game over!",0,58,39,Color3.new(1,1,1))
    self.heading.TextStrokeColor3=Color3.fromRGB(20,35,119);self.heading.TextStrokeTransparency=0
    self.heading.TextScaled=true
    make(self.heading,"UITextSizeConstraint","TitleLimit",{MinTextSize=22,MaxTextSize=48})
    self.description=label(self.hero,"Description","Your color deserves another chance.",58,32,13,Color3.new(1,1,1))
    self.description.FontFace=Fonts.Regular
    self.heart=ReviveHeart.new(self.hero,cfg,callbacks.isMuted)
    self.countdown=self.heart.countdown
    self.adButton=button(self.actions,"WatchAd","REVIVE",0,Color3.fromRGB(128,244,44))
    self.buyButton=button(self.actions,"BuyRevive","REVIVE WITH ROBUX",0,Color3.fromRGB(38,168,250))
    self.creditButton=button(self.actions,"CreditRevive","USE REVIVE CREDIT",0,Color3.fromRGB(115,88,238))
    self.studioButton=button(self.actions,"StudioTestRevive","TEST REVIVE",0,Color3.fromRGB(255,188,57))
    self.studioButton.Visible=STUDIO
    self.endButton=button(self.actions,"EndRun","No, thanks",0,Color3.fromRGB(31,101,219))
    self.endButton.BackgroundTransparency=1
    self.endButton.Activated:Connect(function() self:EndRun() end)
    self.status=label(self.actions,"Status","",0,40,11,Color3.fromRGB(222,250,255))
    self.status.FontFace=Fonts.Regular
    self.resize=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Resize(root.AbsoluteSize)
    end)
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

    for _,b in ipairs({self.adButton,self.buyButton,self.creditButton,self.studioButton,self.endButton}) do
        ButtonEffects.Bind(b,cfg)
    end
    self:RefreshButtons()
    self:Resize(root.AbsoluteSize or Vector2.new(1280,720))
    task.defer(function() if root.Parent then self:Resize(root.AbsoluteSize) end end)
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
        if self.destroyed or not root.Parent then return end
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

-- Only the hero changes size; action hit targets remain at least 44 pixels.
function Revive:Resize(viewport)
    if not viewport or viewport.X<1 or viewport.Y<1 then return end
    local wide=viewport.X>=560 and viewport.X/viewport.Y>1.35
    local width=math.min(wide and 840 or 420,viewport.X-24)
    local height=math.min(wide and 470 or 600,viewport.Y-32)
    self.card.Size=UDim2.fromOffset(width,height)
    local count=self.serverMode and 2 or (STUDIO and 5 or 4)
    local actionHeight=count*48+40
    local actionWidth=wide and math.min(360,width*.53) or width
    local heroWidth=wide and width-actionWidth-20 or width
    local heroHeight=wide and height or height-actionHeight-10
    self.hero.Size=UDim2.fromOffset(heroWidth,heroHeight)
    self.hero.Position=UDim2.fromOffset(0,0)
    self.actions.Size=UDim2.fromOffset(actionWidth,actionHeight)
    self.actions.Position=UDim2.fromOffset(wide and width-actionWidth or 0,wide and (height-actionHeight)/2 or height-actionHeight)
    self.heading.Position=UDim2.fromOffset(0,0);self.heading.Size=UDim2.new(1,0,0,50)
    self.description.Position=UDim2.fromOffset(0,50);self.description.Size=UDim2.new(1,0,0,32)
    self.description.Visible=heroHeight>=220
    local top=self.description.Visible and 86 or 55
    local heartSize=math.max(80,math.min(240,heroWidth-36,heroHeight-top-8))
    self.heart.root.Size=UDim2.fromOffset(heartSize,heartSize)
    self.heart.root.Position=UDim2.new(.5,0,0,top+(heroHeight-top)/2)
    local buttons={self.adButton}
    if not self.serverMode then
        table.insert(buttons,self.buyButton);table.insert(buttons,self.creditButton)
        if STUDIO then table.insert(buttons,self.studioButton) end
    end
    table.insert(buttons,self.endButton)
    for i,b in ipairs(buttons) do
        b.Position=UDim2.new(.5,0,0,(i-1)*48+22)
        ButtonEffects.SetSize(b,UDim2.new(1,-12,0,44))
    end
    self.status.Position=UDim2.fromOffset(6,count*48);self.status.Size=UDim2.new(1,-12,0,40)
end

function Revive:RefreshButtons()
    if self.serverMode then
        local ready=self.active and self.state=="countdown" and self.remaining>0
        self.adButton.Visible=true;self.buyButton.Visible=false
        self.creditButton.Visible=false;self.studioButton.Visible=false
        self.adButton.Active=ready and (self.revivesLeft or 0)>0
        self.adButton.AutoButtonColor=false
        self.adButton.BackgroundTransparency=self.adButton.Active and 0 or .48
        self.adButton.Text=self.adButton.Active and "REVIVE" or ((self.revivesLeft or 0)>0 and "REVIVING…" or "NO REVIVES LEFT")
        self.endButton.Active=ready;self.endButton.AutoButtonColor=false
        self.endButton.BackgroundTransparency=1;self.endButton.TextTransparency=ready and 0 or .48
        return
    end
    -- Never hide the actual options. Explain why unavailable instead.
    self.adButton.Visible = true
    self.buyButton.Visible = true
    self.creditButton.Visible = true
    self.studioButton.Visible = STUDIO

    local waiting = self.state ~= "countdown"
    self.endButton.Active=self.active and not waiting
    self.endButton.AutoButtonColor=false
    self.endButton.BackgroundTransparency=1
    self.endButton.TextTransparency=self.endButton.Active and 0 or .48
    local adReady = not STUDIO and self.available and self.requestAd ~= nil
        and self.purchasedProductId > 0
        and self.adsUsed < self.cfg.ReviveMaxAdsPerRun
    local buyReady = not STUDIO and self.purchasedProductId > 0
    local creditReady = self.consume ~= nil and self.credits > 0 and not STUDIO

    if STUDIO then
        self.adButton.Text = "AD REVIVE UNAVAILABLE"
        self.buyButton.Text = "ROBUX REVIVE UNAVAILABLE"
    elseif self.purchasedProductId <= 0 then
        self.adButton.Text = "AD REVIVE UNAVAILABLE"
        self.buyButton.Text = "ROBUX REVIVE UNAVAILABLE"
    elseif self.adsUsed >= self.cfg.ReviveMaxAdsPerRun then
        self.adButton.Text = "AD REVIVES USED"
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
    self.adButton.AutoButtonColor = false
    self.buyButton.AutoButtonColor = false
    self.creditButton.AutoButtonColor = false
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
        if not self.destroyed and ok and type(result) == "table" and serial == self.runSerial then
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
    self.serverMode=false;self.serverRevive=nil;self.serverDecline=nil
    self.root.Visible = false
    if self.heart then self.heart:Stop() end
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
    self.serverMode=false;self.serverRevive=nil;self.serverDecline=nil
    self.state = "closed"
    self.action = nil
    self.requestSerial += 1
    self.root.Visible = false
    if self.heart then self.heart:Stop() end
end

function Revive:Open()
    if self.destroyed then return end
    self.serverMode=false;self.serverRevive=nil;self.serverDecline=nil
    self.active = true
    self.state = "countdown"
    self.remaining = self.cfg.ReviveWindowSeconds or 4
    self.action, self.waitTime = nil, 0
    self.root.Visible = true
    if self.heart then self.heart:Reset(self.remaining);self.heart:Update(0,self.remaining,self.remaining,false) end
    self.status.Text = STUDIO and "Studio test: no player data loads or saves" or
        "Choose an option before the timer ends"
    self.available = false
    self.checkingAd = not STUDIO and self.purchasedProductId > 0
        and self.adsUsed < self.cfg.ReviveMaxAdsPerRun
    self.requestSerial += 1
    local serial = self.requestSerial
    self:RefreshButtons()
    self:Resize(self.root.AbsoluteSize)

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

-- Multiplayer results and revives are authoritative server messages. The local
-- heart is a presentation timer; requests never grant a revive on this client.
function Revive:OpenServer(remaining,revivesLeft,onRevive,onDecline)
    if self.destroyed then return end
    self:Close()
    self.serverMode=true;self.active=true;self.root.Visible=true
    self.remaining=math.max(0,tonumber(remaining) or 4)
    self.serverTotal=math.max(self.cfg.ReviveWindowSeconds or 4,self.remaining,.001)
    self.revivesLeft=math.max(0,math.floor(tonumber(revivesLeft) or 0))
    self.serverRevive=onRevive;self.serverDecline=onDecline
    self.state=self.remaining>0 and "countdown" or "waiting"
    self.action=nil;self.waitTime=0
    self.status.Text=self.revivesLeft>0 and "Keep your land. Get back in the arena." or "Your run is complete."
    self.heart:Reset(self.serverTotal)
    self.heart:Update(0,self.remaining,self.serverTotal,self.state~="countdown")
    self:RefreshButtons();self:Resize(self.root.AbsoluteSize)
end
function Revive:RequestServerRevive()
    if not self.serverMode or not self.active or self.state~="countdown"
        or self.remaining<=0 or (self.revivesLeft or 0)<=0 then return end
    local callback=self.serverRevive
    self.state="waiting";self.action="serverRevive";self.waitTime=0
    self.status.Text="Returning to the arena…"
    if self.heart then self.heart:Update(0,self.remaining,self.serverTotal,true) end
    self:RefreshButtons()
    if callback then callback() end
end
function Revive:ServerRejected(message)
    if not self.serverMode or not self.active then return end
    -- A rejected revive does not invent additional countdown time. Request the
    -- final result when the original local deadline has already passed.
    self.state="countdown";self.action=nil;self.status.Text=message or "Revive unavailable"
    self:RefreshButtons()
    if self.remaining<=0 then self:EndRun() end
end

function Revive:RestoreCountdown(message)
    if not self.active then return end
    self.state = "countdown"
    self.action = nil
    self.status.Text = message or "Choose a revive option"
    self:RefreshButtons()
end

function Revive:RequestAd()
    if self.serverMode then self:RequestServerRevive();return end
    if not self.adButton.Active then return end
    self.state, self.action, self.waitTime = "waiting", "ad", 0
    if self.heart then self.heart:Update(0,self.remaining,self.cfg.ReviveWindowSeconds,true) end
    self.status.Text = "Opening rewarded video..."
    self:RefreshButtons()
    self.requestAd:FireServer()
end

function Revive:RequestPurchase()
    if self.serverMode then return end
    if not self.buyButton.Active then return end
    self.state, self.action, self.waitTime = "waiting", "purchase", 0
    if self.heart then self.heart:Update(0,self.remaining,self.cfg.ReviveWindowSeconds,true) end
    self.status.Text = "Opening purchase prompt..."
    self:RefreshButtons()
    local ok = pcall(function()
        MarketplaceService:PromptProductPurchase(Players.LocalPlayer, self.purchasedProductId)
    end)
    if not ok then self:RestoreCountdown("Robux prompt failed to open") end
end

function Revive:CompleteRevive()
    if not self.active or self.serverMode then return end
    self.active, self.state, self.action = false, "closed", nil
    self.requestSerial += 1
    self.root.Visible = false
    if self.heart then self.heart:Stop() end
    self.callbacks.onRevive()
end

function Revive:UseCredit()
    if self.serverMode then return end
    if not self.creditButton.Active then return end
    self.state, self.action, self.waitTime = "consuming", "credit", 0
    if self.heart then self.heart:Update(0,self.remaining,self.cfg.ReviveWindowSeconds,true) end
    self.status.Text = "Confirming credit..."
    self:RefreshButtons()
    local serial=self.requestSerial
    task.spawn(function()
        local ok, result = pcall(function() return self.consume:InvokeServer() end)
        if self.destroyed or not self.active or self.serverMode or serial~=self.requestSerial or self.action~="credit" then return end
        if ok and type(result) == "table" and result.success then
            self.credits = result.credits or 0
            self:CompleteRevive()
        else
            self:RestoreCountdown("Revive credit couldn't be confirmed")
        end
    end)
end

function Revive:OnServerMessage(message)
    if self.destroyed or self.serverMode or type(message) ~= "table" then return end
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
    if self.serverMode then return (self.revivesLeft or 0)>0 end
    return STUDIO or self.checkingAd or self.adButton.Active
        or self.buyButton.Active or self.creditButton.Active
end

-- Do not abandon a pending purchase/ad/credit confirmation through this button.
function Revive:EndRun()
    if not self.active or self.state~="countdown" then return end
    if self.serverMode then
        local callback=self.serverDecline
        self.state="waiting";self.action="serverDecline";self.waitTime=0
        self.status.Text="Loading your results…"
        if self.heart then self.heart:Update(0,self.remaining,self.serverTotal,true) end
        self:RefreshButtons()
        if callback then callback() end
        return
    end
    self:Close()
    self.callbacks.onTimeout()
end

function Revive:Update(dt)
    if not self.active then return end
    dt=math.max(0,dt)
    if self.serverMode then
        if self.state=="countdown" then
            self.remaining=math.max(0,self.remaining-dt)
            if self.heart then self.heart:Update(dt,self.remaining,self.serverTotal,false) end
            if self.remaining<=0 then self:EndRun() end
        else
            -- Keep the deadline moving even though the visual is paused awaiting
            -- acknowledgement. A failed request cannot extend the revive window.
            self.remaining=math.max(0,self.remaining-dt);self.waitTime+=dt
            if self.heart then self.heart:Update(dt,self.heart.remaining,self.serverTotal,true) end
            if self.waitTime>8 then self.status.Text="Waiting for the server…" end
        end
        return
    end
    if self.state == "countdown" then
        -- Only skip the prompt once capability discovery has actually finished.
        if self.networkResolved and not self:HasReviveOption() then
            self:EndRun()
            return
        end
        self.remaining = math.max(0, self.remaining - dt)
        self.countdown.Text = tostring(math.ceil(self.remaining))
        if self.heart then self.heart:Update(dt,self.remaining,self.cfg.ReviveWindowSeconds,false) end
        if self.remaining <= 0 then
            self:EndRun()
        end
    elseif self.state == "waiting" or self.state == "consuming" then
        self.countdown.Text = "···"
        if self.heart then self.heart:Update(dt,self.remaining,self.cfg.ReviveWindowSeconds,true) end
        self.waitTime += dt
        if self.waitTime > self.cfg.ReviveTransactionTimeout then
            self:RestoreCountdown("Verification timed out. Late credits remain saved.")
        end
    end
end

function Revive:Destroy()
    if self.destroyed then return end
    self.destroyed=true;self:Close()
    if self.resize then self.resize:Disconnect() end
    if self.updateConnection then self.updateConnection:Disconnect() end
    if self.purchaseConnection then self.purchaseConnection:Disconnect() end
    if self.heart then self.heart:Destroy() end
    self.root:Destroy()
end

return Revive
