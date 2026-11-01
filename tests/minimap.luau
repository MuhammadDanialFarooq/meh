local Minimap=loadModule("MinimapController")
local Grid=loadModule("Grid")
local cfg=table.clone(loadModule("Config"))
for _,side in ipairs({108,142}) do
    local g=Grid.new(cfg)
    for i=1,g.total do
        if g.mask[i] then g:Set(i,(i%3)+1) end
    end
    local m=setmetatable({cfg=cfg,side=side,chunksWide=4,chunkPools={},areas={},
        world={grid=g,entities={{color=cfg.Colors[1]},{color=cfg.Colors[2]},{color=cfg.Colors[3]}}}},Minimap)
    local pixels={}
    for id=1,16 do
        m:RebuildChunk(id)
        for _,rect in ipairs(m.chunkPools[id]) do
            if rect.Visible then
                local x,y,w,h=rect.Position.X,rect.Position.Y,rect.Size.X,rect.Size.Y
                assert(x%1==0 and y%1==0 and w%1==0 and h%1==0,"Fractional minimap rectangle")
                for py=y,y+h-1 do for px=x,x+w-1 do
                    assert(px>=0 and py>=0 and px<side and py<side,"Minimap exceeded bounds")
                    local index=py*side+px
                    assert(not pixels[index],"Minimap rectangles overlap")
                    pixels[index]=rect.BackgroundColor3
                end end
            end
        end
    end
    -- Independently rasterize each grid cell using the shared integer boundary rule.
    for y=1,cfg.Grid do for x=1,cfg.Grid do
        local owner=g.owners[(y-1)*cfg.Grid+x]
        if owner>0 then
            for py=math.floor((y-1)*side/cfg.Grid+.5),math.floor(y*side/cfg.Grid+.5)-1 do
                for px=math.floor((x-1)*side/cfg.Grid+.5),math.floor(x*side/cfg.Grid+.5)-1 do
                    assert(pixels[py*side+px]==cfg.Colors[owner],"Minimap seam or wrong owner")
                end
            end
        end
    end end
end
print("[Paintland V27 TEST PASS] Minimap integer coverage, bounds and no overlap at 108/142px")
-- Coalesce dirty cells, then retain updates that arrive after a partial drain.
local m=setmetatable({cfg=cfg,chunksWide=4,dirty={},queue={},head=1,elapsed=0,world={},
    RebuildChunk=function(self,id) self.built[id]=(self.built[id] or 0)+1 end,built={}},Minimap)
for id=1,16 do m:MarkChunk(id); m:MarkChunk(id) end
assert(#m.queue==16,"Duplicate chunk work was queued")
m:Render(0,Vector2.zero)
m:MarkChunk(1)
m:Render(0,Vector2.zero)
m:Render(0,Vector2.zero)
assert(m.built[1]==2 and #m.queue==0 and m.head==1,"Partial dirty drain lost an update")
for id=2,16 do assert(m.built[id]==1,"Dirty chunk was missed") end
print("[Paintland V27 TEST PASS] Minimap dirty queue batching and re-dirty updates")
