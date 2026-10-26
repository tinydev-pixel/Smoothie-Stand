local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)

local gui: ScreenGui? = nil
local side = 1
local active = {}
local connection: RBXScriptConnection? = nil
local MONTSERRAT_BOLD = Font.new(
	"rbxasset://fonts/families/Montserrat.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

local Popup = {}

local function getGui(): ScreenGui
	if gui and gui.Parent then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "Popups"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function getRandomPos(): (number, number)
	local viewport = workspace.CurrentCamera.ViewportSize
	return math.random(math.floor(viewport.X * 0.3), math.floor(viewport.X * 0.7)), math.random(math.floor(viewport.Y * 0.3), math.floor(viewport.Y * 0.7))
end

local function step()
	local now = os.clock()

	for i = #active, 1, -1 do
		local p = active[i]

		if not p.container.Parent then
			table.remove(active, i)
			continue
		end

		local alpha = math.clamp((now - p.startTime) / p.duration, 0, 1)
		local a = 1 - alpha

		local x = a * a * p.startX + 2 * a * alpha * p.controlX + alpha * alpha * p.endX
		local y = a * a * p.startY + 2 * a * alpha * p.controlY + alpha * alpha * p.endY

		p.container.Position = UDim2.fromOffset(x, y)
		p.container.Rotation = math.sin(alpha * math.pi * 2) * 12 * p.side

		local fade = math.clamp((alpha - 0.65) / 0.35, 0, 1)
		p.label.TextTransparency = fade
		p.label.TextStrokeTransparency = 0.3 + 0.7 * fade
		p.icon.ImageTransparency = fade

		if alpha >= 1 then
			p.container:Destroy()
			table.remove(active, i)
		end
	end

	if #active == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

export type Options = {
	Image: string?,        
	Position: Vector2?,    
	TextColor: Color3?,
	TextSize: number?,
	Text: string?,        
}

function Popup.show(amount: number, options: Options?)
	options = options or {}

	local popupSide = side
	side = -side

	local container = Instance.new("Frame")
	container.Name = "Popup"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.fromOffset(0, 48)
	container.AutomaticSize = Enum.AutomaticSize.X
	container.ZIndex = 1000

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(36, 36)
	icon.Image = options.Image or "" 
	icon.ScaleType = Enum.ScaleType.Fit
	icon.LayoutOrder = 1
	icon.ZIndex = 1001
	icon.Parent = container

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(0, 48)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.FontFace = MONTSERRAT_BOLD
	label.TextSize = options.TextSize or 30
	label.TextColor3 = options.TextColor or Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.Text = options.Text or ("+" .. FormatNumber.Simple.FormatCompact(amount))
	label.LayoutOrder = 2
	label.ZIndex = 1001
	label.Parent = container

	local originX, originY
	if options.Position then
		originX, originY = options.Position.X, options.Position.Y
	else
		originX, originY = getRandomPos()
	end

	local leftX = originX - math.random(30, 60)
	local rightX = originX + math.random(30, 60) + 60
	local arcHeight = math.random(25, 45)

	local startX = if popupSide == 1 then leftX else rightX
	local endX = if popupSide == 1 then rightX else leftX

	container.Position = UDim2.fromOffset(startX, originY)
	container.Parent = getGui()

	table.insert(active, {
		container = container,
		label = label,
		icon = icon,
		side = popupSide,
		startX = startX,
		startY = originY,
		endX = endX,
		endY = originY,
		controlX = (startX + endX) / 2,
		controlY = originY - arcHeight * 2,
		startTime = os.clock(),
		duration = math.random(60, 100) / 100,
	})

	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

return Popup