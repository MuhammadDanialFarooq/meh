-- V14 touch steering: never substitute a synthetic mouse position after release.
-- Drag is relative to the initial finger position, not the avatar or the camera.
local UIS = game:GetService("UserInputService")

local Input = {}
Input.__index = Input
local keys = {
    [Enum.KeyCode.W]="W", [Enum.KeyCode.Up]="Up",
    [Enum.KeyCode.A]="A", [Enum.KeyCode.Left]="Left",
    [Enum.KeyCode.S]="S", [Enum.KeyCode.Down]="Down",
    [Enum.KeyCode.D]="D", [Enum.KeyCode.Right]="Right",
}

local function v2(v) return Vector2.new(v.X, v.Y) end

function Input.new(config)
    local self = setmetatable({}, Input)
    self.config = config or {}
    self.pressed = {}
    self.stick = Vector2.zero
    self.touchObject = nil
    self.touchStart = nil
    self.touchCurrent = nil
    self.connections = {}
    self.connections[#self.connections+1] = UIS.InputBegan:Connect(function(i, processed)
        if keys[i.KeyCode] and not processed then self.pressed[keys[i.KeyCode]] = true end
        -- One active finger at a time. UI touches are never steering touches.
        if i.UserInputType == Enum.UserInputType.Touch and not processed and not self.touchObject then
            self.touchObject = i
            self.touchStart = v2(i.Position)
            self.touchCurrent = self.touchStart
        end
    end)
    self.connections[#self.connections+1] = UIS.InputChanged:Connect(function(i)
        if i == self.touchObject then
            self.touchCurrent = v2(i.Position)
        elseif i.KeyCode == Enum.KeyCode.Thumbstick1 then
            self.stick = Vector2.new(i.Position.X, -i.Position.Y)
        end
    end)
    self.connections[#self.connections+1] = UIS.InputEnded:Connect(function(i)
        if keys[i.KeyCode] then self.pressed[keys[i.KeyCode]] = nil end
        if i == self.touchObject then self:ClearTouch() end
        if i.KeyCode == Enum.KeyCode.Thumbstick1 then self.stick = Vector2.zero end
    end)
    -- Touch events preserve the same InputObject across finger movements.
    self.connections[#self.connections+1] = UIS.TouchMoved:Connect(function(i)
        if i == self.touchObject then self.touchCurrent = v2(i.Position) end
    end)
    self.connections[#self.connections+1] = UIS.TouchEnded:Connect(function(i)
        if i == self.touchObject then self:ClearTouch() end
    end)
    self.connections[#self.connections+1] = UIS.WindowFocusReleased:Connect(function()
        self:ClearTouch()
        table.clear(self.pressed)
        self.stick = Vector2.zero
    end)
    return self
end

function Input:ClearTouch()
    self.touchObject = nil
    self.touchStart = nil
    self.touchCurrent = nil
end

function Input:GetHeading(entity, renderer, camera)
    local p = self.pressed
    local direction = Vector2.new(
        ((p.D or p.Right) and 1 or 0) - ((p.A or p.Left) and 1 or 0),
        ((p.S or p.Down) and 1 or 0) - ((p.W or p.Up) and 1 or 0)
    )
    if direction.Magnitude > 0 then
        return math.atan2(direction.Y, direction.X)
    end
    if self.stick.Magnitude > 0.20 then
        return math.atan2(self.stick.Y, self.stick.X)
    end

    if self.touchObject then
        local delta = (self.touchCurrent or self.touchStart) - self.touchStart
        local deadzone = self.config.TouchDeadzone or 18
        if delta.Magnitude >= deadzone then
            -- Convert the drag through the tilted camera's ground-plane basis.
            -- No stale touch target is retained when the finger lifts.
            local cam = workspace.CurrentCamera
            if cam then
                local at = Vector3.new(entity.pos.X, 0, entity.pos.Y)
                local p0 = cam:WorldToViewportPoint(at)
                local px = cam:WorldToViewportPoint(at + Vector3.new(12,0,0))
                local pz = cam:WorldToViewportPoint(at + Vector3.new(0,0,12))
                local ax, ay = px.X-p0.X, px.Y-p0.Y
                local bx, by = pz.X-p0.X, pz.Y-p0.Y
                local determinant = ax*by-ay*bx
                if math.abs(determinant)>0.01 then
                    local dx = (delta.X*by-delta.Y*bx)/determinant
                    local dz = (ax*delta.Y-ay*delta.X)/determinant
                    return math.atan2(dz, dx)
                end
            end
            return math.atan2(delta.Y,delta.X)
        end
        return nil
    end

    -- Touch-capable clients never use mouse fallback when the finger lifts.
    -- This covers mobile emulation and hybrid touch/mouse setups.
    if UIS.TouchEnabled then return nil end
    if UIS.MouseEnabled then
        local cam=workspace.CurrentCamera
        if cam then
            local mouse=UIS:GetMouseLocation()
            local ray=cam:ViewportPointToRay(mouse.X,mouse.Y)
            if math.abs(ray.Direction.Y)>0.0001 then
                local distance=-ray.Origin.Y/ray.Direction.Y
                if distance>0 then
                    local hit=ray.Origin+ray.Direction*distance
                    local delta=Vector2.new(hit.X-entity.pos.X,hit.Z-entity.pos.Y)
                    if delta.Magnitude>(self.config.MouseWorldDeadzone or 3) then
                        return math.atan2(delta.Y,delta.X)
                    end
                end
            end
        end
    end
    return nil
end

function Input:Destroy()
    for _, connection in ipairs(self.connections) do connection:Disconnect() end
    table.clear(self.connections)
    self:ClearTouch()
end

return Input
