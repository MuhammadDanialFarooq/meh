-- Server-only room registry. Quick Play groups players in this Roblox server;
-- directory entries let private codes route friends to the correct running server.
local MemoryStoreService=game:GetService("MemoryStoreService")
local RunService=game:GetService("RunService")
local Matchmaking={}
Matchmaking.__index=Matchmaking
local LETTERS="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
function Matchmaking.new(cfg)
    return setmetatable({cfg=cfg,rooms={},byPlayer={},nextRoom=0,rng=Random.new(),
        directory=not RunService:IsStudio() and MemoryStoreService:GetHashMap("PaintlandPrivateRoomsV1") or nil,
        publicDirectory=not RunService:IsStudio() and MemoryStoreService:GetSortedMap("PaintlandPublicServersV1") or nil},Matchmaking)
end
function Matchmaking:Code()
    local code=""
    for _=1,7 do local n=self.rng:NextInteger(1,#LETTERS);code..=LETTERS:sub(n,n) end
    return code
end
function Matchmaking:Create(private,hostId)
    self.nextRoom+=1
    local room={id=tostring(self.nextRoom),private=private,hostId=hostId,players={},count=0,
        capacity=math.clamp(self.cfg.MultiplayerMaxPlayers or 8,2,16),state="lobby",created=os.clock()}
    if private then
        local allocated=false
        for _=1,8 do
            room.code=self:Code()
            if not self.rooms[room.code] then
                if self.directory then
                    local ok,value=pcall(function()
                        return self.directory:UpdateAsync(room.code,function(old)
                            if old then return old end
                            return {jobId=game.JobId,placeId=game.PlaceId,hostId=hostId}
                        end,120)
                    end)
                    if not ok then return nil,"Private room directory unavailable; try again." end
                    allocated=value and value.jobId==game.JobId and value.hostId==hostId
                else allocated=true end
                if allocated then break end
            end
        end
        if not allocated then return nil,"Could not allocate a room code; try again." end
    else room.code="PUBLIC-"..room.id end
    self.rooms[room.code]=room
    return room
end
function Matchmaking:Quick()
    for _,room in pairs(self.rooms) do
        if not room.private and room.count<room.capacity and room.state~="completed" then return room end
    end
    return self:Create(false,0)
end
function Matchmaking:Find(code)
    if type(code)~="string" or #code>16 then return nil,"Invalid room code." end
    code=code:upper():gsub("%s","")
    if not code:match("^[A-Z2-9]+$") or #code~=7 then return nil,"Enter a seven-character room code." end
    local room=self.rooms[code]
    if room then return room end
    if self.directory then
        local ok,destination=pcall(function() return self.directory:GetAsync(code) end)
        if not ok then return nil,"Room lookup unavailable; try again." end
        if destination and destination.jobId~=game.JobId then return nil,nil,destination,code end
    end
    return nil,"Room not found or expired."
end
function Matchmaking:Add(room,player)
    if self.byPlayer[player] or room.count>=room.capacity or room.state=="completed" then return nil end
    local slot
    for i=1,room.capacity do if not room.players[i] then slot=i;break end end
    room.players[slot]=player;room.count+=1;self.byPlayer[player]={room=room,slot=slot}
    if room.hostId==0 then room.hostId=player.UserId end
    return slot
end
function Matchmaking:Remove(player)
    local membership=self.byPlayer[player];if not membership then return end
    local room=membership.room
    room.players[membership.slot]=nil;room.count-=1;self.byPlayer[player]=nil
    if room.hostId==player.UserId then
        room.hostId=0
        for _,other in pairs(room.players) do room.hostId=other.UserId;break end
    end
    if room.count==0 then
        self.rooms[room.code]=nil
        if room.private and self.directory then task.spawn(function() pcall(function() self.directory:RemoveAsync(room.code) end) end) end
    end
    return room,membership.slot
end
function Matchmaking:QuickDestination()
    if not self.publicDirectory then return nil end
    local ok,entries=pcall(function() return self.publicDirectory:GetRangeAsync(Enum.SortDirection.Descending,20) end)
    if not ok then return nil end
    for _,entry in ipairs(entries) do
        local value=entry.value
        if value and value.jobId~=game.JobId and value.free>0 and value.placeId==game.PlaceId then return value end
    end
end
function Matchmaking:Refresh()
    if self.publicDirectory then
        local free,active=0,0
        for _,room in pairs(self.rooms) do
            if not room.private and room.state~="completed" then free+=room.capacity-room.count;active+=room.count end
        end
        if active>0 and free>0 then
            pcall(function() self.publicDirectory:SetAsync(game.JobId,{jobId=game.JobId,placeId=game.PlaceId,free=free},90,active) end)
        else pcall(function() self.publicDirectory:RemoveAsync(game.JobId) end) end
    end
    if not self.directory then return end
    for _,room in pairs(self.rooms) do
        if room.private and room.count>0 then
            pcall(function() self.directory:SetAsync(room.code,{jobId=game.JobId,placeId=game.PlaceId,hostId=room.hostId},120) end)
        end
    end
end
return Matchmaking
