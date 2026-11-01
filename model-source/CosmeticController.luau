-- Public, runtime cosmetic API for your own skin shop / game passes.
-- CosmeticController.Equip(1, {Hat = "Crown", FaceImageId = 12345})
-- Uses local Workspace models; never trusts this table for paid ownership.
local Cosmetics = {}
local renderer = nil
local pending = {}

function Cosmetics.Bind(activeRenderer)
    renderer = activeRenderer
    for id, cosmetics in pairs(pending) do renderer:SetCosmetics(id, cosmetics) end
end

function Cosmetics.Equip(entityId, cosmetics)
    assert(type(entityId) == "number", "Entity ID must be a number")
    assert(type(cosmetics) == "table", "Cosmetics must be a table")
    pending[entityId] = cosmetics
    if renderer then renderer:SetCosmetics(entityId, cosmetics) end
end

function Cosmetics.EquipLocal(cosmetics)
    Cosmetics.Equip(1, cosmetics)
end

function Cosmetics.Get(entityId)
    return pending[entityId]
end

return Cosmetics
