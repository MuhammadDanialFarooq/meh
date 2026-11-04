do
local Currency=loadModule("CurrencyService")
local Catalog=loadModule("LoadoutCatalog")
local player={UserId=5001}
local function clone(v) if type(v)~="table" then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local store={data={coins=1000,gems=20}}
function store:UpdateAsync(_,transform)
    if self.fail then error("test outage") end
    self.data=clone(transform(clone(self.data)))
    if self.ambiguous then self.ambiguous=false;error("test committed then lost response") end
    return clone(self.data)
end
local function wallet(session)
    local w=Currency.new(netCfg,function() end,{studio=false,store=store,session=session,spawn=function(f) f() end,wait=function() end})
    w:Add(player);return w
end
local a=wallet("shop_a");local b=wallet("shop_b")
assert(a:Loadout(player).equipped=="","New wallet started with a free standalone ability")
assert(not a:Action(player,"equipAbility","Dash"),"Unowned ability equipped")
store.ambiguous=true
assert(a:Action(player,"buyAbility","Dash"))
assert(store.data.coins==750 and store.data.inventory.abilities.Dash,"Purchase retry duplicated deduction or missed unlock")
assert(a:Action(player,"buyAbility","Dash") and store.data.coins==750,"Repeated purchase double charged")
assert(b:Action(player,"buyAbility","Splash") and store.data.coins==350,"Concurrent purchase used stale wallet")
assert(store.data.inventory.abilities.Dash and store.data.inventory.abilities.Splash,"Concurrent purchase erased ownership")
assert(not a:Action(player,"buyCharacter","Runner") and store.data.coins==350,"Purchase overspent stale balance")
a:Grant(player,10,0);a:Save(player)
assert(store.data.coins==360 and store.data.inventory.abilities.Splash,"Autosave restored spent currency or overwrote inventory")
assert(a:Action(player,"buyCharacter","Splashling") and store.data.gems==12,"Gem character purchase failed")
assert(a:Loadout(player).character=="Splashling" and a:Loadout(player).equipped=="Splash","Character didn't equip included ability")
assert(a:Action(player,"equipAbility","Dash") and a:Loadout(player).equipped=="Dash","Single slot didn't replace equipped ability")
assert(a:Action(player,"unequip","") and a:Loadout(player).equipped=="","Unequip failed")
assert(not a:Action(player,"buyAbility","Fake") and store.data.coins==360,"Unknown product charged")
store.fail=true;assert(not a:Action(player,"equipAbility","Splash"),"Failed save reported successful equip")
store.fail=false
local returning=wallet("shop_rejoin")
assert(returning:Loadout(player).characters.Splashling and returning.entries[player].coins==360,"Saved ownership or balance failed rejoin")
local included=Catalog.Normalize({characters={Runner=true},character="Runner",equipped="Dash"})
assert(Catalog.CanEquip(included,"Dash") and not included.abilities.Dash,"Character ability became a permanent standalone unlock")
local data={coins=0,gems=0,inventory=included}
assert(Catalog.Apply(data,{action="equipCharacter",id="Slime"},netCfg))
assert(data.inventory.equipped=="" and not Catalog.CanEquip(data.inventory,"Dash"),"Character swap retained unauthorized ability")

local sent={}
local menu=loadModule("LoadoutMenu").new(screen,netCfg,function(action,id) sent[#sent+1]={action,id} end)
menu:SetWallet({loaded=true,coins=1000,gems=20,inventory=Catalog.Normalize(nil)});menu:Show()
local dash
for _,row in ipairs(menu.rows) do if row.kind=="ability" and row.product.Id=="Dash" then dash=row end end
assert(dash and dash.button.Text=="BUY 250 COINS","Purchase price hidden or incorrect")
dash.button.Activated:Fire();dash.button.Activated:Fire()
assert(#sent==1 and sent[1][1]=="buyAbility","Pending purchase repeated")
menu:SetWallet({loaded=true,coins=750,gems=20,inventory={abilities={Dash=true},equipped="Dash"}})
menu:Result(true,"Equipped DASH");assert(dash.button.Text=="EQUIPPED" and not dash.button.Active,"Confirmed equip not shown")
for _,size in ipairs({{320,568},{375,667},{568,320},{640,360},{1280,720}}) do
    viewport.AbsoluteSize=Vector2.new(size[1],size[2]);menu:Resize(viewport.AbsoluteSize)
    local panel=rect(menu.panel)
    assert(panel[1]>=0 and panel[2]>=0 and panel[1]+panel[3]<=size[1] and panel[2]+panel[4]<=size[2],"Loadout leaves viewport")
    assert(menu.scroll.Size.Y.Offset==-148 and not overlap(rect(menu.close),rect(menu.clear)),"Loadout footer overlaps")
    for _,row in ipairs(menu.rows) do
        assert(row.button.Size.Y.Offset>=44 and row.button.AnchorPoint.X==.5 and row.button.AnchorPoint.Y==.5,"Shop target too small/off-center")
    end
end
menu:Destroy()
print("[Paintland V43 TEST PASS] Atomic Coin/Gem purchases, retry/concurrent saves, ownership persistence, character entitlements, one-slot shop and mobile layout")
end
