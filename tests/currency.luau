do
local Currency=loadModule("CurrencyService")
local cfg=table.clone(loadModule("Config"))
local now,roll=1000,.5
local player={UserId=777}
local messages={}
local function notify(_,data) messages[#messages+1]=table.clone(data) end
local function dependencies(extra)
    local d={studio=true,now=function() return now end,rng={NextNumber=function() return roll end},
        spawn=function(f) f() end,wait=function() end}
    for k,v in pairs(extra or {}) do d[k]=v end
    return d
end
local wallet=Currency.new(cfg,notify,dependencies())
wallet:Add(player)
assert(messages[#messages].loaded and not messages[#messages].persistent,"Studio must use temporary balances")
wallet:Capture(player,0,1000);assert(wallet.entries[player].coins==0,"Zero capture awarded coins")
wallet:Capture(player,5,1000)
assert(wallet.entries[player].coins==10,"0.5 point capture must give 5 + 5 coins")
wallet:Kill(player);assert(wallet.entries[player].coins==35,"Kill must give 25 coins")
roll=0
wallet:Capture(player,1,1000);assert(wallet.entries[player].gems==0,"Tiny capture rolled a gem")
wallet:Capture(player,5,1000);assert(wallet.entries[player].gems==1,"Eligible capture failed rare drop")
wallet:Kill(player);assert(wallet.entries[player].gems==1,"Gem cooldown bypassed by switching reward type")
now+=60;wallet:Kill(player);assert(wallet.entries[player].gems==2,"Gem cooldown didn't expire")
wallet:Grant(player,-10,0/0);assert(wallet.entries[player].gems==2,"Invalid amount corrupted balance")
wallet:Remove(player);assert(wallet.entries[player]==nil,"Temporary wallet leaked after departure")

local function clone(t)
    if type(t)~="table" then return t end
    local copy={};for k,v in pairs(t) do copy[k]=clone(v) end;return copy
end
local store={data={u_777={coins=100,gems=3,sessions={}}},fail=false,ambiguous=false}
function store:UpdateAsync(key,transform)
    if self.fail then error("test DataStore unavailable") end
    local new=transform(clone(self.data[key]));self.data[key]=clone(new)
    if self.during then local f=self.during;self.during=nil;f() end
    if self.ambiguous then self.ambiguous=false;error("test response lost after commit") end
    return clone(new)
end
local function persistent(id)
    return Currency.new(cfg,notify,dependencies({studio=false,store=store,session=id}))
end
local a=persistent("a");a:Add(player)
assert(a.entries[player].coins==100 and a.entries[player].gems==3,"Saved wallet did not load")
a:Grant(player,25,1);store.ambiguous=true;assert(a:Save(player))
assert(store.data.u_777.coins==125 and store.data.u_777.gems==4,"Ambiguous commit duplicated reward")
a:Save(player);assert(store.data.u_777.coins==125,"Repeated save duplicated reward")
local b=persistent("b");b:Add(player)
a:Grant(player,5,0);b:Grant(player,10,0)
a:Save(player);b:Save(player)
assert(store.data.u_777.coins==140,"Concurrent sessions lost additive rewards")
store.during=function() a:Grant(player,7,0) end
a:Save(player)
assert(a.entries[player].coins==147 and store.data.u_777.coins==140,"Reward earned during save was lost or pre-saved")
a:Save(player);assert(store.data.u_777.coins==147,"Buffered reward failed to save")
store.fail=true
local c=persistent("c");c:Add(player);c:Grant(player,9,0)
assert(not c.entries[player].loaded and c.entries[player].failed,"Failed load falsely became an empty loaded wallet")
assert(store.data.u_777.coins==147,"Load failure overwrote saved balance")
store.fail=false;assert(c:Save(player))
assert(c.entries[player].coins==156 and c.entries[player].loaded,"Retry failed to merge buffered rewards with saved balance")
store.fail=true;c:Remove(player)
assert(c.entries[player] and not c.entries[player].active,"Failed departure save wasn't retained for retry")
store.fail=false;c:Update(60)
assert(c.entries[player]==nil and store.data.u_777.coins==156,"Departure retry duplicated or lost coins")
local returning={UserId=player.UserId}
c:Add(returning);c:Grant(returning,6,0);c:Save(returning)
assert(store.data.u_777.coins==162,"Rejoining same server reused old receipt and lost new rewards")
roll=0;c:Kill(returning);c:Save(returning)
local gemsBefore=store.data.u_777.gems
c:Remove(returning);local again={UserId=player.UserId};c:Add(again);c:Kill(again);c:Save(again)
assert(store.data.u_777.gems==gemsBefore,"Rejoining bypassed persisted Gem cooldown")
a:Shutdown();b:Shutdown()
print("[Paintland V42 TEST PASS] Currency: capture/kill rates, rare drops/cooldown, invalid amounts, save retries, concurrent sessions, loading and departure recovery")
end
