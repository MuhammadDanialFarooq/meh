-- Roblox's built-in Montserrat family; no uploaded font or permission required.
-- https://create.roblox.com/docs/reference/engine/datatypes/Font
local FAMILY = "rbxasset://fonts/families/Montserrat.json"
return {
    Bold = Font.new(FAMILY, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
    Regular = Font.new(FAMILY, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
}
