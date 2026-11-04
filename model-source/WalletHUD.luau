-- Compact server-confirmed wallet. Loading/failure never pretends the balance is zero.
local Fonts=require(script.Parent.Fonts)
local Wallet={};Wallet.__index=Wallet
local INK=Color3.fromRGB(40,35,76)
local function make(parent,class,name,p)
    local o=Instance.new(class);o.Name=name;for k,v in pairs(p) do o[k]=v end;o.Parent=parent;return o
end
local function short(n)
    n=math.max(0,math.floor(tonumber(n) or 0))
    if n>=1000000 then return string.format("%.1fM",n/1000000) end
    if n>=10000 then return string.format("%.1fK",n/1000) end
    return tostring(n)
end
function Wallet.new(screen,cfg)
    local self=setmetatable({cfg=cfg,timer=0,loaded=false},Wallet)
    self.root=make(screen,"Frame","Wallet",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,12,1,-12),
        Size=UDim2.fromOffset(160,44),BackgroundTransparency=1,Active=false,ZIndex=160})
    self.cards={};self.values={};self.captions={}
    for i,data in ipairs({{"Coins",Color3.fromRGB(255,211,77)},{"Gems",Color3.fromRGB(178,139,255)}}) do
        local card=make(self.root,"Frame",data[1],{Position=UDim2.new((i-1)*.5,(i-1)*3,0,0),
            Size=UDim2.new(.5,-3,1,0),BackgroundColor3=Color3.fromRGB(255,250,232),BorderSizePixel=0,Active=false,ZIndex=160})
        make(card,"UICorner","Round",{CornerRadius=UDim.new(0,12)})
        make(card,"UIStroke","Edge",{Color=INK,Thickness=2})
        local icon=make(card,"Frame","Icon",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(0,13,.5,0),
            Size=UDim2.fromOffset(i==1 and 17 or 13,i==1 and 17 or 13),Rotation=i==2 and 45 or 0,
            BackgroundColor3=data[2],BorderSizePixel=0,Active=false,ZIndex=161})
        make(icon,"UICorner","Round",{CornerRadius=UDim.new(i==1 and 1 or 0,i==2 and 3 or 0)})
        make(icon,"UIStroke","Edge",{Color=INK,Thickness=1})
        self.captions[i]=make(card,"TextLabel","Caption",{Position=UDim2.fromOffset(25,4),Size=UDim2.new(1,-28,0,12),Text=data[1]:upper(),
            FontFace=Fonts.Bold,TextSize=8,TextColor3=INK,BackgroundTransparency=1,Active=false,ZIndex=161})
        self.values[i]=make(card,"TextLabel","Balance",{Position=UDim2.fromOffset(23,16),Size=UDim2.new(1,-25,0,23),Text="…",
            FontFace=Fonts.Bold,TextSize=16,TextColor3=INK,BackgroundTransparency=1,Active=false,ZIndex=161})
        self.cards[i]=card
    end
    if cfg.MultiplayerEnabled==false then
        self:Set({loaded=true,coins=0,gems=0,persistent=false})
        self.captions[1].Text="PRACTICE";self.captions[2].Text="PRACTICE"
    else self:Captions() end
    return self
end
function Wallet:Captions()
    local data=self.data or {}
    local status=data.saving and "SAVE PENDING" or (not self.loaded and "LOADING" or nil)
    self.captions[1].Text=status or (data.persistent==false and "COINS · TEST" or "COINS")
    self.captions[2].Text=status or (data.persistent==false and "GEMS · TEST" or "GEMS")
end
function Wallet:Set(data)
    self.loaded=data.loaded==true;self.data=data
    self.values[1].Text=self.loaded and short(data.coins) or "…"
    self.values[2].Text=self.loaded and short(data.gems) or "…"
    local coins,gems=math.max(0,data.deltaCoins or 0),math.max(0,data.deltaGems or 0)
    if coins>0 or gems>0 then
        self.timer=2.2
        self:Captions()
        if coins>0 then self.captions[1].Text="+"..short(coins).." COINS" end
        if gems>0 then self.captions[2].Text="+"..short(gems).." GEMS!" end
    elseif self.timer<=0 or data.saving then self:Captions() end
end
function Wallet:Update(dt)
    if self.timer<=0 then return end
    self.timer=math.max(0,self.timer-dt)
    if self.timer==0 then self:Captions() end
end
function Wallet:Resize(size,mode)
    local playing=mode=="playing"
    local stacked=playing and size.X<600 and size.Y>=500
    self.root.AnchorPoint=Vector2.new(0,1)
    self.root.Position=UDim2.new(0,12,1,-12)
    self.root.Size=UDim2.fromOffset(size.X<600 and 160 or 224,44)
    if playing then
        self.root.AnchorPoint=Vector2.zero
        if stacked then
            self.root.Position=UDim2.fromOffset(12,240);self.root.Size=UDim2.fromOffset(116,94)
        elseif size.X<900 or size.Y<500 then
            self.root.AnchorPoint=Vector2.new(.5,0);self.root.Position=UDim2.new(.5,0,0,132)
            self.root.Size=UDim2.fromOffset(size.X<620 and 208 or 224,44)
        else self.root.Position=UDim2.fromOffset(18,128) end
    end
    for i,card in ipairs(self.cards) do
        card.Position=stacked and UDim2.fromOffset(0,(i-1)*50) or UDim2.new((i-1)*.5,(i-1)*3,0,0)
        card.Size=stacked and UDim2.new(1,0,0,44) or UDim2.new(.5,-3,0,44)
    end
end
function Wallet:Destroy() self.root:Destroy() end
return Wallet
