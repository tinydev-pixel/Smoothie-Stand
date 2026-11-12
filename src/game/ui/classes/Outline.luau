local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Outline = {}
Outline.__index = Outline

local defaults = {
    size = UDim2.fromScale(0.3, 0.1),
    pos = UDim2.fromScale(0.5, 0.5)
}

local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getFirstAvailableParent(): Frame? | ScreenGui?
    local plr = Players.LocalPlayer
    local plrGui = plr and (plr:FindFirstChild("PlayerGui") or plr:WaitForChild("PlayerGui", 5))
    local gui = plrGui and plrGui:FindFirstChildWhichIsA("ScreenGui")
    return gui
end

local function tween(self: Outline, key: string, properties: {[string]: any})
    if not self.object then return end

    local existing = self.tweens[key]
    if existing then
        existing:Cancel()
    end

    local t = TweenService:Create(self.object, tweenInfo, properties)
    self.tweens[key] = t
    t:Play()
end

function Outline.changePos(self: Outline, pos: UDim2)
    tween(self, "Position", {Position = pos})
end

function Outline.changeSize(self: Outline, size: UDim2)
    tween(self, "Size", {Size = size})
end

function Outline.enable(self: Outline)
    if self.object then
        self.object.Visible = true
    end
end

function Outline.disable(self: Outline)
    if self.object then
        self.object.Visible = false
    end
end

function Outline.cleanup(self: Outline)
    for _, t in self.tweens do
        t:Cancel()
    end

    table.clear(self.tweens)

    if self.object then
        self.object:Destroy()
        self.object = nil
    end
end

function Outline.new(size: UDim2?, pos: UDim2?, parent: Frame? | ScreenGui?)
    if not parent then
        parent = getFirstAvailableParent()
        if not parent then return end
    end

    local self = setmetatable({}, Outline) :: Outline
    self.tweens = {}

    local frame = Instance.new("Frame")
    frame.Name = "Outline"
    frame.BackgroundTransparency = 1
    frame.Size = size or defaults.size
    frame.Position = pos or defaults.pos
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Active = false

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Transparency = 0.5
    stroke.Thickness = 10000
    stroke.Parent = frame

    frame.Parent = parent
    self.object = frame

    return self
end

type Outline = typeof(Outline) & {
    object: Frame?,
    tweens: {[string]: Tween}
}

return Outline :: Outline