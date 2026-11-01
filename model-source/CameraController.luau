-- V21: stable 3/4-overhead camera, independent of input position or UI layout.
local UIS=game:GetService("UserInputService")
local Camera={}
Camera.__index=Camera
local function damp(pos,vel,target,frequency,dt)
    local w=math.max(.01,frequency)
    local d=pos-target
    local decay=math.exp(-w*dt)
    local temp=(vel+d*w)*dt
    return target+(d+temp)*decay,(vel-temp*w)*decay
end
function Camera.new(cfg)
    local self=setmetatable({cfg=cfg,position=Vector2.zero,base=Vector2.zero,
        velocity=Vector2.zero,kick=Vector2.zero,kickVelocity=Vector2.zero,initialized=false},Camera)
    self:Apply()
    return self
end
function Camera:Reset(target)
    self.position=target
    self.base=target
    self.velocity=Vector2.zero
    self.kick=Vector2.zero
    self.kickVelocity=Vector2.zero
    self.initialized=true
    self:Apply()
end
function Camera:CapturePulse(heading,count)
    if UIS.TouchEnabled or self.cfg.CaptureCameraEnabled==false then return end
    local scale=math.clamp(math.sqrt(math.max(count or 0,0))*.06,0,.4)
    self.kickVelocity+=Vector2.new(-math.cos(heading),-math.sin(heading))*scale*2.5
end
function Camera:KillPulse(heading,streak)
    if UIS.TouchEnabled or self.cfg.KillCameraEnabled==false then return end
    self.kickVelocity+=Vector2.new(-math.cos(heading),-math.sin(heading))*
        math.min(1.8,.7+(streak or 1)*.14)
end
function Camera:Update(target,dt)
    if not self.initialized then self:Reset(target) end
    dt=math.clamp(dt or 0,0,.05)
    self.base,self.velocity=damp(self.base,self.velocity,target,
        self.cfg.CameraSpringFrequency or 14,dt)
    self.kick,self.kickVelocity=damp(self.kick,self.kickVelocity,Vector2.zero,18,dt)
    self.position=self.base+self.kick
end
function Camera:Apply()
    local cam=workspace.CurrentCamera
    if not cam then return end
    cam.CameraType=Enum.CameraType.Scriptable
    cam.FieldOfView=self.cfg.WorkspaceCameraFOV or 48
    local screenHeight=cam.ViewportSize.Y
    local phone=UIS.TouchEnabled or (screenHeight>0 and cam.ViewportSize.X<650)
    local visible=phone and (self.cfg.MobileWorldViewHeight or 136) or
        (self.cfg.WorldViewHeightStuds or 124)
    local dist=(visible/2)/math.tan(math.rad(cam.FieldOfView)/2)
    local angle=math.rad(self.cfg.CameraTiltDegrees or 21)
    -- A small Z offset reveals the front and height of the toy characters.
    local center=Vector3.new(self.position.X,1.2,self.position.Y)
    local eye=center+Vector3.new(0,dist*math.cos(angle),dist*math.sin(angle))
    cam.CFrame=CFrame.lookAt(eye,center,Vector3.new(0,1,0))
    cam.Focus=CFrame.new(center)
end
return Camera
