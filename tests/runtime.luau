-- Small Roblox value/UI doubles for headless logic tests. Not an engine emulator.
local Vector2 = {}
local vector = {}
vector.__index = function(v,k)
    if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y) end
    if k == "Unit" then return v / v.Magnitude end
    return vector[k]
end
function Vector2.new(x,y) return setmetatable({X=x,Y=y},vector) end
Vector2.zero=Vector2.new(0,0)
function vector:Dot(v) return self.X*v.X+self.Y*v.Y end
function vector:Lerp(v,t) return self+(v-self)*t end
vector.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
vector.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
vector.__mul=function(a,b) return Vector2.new(a.X*b,a.Y*b) end
vector.__div=function(a,b) return Vector2.new(a.X/b,a.Y/b) end
local Color3={}
function Color3.new(r,g,b) return {R=r,G=g,B=b} end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local Random={}
function Random.new()
    return {NextNumber=function(_,a,b) return a and (a+(b-a)*0.5) or 0.5 end,
        NextInteger=function(_,a,b) return math.floor((a+b)/2) end}
end
local function warn(...) print("WARN",...) end
local game={GetService=function() return {TouchEnabled=false} end}
local Instance={new=function(kind)
    return {ClassName=kind, Playing=false,
        Play=function(self) self.Playing=true end,
        Stop=function(self) self.Playing=false end,
        Destroy=function(self) self.Destroyed=true end}
end}
local UDim2={fromOffset=function(x,y) return {X=x,Y=y} end}
