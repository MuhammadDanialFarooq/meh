-- Exercise the actual redesigned menu at desktop, portrait and landscape sizes.
-- Rect arithmetic checks layout only; Roblox rendering requires Studio.
local menuCfg=table.clone(loadModule("Config"))
menuCfg.ReducedMotion=false
local chosenSkin
local menuUI=loadModule("UIController").new(renderer,menuCfg,{
    onPlay=function(skin) chosenSkin=skin end})
local menu=menuUI.menu
menuUI:SetWallet({loaded=true,coins=0,gems=0,persistent=false})
for _,decoration in ipairs({menu.root,menu.hero,menu.art,menu.mascot,menu.footer}) do
    assert(decoration.Active==false and decoration.Selectable==false,
        "Decoration captures input or controller focus: "..decoration.Name)
end
local function inside(inner,outer,message)
    assert(inner[1]>=outer[1]-1e-6 and inner[2]>=outer[2]-1e-6
        and inner[1]+inner[3]<=outer[1]+outer[3]+1e-6
        and inner[2]+inner[4]<=outer[2]+outer[4]+1e-6,message)
end
for _,size in ipairs({{320,568},{375,667},{390,844},{568,320},{640,360},{844,390},{900,600},{1280,720},{1920,1080}}) do
    local previousTweens=table.clone(menu.tweens)
    viewport.AbsoluteSize=Vector2.new(size[1],size[2]);menuUI:Resize()
    for _,tween in ipairs(previousTweens) do assert(tween.Cancelled,"Resize retained old animation") end
    assert(#menu.tweens<=#menu.motes,"Resize accumulated animation handles")
    local context=" at "..size[1].."x"..size[2]
    local rootBounds,panelBounds=rect(menu.root),rect(menu.panel)
    inside(rootBounds,{0,0,size[1],size[2]},"Menu leaves viewport"..context)
    inside(panelBounds,rootBounds,"Action panel leaves menu"..context)
    inside(rect(menu.hero),rootBounds,"Brand leaves menu"..context)
    assert(not overlap(rect(menu.hero),panelBounds),"Brand overlaps action panel"..context)
    if menu.footer.Visible then
        inside(rect(menu.footer),{0,0,size[1],size[2]},"Footer leaves viewport"..context)
        assert(not overlap(rect(menu.footer),rect(menuUI.soundButton)),"Sound overlaps footer"..context)
    end
    local controls={menu.play}
    for _,button in ipairs(menu.roomButtons) do table.insert(controls,button) end
    for _,view in ipairs(menu.skins) do table.insert(controls,view.button) end
    for i,button in ipairs(controls) do
        local bounds=rect(button)
        inside(bounds,panelBounds,"Button leaves action panel"..context)
        assert(bounds[3]>=44 and bounds[4]>=44,"Touch target too small"..context)
        assert(button.AnchorPoint.X==.5 and button.AnchorPoint.Y==.5,"Button anchor is not centered")
        for j=i+1,#controls do
            assert(not overlap(bounds,rect(controls[j])),"Menu buttons overlap"..context)
        end
        if menu.help.Visible then assert(not overlap(bounds,rect(menu.help)),"Help overlaps an action"..context) end
    end
    assert(not overlap(rect(menu.play),rect(menuUI.soundButton)),"Sound overlaps Play"..context)
end
menuUI:SetMode("menu")
menuUI.skins[4].button.Activated:Fire()
menuUI.play.Activated:Fire()
assert(menuUI.skin==4 and chosenSkin==4,"Redesigned menu lost selected color on Play")
assert(menu.mascot.BackgroundColor3==menuCfg.Colors[4],"Mascot did not adopt selected color")
assert(menu.colorName.Text=="VIOLET" and menu.colorName.TextColor3==menuCfg.Colors[4],
    "Color name did not match selection")
for _,tile in ipairs(menu.accent) do
    assert(tile.BackgroundColor3==menuCfg.Colors[4],"Illustrated trail retained a stale color")
end
for i,view in ipairs(menuUI.skins) do
    assert(view.button.Text==(i==4 and "✓" or ""),"Color selection marker is stale")
end
menu:Show(false)
menu:Show(true)
local createdBefore=#tweens.created
local entering={}
for _,tween in ipairs(menu.tweens) do table.insert(entering,tween) end
assert(#entering>0,"Menu has no entrance presentation")
menu:Show(true)
assert(#tweens.created==createdBefore,"Repeated Show restarted entrance animation")
menu:Show(false)
for _,tween in ipairs(entering) do assert(tween.Cancelled,"Hidden menu retained an animation") end
menuCfg.ReducedMotion=true
createdBefore=#tweens.created
menu:Show(true)
assert(#tweens.created==createdBefore,"Reduced-motion menu still creates entrance tweens")
menuUI:SetMode("playing")
assert(not menuUI.overlay.Visible,"Menu remains visible during play")
menuUI:SetMode("menu")
assert(menuUI.overlay.Visible and menuUI.skin==4,"Returning to menu lost selection")
menuCfg.ReducedMotion=false
menu:Show(false);menu:Show(true)
local ending=table.clone(menu.tweens)
menuUI:Destroy()
for _,tween in ipairs(ending) do assert(tween.Cancelled,"Destroyed menu retained animation") end
assert(menu.root.Destroyed or menuUI.overlay.Destroyed,"Menu was not destroyed with UI")
print("[Paintland V39 TEST PASS] Menu/brand/footer separation and 44px targets at 9 sizes; mascot color routing; entrance lifecycle and reduced motion")
