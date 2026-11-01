-- Small, colorful arcade ranks with public Roblox avatar thumbnails.
-- Only four persistent UI rows; never recreate rows on score updates.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Avatars = require(script.Parent.AvatarThumbnails)
local Leaderboard = {}
Leaderboard.__index = Leaderboard

local WHITE=Color3.new(1,1,1)
local INK=Color3.fromRGB(25,46,123)
local ROW_COLORS={
    Color3.fromRGB(126,61,251),
    Color3.fromRGB(23,201,237),
    Color3.fromRGB(12,185,236),
    Color3.fromRGB(255,215,37),
}

local function gui(parent, class, name, props)
    local i=Instance.new(class)
    i.Name=name
    for k,v in pairs(props or {}) do i[k]=v end
    i.Parent=parent
    return i
end
local function circle(obj, px)
    return gui(obj,"UICorner","Round",{CornerRadius=UDim.new(0,px or 50)})
end
local function stroke(obj,color,width)
    return gui(obj,"UIStroke","Stroke",{Color=color,Thickness=width})
end
local function label(parent,name,value,size,depth)
    return gui(parent,"TextLabel",name,{
        BackgroundTransparency=1,Text=value,Font=Enum.Font.GothamBlack,
        TextSize=size,TextColor3=WHITE,TextStrokeColor3=INK,
        TextStrokeTransparency=1,ZIndex=depth or 37,
    })
end

function Leaderboard.new(parent,config)
    local self=setmetatable({},Leaderboard)
    self.cfg=config
    self.thumbnails=Avatars.new()
    self.compact=true
    self.panel=gui(parent,"Frame","ArcadeLeaderboard",{
        BackgroundColor3=Color3.fromRGB(19,30,48),BackgroundTransparency=.06,BorderSizePixel=0,
        AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-9,0,78),
        Size=UDim2.fromOffset(155,178),ZIndex=32,
    })
    circle(self.panel,18)
    stroke(self.panel,Color3.fromRGB(67,91,117),1)
    local heading=label(self.panel,"Heading","TOP PAINTERS",10,36)
    heading.TextColor3=Color3.fromRGB(166,187,205)
    heading.Position=UDim2.fromOffset(12,8)
    heading.Size=UDim2.new(1,-24,0,20)
    heading.TextXAlignment=Enum.TextXAlignment.Left
    self.rows={}
    for n=1,math.min(4,config.LeaderboardRows or 4) do
        local row=gui(self.panel,"Frame","Rank"..n,{
            BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset(0,(n-1)*43),
            Size=UDim2.new(1,0,0,40),ZIndex=33,
        })
        -- Colored strip starts behind the avatar and ends flush to screen edge.
        local bar=gui(row,"Frame","ColorStrip",{
            AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,0,0.5,0),
            Size=UDim2.new(1,-36,0,31),BorderSizePixel=0,
            BackgroundColor3=Color3.fromRGB(31,48,69),ZIndex=33,
        })
        circle(bar,10)
        local avatar=gui(row,"ImageLabel","Avatar",{
            Position=UDim2.fromOffset(3,1),Size=UDim2.fromOffset(38,38),
            BorderSizePixel=0, BackgroundColor3=Color3.fromRGB(242,246,255),
            Image="",ScaleType=Enum.ScaleType.Crop,ZIndex=36,
        })
        circle(avatar,19)
        stroke(avatar,INK,1.9)
        local fallback=label(avatar,"Fallback","●",21,37)
        fallback.Size=UDim2.fromScale(1,1)
        fallback.TextColor3=ROW_COLORS[n]
        fallback.TextStrokeTransparency=1
        local rank=gui(row,"TextLabel","RankBadge",{
            Size=UDim2.fromOffset(16,16), Position=UDim2.fromOffset(0,25),
            BackgroundColor3=WHITE, BorderSizePixel=0,Text=tostring(n),
            Font=Enum.Font.GothamBlack,TextColor3=INK,TextSize=10,ZIndex=40,
        })
        circle(rank,9)
        stroke(rank,INK,1)
        local percent=label(bar,"Percent","0.00%",15,38)
        percent.Size=UDim2.new(1,-14,1,0)
        percent.Position=UDim2.fromOffset(7,0)
        percent.TextXAlignment=Enum.TextXAlignment.Right
        local name=label(bar,"Username","",10,38)
        name.TextXAlignment=Enum.TextXAlignment.Left
        name.TextTruncate=Enum.TextTruncate.AtEnd
        name.TextStrokeTransparency=0.38
        name.Position=UDim2.fromOffset(10,0)
        name.Size=UDim2.new(1,-88,1,0)
        local crown=label(row,"Crown","👑",20,42)
        crown.Position=UDim2.fromOffset(11,-17)
        crown.Size=UDim2.fromOffset(28,22)
        crown.Visible=false
        self.rows[n]={row=row,bar=bar,avatar=avatar,fallback=fallback,rank=rank,
            percent=percent,name=name,crown=crown,userId=nil}
    end
    return self
end

function Leaderboard:Resize(viewport)
    local narrow=viewport.X<900
    self.compact=narrow
    self.maxRows=viewport.Y<500 and 2 or #self.rows
    local width=narrow and 160 or 220
    self.panel.Position=UDim2.new(1,-12,0,narrow and 168 or 56)
    self.panel.Size=UDim2.fromOffset(width,38+self.maxRows*40)
    for i,entry in ipairs(self.rows) do
        entry.row.Visible=i<=self.maxRows
        entry.row.Position=UDim2.fromOffset(8,32+(i-1)*40)
        entry.row.Size=UDim2.new(1,-16,0,38)
        entry.bar.Size=UDim2.new(1,-28,0,32)
        entry.avatar.Size=UDim2.fromOffset(30,30)
        entry.avatar.Position=UDim2.fromOffset(1,4)
        entry.name.Visible=not narrow
        entry.name.Size=UDim2.new(1,-70,1,0)
        entry.percent.TextSize=narrow and 12 or 13
        entry.rank.Position=UDim2.fromOffset(0,24)
        entry.crown.Visible=false
    end
end

function Leaderboard:Update(ordered,leader,world)
    local total=world.grid.playableTotal
    for n,view in ipairs(self.rows) do
        local entity=ordered[n]
        view.row.Visible=entity~=nil and n<=(self.maxRows or #self.rows)
        if entity then
            local count=world.grid.counts[entity.id] or 0
            view.percent.Text=string.format("%.2f%%",count/math.max(1,total)*100)
            view.name.Text=entity.name
            view.bar.BackgroundColor3=entity==leader and Color3.fromRGB(39,78,76) or Color3.fromRGB(31,48,69)
            view.rank.BackgroundColor3=entity==leader and Color3.fromRGB(82,230,186) or WHITE
            view.crown.Visible=false
            local id=entity.isHuman and Players.LocalPlayer.UserId or entity.robloxUserId
            if id~=view.userId then
                view.userId=id
                view.avatar.Image=""
                view.fallback.Visible=true
            end
            local url=self.thumbnails:Get(id)
            if url and view.avatar.Image~=url then
                view.avatar.Image=url
                view.fallback.Visible=false
            elseif not url then
                view.fallback.Text=string.sub(entity.name or "?",1,1):upper()
            end
        end
    end
end

function Leaderboard:Destroy()
    self.thumbnails:Destroy()
    self.panel:Destroy()
end

return Leaderboard
