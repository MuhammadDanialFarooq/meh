-- Compress rectangular runs of same-owner cells; used by arena and minimap.
local Geometry = {}

function Geometry.Rectangles(grid, cfg, chunkId, chunksWide)
    local n = cfg.Grid
    local zero = chunkId - 1
    local cx, cy = zero % chunksWide, math.floor(zero / chunksWide)
    local x1 = cx * cfg.Chunk + 1
    local y1 = cy * cfg.Chunk + 1
    local x2 = math.min(n, x1 + cfg.Chunk - 1)
    local y2 = math.min(n, y1 + cfg.Chunk - 1)
    local active, rectangles = {}, {}
    for y = y1, y2 do
        local nextActive = {}
        local x = x1
        while x <= x2 do
            local owner = grid.owners[(y - 1) * n + x]
            if owner and owner > 0 then
                local startX = x
                repeat
                    x += 1
                until x > x2 or grid.owners[(y - 1) * n + x] ~= owner
                local key = owner .. ":" .. startX .. ":" .. (x - 1)
                local rect = active[key]
                if not rect then
                    rect = {x1 = startX, x2 = x - 1, y1 = y, y2 = y, owner = owner}
                    rectangles[#rectangles + 1] = rect
                else
                    rect.y2 = y
                end
                nextActive[key] = rect
            else
                x += 1
            end
        end
        active = nextActive
    end
    return rectangles
end


-- Pack an arbitrary set of grid indices into vertically merged rectangles.
-- Used for animated death absorptions. No one-Frame-per-cell allocations.
function Geometry.RectanglesFromSet(cells, n)
    if not cells or not next(cells) then return {} end
    local active, result = {}, {}
    for y = 1, n do
        local following = {}
        local x = 1
        while x <= n do
            local index = (y - 1) * n + x
            if cells[index] then
                local firstX = x
                repeat
                    x += 1
                until x > n or not cells[(y - 1) * n + x]
                local key = firstX .. ':' .. (x - 1)
                local rect = active[key]
                if rect then
                    rect.y2 = y
                else
                    rect = {x1 = firstX, x2 = x - 1, y1 = y, y2 = y}
                    result[#result + 1] = rect
                end
                following[key] = rect
            else
                x += 1
            end
        end
        active = following
    end
    return result
end

return Geometry
