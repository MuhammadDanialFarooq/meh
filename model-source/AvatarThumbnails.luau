-- Lazy, cached avatar thumbnails for real Roblox UserIds.
-- Fake/offline AI identities get a fallback icon, not an invented face.
local Players = game:GetService("Players")
local Avatars = {}
Avatars.__index = Avatars

function Avatars.new()
    return setmetatable({cache={}, pending={}, failures={}}, Avatars)
end

function Avatars:Get(userId)
    if type(userId) ~= "number" or userId <= 0 then return nil end
    userId = math.floor(userId)
    if self.cache[userId] then return self.cache[userId] end
    if self.pending[userId] or self.failures[userId] then return nil end

    self.pending[userId] = true
    task.spawn(function()
        local ok, url, ready = pcall(function()
            return Players:GetUserThumbnailAsync(
                userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150
            )
        end)
        self.pending[userId] = nil
        if ok and type(url) == "string" and url ~= "" then
            self.cache[userId] = url
        else
            self.failures[userId] = true
            warn("[Paintland] Avatar thumbnail unavailable for UserId", userId)
        end
    end)
    return nil
end

function Avatars:Destroy()
    table.clear(self.pending)
    table.clear(self.cache)
end

return Avatars
