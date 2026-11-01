-- Resolves real, public Roblox display names for local AI opponents.
-- No off-platform HTTP APIs or server script are required.
-- Lookup is asynchronous, so a slow Roblox response never freezes the game.
local UserService = game:GetService("UserService")
local Players = game:GetService("Players")

local NameService = {}
NameService.__index = NameService

function NameService.new(cfg)
    return setmetatable({
        cfg = cfg,
        rng = Random.new(),
        verified = {},
        knownIds = {},
        loading = false,
        finished = false,
        currentWorld = nil,
    }, NameService)
end

local function cleanName(info)
    if type(info) ~= "table" then return nil end
    if type(info.Id) ~= "number" or type(info.Username) ~= "string" then return nil end
    local displayName = info.DisplayName
    if type(displayName) ~= "string" or displayName == "" then
        displayName = info.Username
    end
    if displayName == "" or info.Username == "" then return nil end
    return {
        id = info.Id,
        username = info.Username,
        displayName = displayName,
    }
end

function NameService:Apply(world)
    if self.currentWorld ~= world then return end

    -- Don't change an already-selected identity each time another lookup finishes.
    local candidates = table.clone(self.verified)
    for i = #candidates, 2, -1 do
        local j = self.rng:NextInteger(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local usedNames, usedIds = {}, {}
    local human = world.entities[1]
    if human then usedNames[string.lower(human.name)] = true end
    if Players.LocalPlayer then usedNames[string.lower(Players.LocalPlayer.Name)] = true end

    for _, e in ipairs(world.entities) do
        if not e.isHuman and e.robloxUserId then
            usedIds[e.robloxUserId] = true
            usedNames[string.lower(e.name)] = true
        end
    end

    for _, entity in ipairs(world.entities) do
        if not entity.isHuman and not entity.robloxUserId then
            local selected
            for _, candidate in ipairs(candidates) do
                if not usedIds[candidate.id] then
                    local display = candidate.displayName
                    if usedNames[string.lower(display)] then
                        display = candidate.username
                    end
                    if not usedNames[string.lower(display)] then
                        selected = candidate
                        entity.name = display
                        break
                    end
                end
            end
            if selected then
                entity.robloxUserId = selected.id
                entity.robloxUsername = selected.username
                usedIds[selected.id] = true
                usedNames[string.lower(entity.name)] = true
            end
        end
    end
end

function NameService:Assign(world)
    self.currentWorld = world
    self:Apply(world)
    if self.loading or self.finished then return end
    self.loading = true

    task.spawn(function()
        local needed = self.cfg.BotCount
        local attempts = self.cfg.NameLookupAttempts or 3
        local batchSize = self.cfg.NameLookupBatchSize or 44
        local minId = self.cfg.RandomUserIdMin or 10000000
        local maxId = self.cfg.RandomUserIdMax or 2000000000
        local myId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

        for attempt = 1, attempts do
            if #self.verified >= needed * 2 then break end

            local ids = {}
            for _ = 1, batchSize do
                local id = self.rng:NextInteger(minId, maxId)
                if id ~= myId and not self.knownIds[id] then
                    self.knownIds[id] = true
                    ids[#ids + 1] = id
                end
            end

            if #ids > 0 then
                local ok, results = pcall(function()
                    return UserService:GetUserInfosByUserIdsAsync(ids)
                end)
                if ok and type(results) == "table" then
                    for _, info in ipairs(results) do
                        local account = cleanName(info)
                        if account and account.id ~= myId then
                            self.verified[#self.verified + 1] = account
                        end
                    end
                    -- Refresh the current world's names, including live HUD labels.
                    if self.currentWorld then self:Apply(self.currentWorld) end
                else
                    warn("[Paintland] Roblox username lookup failed; using offline names", results)
                end
            end
            if attempt < attempts then task.wait(1.5) end
        end

        self.loading = false
        self.finished = true
        if self.currentWorld then self:Apply(self.currentWorld) end
    end)
end

return NameService
