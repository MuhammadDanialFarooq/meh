-- Server wallet. Clients cannot submit amounts or roll rewards.
-- Cumulative session receipts make retries and concurrent additive saves idempotent.
local Currency={};Currency.__index=Currency
local LIMIT=2147483647
local function amount(n)
    if type(n)~="number" or n~=n or n==math.huge or n==-math.huge then return 0 end
    return math.clamp(math.floor(n),0,LIMIT)
end
local function record(old)
    old=type(old)=="table" and old or {}
    return {version=1,coins=amount(old.coins),gems=amount(old.gems),lastGem=amount(old.lastGem),
        sessions=type(old.sessions)=="table" and table.clone(old.sessions) or {}}
end
function Currency.new(cfg,notify,deps)
    deps=deps or {}
    local store=deps.store
    local studio=deps.studio
    if studio==nil then studio=game:GetService("RunService"):IsStudio() end
    local persistent=cfg.CurrencyPersistenceEnabled~=false and (not studio or cfg.CurrencyPersistInStudio==true)
    if persistent and not store then store=game:GetService("DataStoreService"):GetDataStore(cfg.CurrencyDataStoreName or "PaintlandWalletV1") end
    local self=setmetatable({cfg=cfg,notify=notify,store=persistent and store or nil,entries={},timer=0,joinSerial=0,
        rng=deps.rng or Random.new(),spawn=deps.spawn or task.spawn,wait=deps.wait or task.wait,
        now=deps.now or os.time,session=deps.session or (persistent and game:GetService("HttpService"):GenerateGUID(false) or "studio")},Currency)
    return self
end
function Currency:Publish(player,reward)
    local e=self.entries[player];if not e then return end
    self.notify(player,{kind="wallet",coins=e.coins,gems=e.gems,loaded=e.loaded,
        persistent=self.store~=nil,saving=e.failed==true,deltaCoins=reward and reward.coins or 0,
        deltaGems=reward and reward.gems or 0,reason=reward and reward.reason or nil})
end
function Currency:Add(player)
    if self.entries[player] then return end
    self.joinSerial+=1
    local e={coins=0,gems=0,earnedCoins=0,earnedGems=0,savedCoins=0,savedGems=0,
        loaded=not self.store,failed=false,busy=false,lastGem=-math.huge,active=true,
        session=self.session..":"..self.joinSerial}
    self.entries[player]=e;self:Publish(player)
    if self.store then self.spawn(function() self:Save(player) end) end
end
function Currency:Grant(player,coins,gems,reason)
    local e=self.entries[player]
    if not e or not e.active then return end
    coins=math.min(amount(coins),LIMIT-e.earnedCoins);gems=math.min(amount(gems),LIMIT-e.earnedGems)
    e.earnedCoins+=coins;e.earnedGems+=gems
    e.coins=math.min(LIMIT,e.coins+coins);e.gems=math.min(LIMIT,e.gems+gems)
    if not self.store then e.savedCoins=e.earnedCoins;e.savedGems=e.earnedGems end
    self:Publish(player,{coins=coins,gems=gems,reason=reason})
end
function Currency:Gem(player,chance)
    local e=self.entries[player]
    if not e or not e.active or not e.loaded or self.now()-e.lastGem<math.max(0,self.cfg.CurrencyGemCooldownSeconds or 60) then return 0 end
    if self.rng:NextNumber()<math.clamp(chance or 0,0,1) then e.lastGem=self.now();return 1 end
    return 0
end
function Currency:Capture(player,count,total)
    if type(count)~="number" or count~=count or count<=0 or count==math.huge or not total or total<=0 then return end
    local points=math.min(100,count/total*100)
    local coins=amount(self.cfg.CurrencyCaptureBaseCoins or 5)+amount(points*(self.cfg.CurrencyCoinsPerPercent or 10))
    local gems=points>=(self.cfg.CurrencyGemMinCapturePercent or .5) and self:Gem(player,self.cfg.CurrencyCaptureGemChance or .01) or 0
    self:Grant(player,coins,gems,"capture")
end
function Currency:Kill(player)
    self:Grant(player,self.cfg.CurrencyKillCoins or 25,self:Gem(player,self.cfg.CurrencyKillGemChance or .05),"kill")
end
function Currency:Save(player)
    local e=self.entries[player];if not e then return true end
    if not self.store then return true end
    if e.busy then return false end
    e.busy=true
    local coins,gems=e.earnedCoins,e.earnedGems
    local session,lastGem=e.session,e.lastGem
    local timestamp=self.now();local result,ok
    for attempt=1,3 do
        ok,result=pcall(function()
            return self.store:UpdateAsync("u_"..player.UserId,function(old)
                local data=record(old)
                local prior=data.sessions[session]
                local oldCoins=type(prior)=="table" and amount(prior.coins) or 0
                local oldGems=type(prior)=="table" and amount(prior.gems) or 0
                data.coins=math.min(LIMIT,data.coins+math.max(0,coins-oldCoins))
                data.gems=math.min(LIMIT,data.gems+math.max(0,gems-oldGems))
                data.lastGem=math.max(data.lastGem,lastGem)
                data.sessions[session]={coins=math.max(coins,oldCoins),gems=math.max(gems,oldGems),time=timestamp}
                -- Active sessions refresh every minute. Only long-expired receipts are pruned.
                for key,receipt in pairs(data.sessions) do
                    if key~=session and type(receipt)=="table" and type(receipt.time)=="number"
                        and timestamp-receipt.time>30*86400 then data.sessions[key]=nil end
                end
                return data
            end)
        end)
        if ok and type(result)=="table" then break end
        ok=false
        if attempt<3 then self.wait(attempt) end
    end
    e.busy=false;e.failed=not ok
    if ok then
        e.loaded=true;e.savedCoins=coins;e.savedGems=gems
        e.lastGem=math.max(e.lastGem,amount(result.lastGem))
        e.coins=math.min(LIMIT,amount(result.coins)+e.earnedCoins-coins)
        e.gems=math.min(LIMIT,amount(result.gems)+e.earnedGems-gems)
    end
    self:Publish(player)
    return ok
end
function Currency:Flush(player)
    local e=self.entries[player];if not e then return true end
    local started=os.clock()
    while e.busy and os.clock()-started<12 do self.wait(.1) end
    if e.busy then return false end
    return self:Save(player)
end
function Currency:Remove(player)
    local e=self.entries[player];if not e then return end
    e.active=false
    if not self.store then self.entries[player]=nil;return end
    self.spawn(function()
        local ok=self:Flush(player)
        if ok then self.entries[player]=nil
        else warn("[Paintland Currency] Save pending for user "..tostring(player.UserId)) end
    end)
end
function Currency:Update(dt)
    if not self.store then return end
    self.timer+=math.max(0,dt)
    if self.timer<math.max(15,self.cfg.CurrencyAutosaveSeconds or 60) then return end
    self.timer=0
    for player,e in pairs(self.entries) do
        if not e.busy then
            self.spawn(function()
                if self:Save(player) and not e.active then self.entries[player]=nil end
            end)
        end
    end
end
function Currency:Shutdown()
    if not self.store then table.clear(self.entries);return end
    local pending=0
    for player,e in pairs(self.entries) do
        e.active=false;pending+=1
        self.spawn(function() self:Flush(player);pending-=1 end)
    end
    local started=os.clock()
    while pending>0 and os.clock()-started<25 do self.wait(.1) end
end
return Currency
