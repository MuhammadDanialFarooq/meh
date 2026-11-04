local Catalog=require(script.Parent.LoadoutCatalog)
local Registry=require(script.Parent.AbilityRegistry)
local Fonts=require(script.Parent.Fonts)
local Effects=require(script.Parent.ButtonEffects)
local Menu={};Menu.__index=Menu
local INK=Color3.fromRGB(40,35,76)
local function make(parent,class,name,p)
    local o=Instance.new(class);o.Name=name;for k,v in pairs(p) do o[k]=v end;o.Parent=parent;return o
end
local function label(parent,name,text,size,y,height)
    return make(parent,"TextLabel",name,{Position=UDim2.fromOffset(12,y),Size=UDim2.new(1,-24,0,height or 24),
        Text=text,TextColor3=INK,TextSize=size,FontFace=Fonts.Bold,BackgroundTransparency=1,Active=false,ZIndex=222})
end
local function button(parent,name,text)
    local b=make(parent,"TextButton",name,{AnchorPoint=Vector2.new(.5,.5),Text=text,TextSize=10,
        FontFace=Fonts.Bold,TextColor3=INK,BackgroundColor3=Color3.fromRGB(156,239,102),AutoButtonColor=false,
        BorderSizePixel=0,ZIndex=223})
    make(b,"UICorner","Round",{CornerRadius=UDim.new(0,12)});make(b,"UIStroke","Edge",{Color=INK,Thickness=2})
    return b
end
function Menu.new(screen,cfg,onRequest)
    local self=setmetatable({cfg=cfg,request=onRequest,rows={},pending=0},Menu)
    self.root=make(screen,"Frame","LoadoutMenu",{Size=UDim2.fromScale(1,1),BackgroundColor3=INK,
        BackgroundTransparency=.28,Visible=false,Active=true,ZIndex=220})
    self.panel=make(self.root,"Frame","Panel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundColor3=Color3.fromRGB(255,250,232),BorderSizePixel=0,ZIndex=221})
    make(self.panel,"UICorner","Round",{CornerRadius=UDim.new(0,22)})
    make(self.panel,"UIStroke","Outline",{Color=INK,Thickness=3})
    label(self.panel,"Title","YOUR LOADOUT",23,12,28)
    self.balance=label(self.panel,"Balance","Loading wallet…",11,44)
    self.scroll=make(self.panel,"ScrollingFrame","Items",{Position=UDim2.fromOffset(8,78),Size=UDim2.new(1,-16,1,-148),
        CanvasSize=UDim2.fromOffset(0,370),ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,
        BorderSizePixel=0,BackgroundTransparency=1,Active=true,ZIndex=222})
    local y=0
    for _,group in ipairs({{kind="character",title="CHARACTER",items=Catalog.Characters},{kind="ability",title="ONE ABILITY SLOT",items=Registry.List}}) do
        local heading=label(self.scroll,group.title,group.title,10,y,20);heading.TextXAlignment=Enum.TextXAlignment.Left;y+=24
        for _,product in ipairs(group.items) do
            local row=make(self.scroll,"Frame",product.Id,{Position=UDim2.fromOffset(4,y),Size=UDim2.new(1,-12,0,54),
                BackgroundColor3=Color3.fromRGB(242,231,212),BorderSizePixel=0,ZIndex=222})
            make(row,"UICorner","Round",{CornerRadius=UDim.new(0,12)})
            local title=label(row,"Name",product.Name,12,4,20);title.Size=UDim2.new(1,-126,0,20);title.TextXAlignment=Enum.TextXAlignment.Left
            local detail=label(row,"Detail",group.kind=="character" and (product.Ability~="" and ("Includes "..product.Ability) or "No built-in ability") or "Use with any character",9,26,18)
            detail.Size=UDim2.new(1,-126,0,18);detail.TextXAlignment=Enum.TextXAlignment.Left;detail.FontFace=Fonts.Regular
            local action=button(row,"Action","EQUIP");action.Position=UDim2.new(1,-58,.5,0)
            Effects.SetSize(action,UDim2.fromOffset(104,44));Effects.Bind(action,cfg)
            local view={kind=group.kind,product=product,button=action};table.insert(self.rows,view)
            action.Activated:Connect(function() if view.operation then self:Request(view.operation,product.Id) end end)
            y+=60
        end
    end
    self.scroll.CanvasSize=UDim2.fromOffset(0,y)
    self.status=label(self.panel,"Status","Buying also equips. One ability per round.",10,0,22)
    self.status.Position=UDim2.new(0,12,1,-66)
    self.close=button(self.panel,"Done","DONE");self.close.Position=UDim2.new(.73,0,1,-28)
    Effects.SetSize(self.close,UDim2.fromOffset(112,44));Effects.Bind(self.close,cfg)
    self.close.Activated:Connect(function() self:Hide() end)
    self.clear=button(self.panel,"Unequip","UNEQUIP ABILITY");self.clear.Position=UDim2.new(.27,0,1,-28)
    Effects.SetSize(self.clear,UDim2.fromOffset(112,44));Effects.Bind(self.clear,cfg)
    self.clear.Activated:Connect(function() self:Request("unequip","") end)
    self:Resize(Vector2.new(1280,720));return self
end
function Menu:Request(action,id)
    if not self.root.Visible or self.pending>0 or not self.wallet or not self.wallet.loaded then return end
    self.pending=8;self.status.Text="Saving selection…";self:Refresh();self.request(action,id)
end
function Menu:SetWallet(wallet) self.wallet=wallet;self:Refresh() end
function Menu:Refresh()
    local wallet=self.wallet or {};local inv=Catalog.Normalize(wallet.inventory)
    self.balance.Text=wallet.loaded and (tostring(wallet.coins).." COINS   ·   "..tostring(wallet.gems).." GEMS") or "Loading wallet…"
    for _,view in ipairs(self.rows) do
        local id=view.product.Id;local character=view.kind=="character"
        local equipped=character and inv.character==id or (not character and inv.equipped==id)
        local owned=character and inv.characters[id]==true or (not character and Catalog.CanEquip(inv,id))
        local currency,cost=Catalog.Price(self.cfg,view.kind,id)
        view.operation=not equipped and ((owned and "equip" or "buy")..(character and "Character" or "Ability")) or nil
        view.button.Text=equipped and "EQUIPPED" or (owned and "EQUIP" or (currency and ("BUY "..cost.." "..currency:upper()) or "UNAVAILABLE"))
        view.button.Active=self.pending<=0 and wallet.loaded==true and view.operation~=nil and (owned or currency~=nil)
        view.button.BackgroundTransparency=view.button.Active and 0 or .45
    end
end
function Menu:Result(accepted,message)
    self.pending=0;self.status.Text=message or (accepted and "Equipped" or "Try again");self:Refresh()
end
function Menu:Update(dt)
    if self.pending>0 then self.pending=math.max(0,self.pending-dt)
        if self.pending==0 then self.status.Text="Check your selection or retry safely.";self:Refresh() end
    end
end
function Menu:Show() self.root.Visible=true;self:Refresh() end
function Menu:Hide() self.root.Visible=false end
function Menu:Resize(size) self.panel.Size=UDim2.fromOffset(math.min(540,size.X-24),math.min(520,size.Y-32)) end
function Menu:Destroy() self.root:Destroy() end
return Menu
