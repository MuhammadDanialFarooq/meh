-- Public queue and private room controls. All membership is decided by the server.
local Fonts=require(script.Parent.Fonts)
local ButtonEffects=require(script.Parent.ButtonEffects)
local Players=game:GetService("Players")
local UI={};UI.__index=UI
local INK=Color3.fromRGB(35,32,71)
local function make(parent,class,name,p)
    local o=Instance.new(class);o.Name=name;for k,v in pairs(p) do o[k]=v end;o.Parent=parent;return o
end
local function text(parent,name,value,size,y,height)
    return make(parent,"TextLabel",name,{Text=value,TextSize=size,FontFace=Fonts.Bold,TextColor3=INK,
        Position=UDim2.fromOffset(16,y),Size=UDim2.new(1,-32,0,height),BackgroundTransparency=1,
        TextWrapped=true,ZIndex=113})
end
local function rounded(o,r)
    make(o,"UICorner","Round",{CornerRadius=UDim.new(0,r)})
    make(o,"UIStroke","Outline",{Thickness=2,Color=INK,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
function UI.new(screen,cfg,onCommand)
    local self=setmetatable({cfg=cfg,onCommand=onCommand,room=nil},UI)
    self.root=make(screen,"Frame","Matchmaking",{Size=UDim2.fromScale(1,1),BackgroundColor3=INK,
        BackgroundTransparency=.22,BorderSizePixel=0,Active=true,Visible=false,ZIndex=110})
    self.panel=make(self.root,"Frame","RoomPanel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(440,430),BackgroundColor3=Color3.fromRGB(255,248,225),BorderSizePixel=0,ZIndex=111})
    rounded(self.panel,22)
    self.title=text(self.panel,"Title","JOIN A ROOM",25,14,42)
    self.description=text(self.panel,"Description","Enter a friend's room code.",13,58,38)
    self.code=make(self.panel,"TextBox","RoomCode",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,124),
        Size=UDim2.new(1,-32,0,48),Text="",PlaceholderText="ROOM CODE",ClearTextOnFocus=false,
        FontFace=Fonts.Bold,TextSize=23,TextColor3=INK,BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=113})
    rounded(self.code,10)
    self.roster=text(self.panel,"Roster","",14,154,98);self.roster.FontFace=Fonts.Regular
    self.status=text(self.panel,"Status","",12,256,34);self.status.FontFace=Fonts.Regular
    local function button(name,label,y,color,action)
        local b=make(self.panel,"TextButton",name,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,y),
            Size=UDim2.new(1,-32,0,48),Text=label,FontFace=Fonts.Bold,TextSize=18,TextColor3=INK,
            BackgroundColor3=color,BorderSizePixel=0,ZIndex=114,Active=true,AutoButtonColor=false})
        rounded(b,12);ButtonEffects.Bind(b,cfg,{play=name=="Primary"})
        b.Activated:Connect(function() if self.root.Visible and b.Active then action() end end)
        return b
    end
    self.primary=button("Primary","JOIN",324,Color3.fromRGB(154,242,107),function()
        if self.room then self.onCommand("start",{})
        else
            local code=self.code.Text:gsub("%s+",""):upper()
            if #code<4 or #code>12 or not code:match("^[A-Z0-9]+$") then self:SetStatus("Enter the room code shown by the host.");return end
            self:SetStatus("Joining room...");self.onCommand("join",{code=code})
        end
    end)
    self.back=button("Back","BACK",382,Color3.fromRGB(212,231,255),function()
        self.onCommand("leave",{});self:Hide()
    end)
    self.resize=self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Resize(self.root.AbsoluteSize)
    end)
    self:Resize(screen.AbsoluteSize or Vector2.new(1280,720))
    return self
end
function UI:Show(room)
    self.room=room;self.root.Visible=true;self.status.Text=""
    self.code.Visible=room==nil
    self.title.Text=room and (room.private and "PRIVATE ROOM" or "QUICK PLAY") or "JOIN A ROOM"
    self.description.Text=room and (room.private and ("ROOM CODE: "..room.code) or "Finding players for your arena...") or "Enter a friend's room code."
    local names={}
    for _,p in ipairs(room and room.players or {}) do names[#names+1]=p.name..(p.userId==room.hostId and "  / HOST" or "") end
    self.roster.Text=room and string.format("%d / %d PLAYERS\n%s",#names,room.capacity,table.concat(names,"  ·  ")) or "Private rooms keep your match together."
    local host=room and room.hostId==Players.LocalPlayer.UserId
    self.primary.Visible=room==nil or room.private==true
    self.primary.Active=room==nil or host
    self.primary.Text=room==nil and "JOIN ROOM" or (host and "START MATCH" or "WAITING FOR HOST")
    self.back.Text=room and "LEAVE ROOM" or "BACK"
    if self.viewport then self:Resize(self.viewport) end
end
function UI:SetStatus(message) self.status.Text=tostring(message) end
function UI:Hide() self.root.Visible=false end
function UI:Resize(size)
    if not size or size.X<1 or size.Y<1 then return end
    self.viewport=size
    local width=math.min(440,size.X-24);local compact=size.Y<470
    local height=compact and math.min(290,size.Y-24) or 418
    self.panel.Size=UDim2.fromOffset(width,height)
    self.title.Position=UDim2.fromOffset(16,compact and 4 or 14)
    self.description.Position=UDim2.fromOffset(16,compact and 42 or 58)
    self.code.Position=UDim2.new(.5,0,0,compact and 102 or 124)
    self.roster.Position=UDim2.fromOffset(16,compact and 82 or 154)
    self.roster.Size=UDim2.new(1,-32,0,compact and 50 or 98)
    -- Join form and lobby roster occupy the same row; only one is needed.
    self.roster.Visible=not compact or self.room~=nil
    self.status.Position=UDim2.fromOffset(16,compact and 134 or 256)
    self.primary.Position=UDim2.new(.5,0,0,height-84)
    self.back.Position=UDim2.new(.5,0,0,height-28)
end
function UI:Destroy() if self.resize then self.resize:Disconnect() end;self.root:Destroy() end
return UI
