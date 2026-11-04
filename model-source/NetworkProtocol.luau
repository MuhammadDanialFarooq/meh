-- Shared wire format; server validates intent, never client positions or ownership.
local Protocol={Version=2,RemoteFolder="PaintlandNetwork",CommandRemote="Command",StateRemote="State",InputRemote="Input",AbilityRemote="Ability"}
function Protocol.IsFinite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
function Protocol.Input(message,lastSequence)
    if type(message)~="table" or not Protocol.IsFinite(message.seq) or message.seq%1~=0
        or message.seq<1 or message.seq>2147483647 or message.seq<=(lastSequence or 0)
        or not Protocol.IsFinite(message.heading) then return nil end
    return message.seq,math.atan2(math.sin(message.heading),math.cos(message.heading))
end
function Protocol.Allow(bucket,now,rate,capacity)
    bucket.tokens=math.min(capacity,(bucket.tokens or capacity)+math.max(0,now-(bucket.time or now))*rate)
    bucket.time=now
    if bucket.tokens<1 then return false end
    bucket.tokens-=1;return true
end
function Protocol.Entity(e,includeTrail)
    local nodes={}
    if includeTrail~=false then for i,p in ipairs(e.nodes) do nodes[i]={p.X,p.Y} end end
    return {id=e.id,userId=e.userId or 0,name=e.name,color={e.color.R,e.color.G,e.color.B},
        connected=e.connected==true,isHuman=e.isHuman,alive=e.alive,x=e.pos.X,y=e.pos.Y,
        heading=e.heading,targetHeading=e.targetHeading,kills=e.kills,killStreak=e.killStreak,
        dashRemaining=e.dashRemaining or 0,dashMultiplier=e.dashMultiplier or 1,
        bestKillStreak=e.bestKillStreak,drawing=e.drawing,visualVersion=e.visualVersion,
        trailGeneration=e.trailGeneration,spawnRevision=e.spawnRevision,nodes=includeTrail~=false and nodes or nil,
        trailCells=includeTrail~=false and table.clone(e.trailCells) or nil}
end
return Protocol
