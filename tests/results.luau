local Results=loadModule("ResultsScreen")
local resultsCfg=table.clone(loadModule("Config"));resultsCfg.ReducedMotion=false
local r=Results.new(screen,resultsCfg,{onPlay=function() end,onMainMenu=function() end})
local m=table.create(16,true);local cells=table.create(16,false)
for _,i in ipairs({1,2,6,16}) do cells[i]=true end
local snap={size=4,mask=m,cells=cells,count=4,percent=25,kills=3,color=Color3.fromRGB(0,220,200)}
r:Show(snap);cells[1]=false
assert(r.snapshot.cells[1] and not r.ready and r.percentLabel.Text=="0.0%","Snapshot copy/start broken")
r:Update(1)
assert(r.progress>0 and r.progress<1 and not r.ready,"Results jumped to end")
assert(r.paint.Size.X.Offset==r.mapPixels,"Map paint stretches with reveal width")
r:Update(5);assert(r.percentLabel.Text=="25.0%" and r.ready and r.play.Active,"Results final percent mismatch")
r:Hide();r:Update(10);assert(not r.active and not r.play.Active,"Hidden results accepted action")
snap.percent=0;snap.count=0;snap.cells=table.create(16,false);r:Show(snap);r:Update(5)
assert(r.percentLabel.Text=="0.0%" and r.ready,"Zero coverage failed")
snap.percent=100;snap.count=16;snap.cells=table.create(16,true);resultsCfg.ReducedMotion=true;r:Show(snap)
assert(r.percentLabel.Text=="100.0%" and r.ready,"Reduced-motion100% result failed")
r:Destroy()
print("[Paintland V41 TEST PASS] Accurate immutable results map, smooth0-to-total count-up, gatedactions, zero/full/reducedmotion")
