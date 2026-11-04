-- Shared descriptions; ownership, prices and spending are validated by the server.
local Abilities=require(script.Parent.AbilityRegistry)
local Catalog={}
Catalog.Characters={
    {Id="Slime",Name="SLIME",Ability="",Hat="None",Description="Your classic painter"},
    {Id="Runner",Name="RUNNER",Ability="Dash",Hat="Cap",Description="Includes Dash while equipped"},
    {Id="Splashling",Name="SPLASHLING",Ability="Splash",Hat="Crown",Description="Includes Splash while equipped"},
}
Catalog.ByCharacter={}
for _,c in ipairs(Catalog.Characters) do Catalog.ByCharacter[c.Id]=c end
function Catalog.CanEquip(inventory,id)
    if id=="" then return true end
    if not Abilities.ById[id] then return false end
    local character=Catalog.ByCharacter[inventory.character]
    return inventory.abilities[id]==true or (character and inventory.characters[character.Id]==true and character.Ability==id) or false
end
function Catalog.Normalize(value)
    value=type(value)=="table" and value or {}
    local result={abilities={},characters={Slime=true},character="Slime",equipped=""}
    for id,owned in pairs(type(value.abilities)=="table" and value.abilities or {}) do
        if owned==true and Abilities.ById[id] then result.abilities[id]=true end
    end
    for id,owned in pairs(type(value.characters)=="table" and value.characters or {}) do
        if owned==true and Catalog.ByCharacter[id] then result.characters[id]=true end
    end
    if type(value.character)=="string" and result.characters[value.character] then result.character=value.character end
    if type(value.equipped)=="string" and Catalog.CanEquip(result,value.equipped) then result.equipped=value.equipped end
    return result
end
function Catalog.Price(cfg,kind,id)
    if kind=="character" and id=="Slime" then return "coins",0 end
    local prices=kind=="character" and cfg.CharacterPrices or cfg.AbilityPrices
    local price=prices and prices[id]
    if type(price)~="table" then return nil end
    local currency=price.Gems and "gems" or "coins"
    local cost=price.Gems or price.Coins
    if type(cost)~="number" or cost~=cost or cost<1 or cost>100000000 then return nil end
    return currency,math.floor(cost)
end
-- Atomic with wallet deduction. Ownership is the receipt for lost-response retries.
function Catalog.Apply(data,operation,cfg)
    local inv=data.inventory
    local action,id=operation.action,operation.id
    if action=="unequip" then inv.equipped="";return true,"Ability unequipped" end
    local character=action=="buyCharacter" or action=="equipCharacter"
    local buying=action=="buyCharacter" or action=="buyAbility"
    if not character and action~="buyAbility" and action~="equipAbility" then return false,"Unknown loadout action" end
    local product=character and Catalog.ByCharacter[id] or (not character and Abilities.ById[id])
    if not product then return false,"Unknown item" end
    local owned=character and inv.characters or inv.abilities
    local accessible=character and owned[id]==true or (not character and Catalog.CanEquip(inv,id))
    if not accessible then
        if not buying then return false,"Unlock this item first" end
        local currency,cost=Catalog.Price(cfg,character and "character" or "ability",id)
        if not currency then return false,"Item is not for sale" end
        if data[currency]<cost then return false,"Need "..cost.." "..currency end
        data[currency]-=cost;owned[id]=true
    end
    if character then
        inv.character=id
        inv.equipped=product.Ability~="" and product.Ability or (inv.abilities[inv.equipped] and inv.equipped or "")
    else inv.equipped=id end
    return true,"Equipped "..product.Name
end
return Catalog
