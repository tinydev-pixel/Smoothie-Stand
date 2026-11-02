--[[
local UpgradesServiceClient = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImageIds = require(ReplicatedStorage.Source.Game.Assets.ImageIds)
local Upgrades = require(ReplicatedStorage.Source.Game.Configurations.Upgrades)

local Player = Players.LocalPlayer
local UserKey = tostring(Player.UserId)
local PlayerGui = Player:WaitForChild("PlayerGui")

local Main = PlayerGui:WaitForChild("UpgradeTree")
local Background = Main:WaitForChild("Background")
local UpgradesFrame = Background:WaitForChild("Upgrades")
local HexTemplate = UpgradesFrame:WaitForChild("HexTemplate")
HexTemplate.Visible = false

local BACK_NODE_NAME = "__Back"
local SQRT3 = math.sqrt(3)
local HEX_PADDING = 8

local COLOR_GROUP = Color3.fromRGB(245, 192, 77)
local COLOR_UNBOUGHT = Color3.fromRGB(41, 41, 41)
local COLOR_BOUGHT = Color3.fromRGB(64, 153, 255)
local COLOR_BACK = Color3.fromRGB(144, 247, 103)

type NodeState = "Bought" | "Buyable" | "Hidden" | "Invisible"

local renderedHexes: { GuiObject } = {}
local currentGroup: string? = nil

local function getPlayerState()
	local state = GameStateReplica.Data
	return state.Players and state.Players[UserKey]
end

local function isPurchased(nodeName: string): boolean
	local playerState = getPlayerState()
	return playerState and playerState.Upgrades and playerState.Upgrades[nodeName] == true
end

local stateCache: { [string]: NodeState } = {}

local function computeState(nodeName: string): NodeState
	local cached = stateCache[nodeName]
	if cached then
		return cached
	end

	local node = Upgrades[nodeName]
	if not node then
		stateCache[nodeName] = "Invisible"
		return "Invisible"
	end

	if isPurchased(nodeName) then
		stateCache[nodeName] = "Bought"
		return "Bought"
	end

	local allBought = true
	local allShowing = true

	for _, requirementName in node.Requirements do
		if not isPurchased(requirementName) then
			allBought = false
		end

		local requirementState = computeState(requirementName)
		if requirementState == "Invisible" then
			allShowing = false
			break
		end
	end

	local result: NodeState
	if allBought then
		result = "Buyable"
	elseif allShowing then
		result = "Hidden"
	else
		result = "Invisible"
	end

	stateCache[nodeName] = result
	return result
end

local function hexPositionToUDim(position: Vector2): UDim2
	local hexWidth = HexTemplate.AbsoluteSize.X
	local stepX = hexWidth * 0.75 + HEX_PADDING
	local stepY = hexWidth * (SQRT3 / 2) + HEX_PADDING
	local q, r = position.X, position.Y
	local x = stepX * q
	local y = stepY * (r + q / 2)
	return UDim2.new(0.5, x, 0.5, y)
end

local function setVisualState(hex: GuiObject, options: {
	Hidden: boolean,
	Color: Color3,
	Currency: string?,
	NameText: string?,
	CostText: string?,
	IconImage: string?,
	ShowIcon: boolean,
	ShowOpen: boolean,
	ShowCost: boolean,
})
	local hidden = hex:FindFirstChild("Hidden") :: GuiObject?
	local icon = hex:FindFirstChild("Icon") :: ImageLabel?
	local costLabel = hex:FindFirstChild("CostLabel") :: TextLabel?
	local nameLabel = hex:FindFirstChild("NameLabel") :: TextLabel?
	local openLabel = hex:FindFirstChild("Open") :: GuiObject?

	if hidden then hidden.Visible = options.Hidden end

	if options.Hidden then
		if icon then icon.Visible = false end
		if costLabel then costLabel.Visible = false end
		if nameLabel then nameLabel.Visible = false end
		if openLabel then openLabel.Visible = false end
		return
	end

	if icon then
		icon.Visible = options.ShowIcon
		if options.IconImage then icon.Image = options.IconImage end
	end
	if nameLabel then
		nameLabel.Visible = true
		if options.NameText then nameLabel.Text = options.NameText end
	end
	if costLabel then
		costLabel.Visible = options.ShowCost
		if options.CostText then costLabel.Text = options.CostText end
		local costIconLabel = costLabel:FindFirstChild("Icon") :: ImageLabel?
		if costIconLabel then
			local iconAsset = options.Currency and ImageIds.Cash
			if iconAsset then
				costIconLabel.Image = iconAsset
				costIconLabel.Visible = true
			else
				costIconLabel.Visible = false
			end
		end
	end
	if openLabel then openLabel.Visible = options.ShowOpen end

	if hex:IsA("ImageLabel") or hex:IsA("ImageButton") then
		(hex :: ImageLabel).ImageColor3 = options.Color
	end
end

local function clearRendered()
	for _, hex in renderedHexes do
		hex:Destroy()
	end
	table.clear(renderedHexes)
end

local function onHexClicked(nodeName: string)
	if nodeName == BACK_NODE_NAME then
		local groupNode = currentGroup and Upgrades[currentGroup]
		currentGroup = groupNode and groupNode.ParentGroup or nil
		UpgradeTreeManager.Render()
		return
	end

	local node = Upgrades[nodeName]
	if not node then return end

	local state = computeState(nodeName)
	if state == "Hidden" or state == "Invisible" then
		return
	end

	if node.IsGroup and state == "Bought" then
		currentGroup = nodeName
		UpgradeTreeManager.Render()
		return
	end

	if state == "Buyable" then
		Remotes.PurchaseUpgrade:FireServer(nodeName)
	end
end

local function connectClick(hex: GuiObject, nodeName: string)
	if hex:IsA("ImageButton") or hex:IsA("TextButton") then
		(hex :: ImageButton).Activated:Connect(function()
			onHexClicked(nodeName)
		end)
	else
		hex.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				onHexClicked(nodeName)
			end
		end)
	end
end

local function createHex(nodeName: string, position: Vector2): GuiObject
	local hex = HexTemplate:Clone() :: GuiObject
	hex.Name = nodeName
	hex.AnchorPoint = Vector2.new(0.5, 0.5)
	hex.Position = hexPositionToUDim(position)
	hex.Visible = true
	hex.Parent = Upgrades
	connectClick(hex, nodeName)
	table.insert(renderedHexes, hex)
	return hex
end

function UpgradeTreeManager.Render()
	stateCache = {}
	clearRendered()

	if currentGroup then
		local backHex = createHex(BACK_NODE_NAME, Vector2.new(0, 0))
		setVisualState(backHex, {
			Currency = nil,
			Hidden = false,
			Color = COLOR_BACK,
			NameText = "Back",
			ShowIcon = false,
			ShowOpen = false,
			ShowCost = false,
		})
	end

	for nodeName, node in Upgrades do
		if node.ParentGroup ~= currentGroup then continue end

		local state = computeState(nodeName)
		if state == "Invisible" then continue end

		local hex = createHex(nodeName, node.Position)

		if state == "Hidden" then
			setVisualState(hex, {
				Currency = nil,
				Hidden = true,
				Color = COLOR_UNBOUGHT,
				ShowIcon = false,
				ShowOpen = false,
				ShowCost = false,
			})
			continue
		end

		local color: Color3
		if state == "Bought" then
			color = if node.IsGroup then COLOR_GROUP else COLOR_BOUGHT
		else
			color = COLOR_UNBOUGHT
		end

		local costText: string? = nil
		local currency: string? = nil
		if node.Cost then
			currency = node.Cost.Currency
			if node.Cost.Amount == 0 then
				costText = "FREE"
			else
				costText = Formatter.FormatNumberShort(node.Cost.Amount, 2)
			end
		end

		setVisualState(hex, {
			Currency = currency,
			Hidden = false,
			Color = color,
			NameText = nodeName,
			CostText = costText,
			IconImage = node.Icon,
			ShowIcon = node.Icon ~= nil,
			ShowOpen = node.IsGroup == true and state == "Bought",
			ShowCost = state == "Buyable" and node.Cost ~= nil,
		})
	end
end

function UpgradesServiceClient.Init()
	HexTemplate.Visible = false

	task.spawn(function()
		GameStateReplica:Get()
		UpgradeTreeManager.Render()
	end)

	GameStateReplica:GetDataChangedSignal("Players", UserKey, "Upgrades"):Connect(function()
		UpgradeTreeManager.Render()
	end)
end

return UpgradesServiceClient
]]
return {}