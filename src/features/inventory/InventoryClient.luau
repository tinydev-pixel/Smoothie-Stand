local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local PlantingClient = require(ReplicatedStorage.Features.Planting.PlantingClient)
local ImageIds = require(ReplicatedStorage.Game.Assets.ImageIds)
local Seeds = require(ReplicatedStorage.Game.Configurations.Seeds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)

local Template = ReplicatedStorage.Assets.UI.Item
local Player = Players.LocalPlayer
local Gui = Player.PlayerGui:WaitForChild("Main")
local Frames = Gui:WaitForChild("Frames")
local Inventory = Frames:WaitForChild("Inventory")
local Hotbar = Frames:WaitForChild("Hotbar")

local hotbarLimit = 6
local dragThreshold = 6
local dragging = false
local pendingItem: typeof(Template)? = nil
local draggingItem: typeof(Template)? = nil
local dragOffset = Vector2.zero
local pendingStart = Vector2.zero
local dragOrigin = {Size = UDim2.new(), AnchorPoint = Vector2.zero, ZIndex = 1}
local draggedFromHotbar = false
local suppressUntil = 0
local inventoryKeybind = Enum.KeyCode.R
local keybinds = {
    Enum.KeyCode.One,
    Enum.KeyCode.Two,
    Enum.KeyCode.Three,
    Enum.KeyCode.Four,
    Enum.KeyCode.Five,
    Enum.KeyCode.Six,
}

local InventoryClient = {}

local function verifyInputType(input: InputObject): boolean
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function verifyMoveType(input: InputObject): boolean
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function getPointer(input: InputObject): Vector2
    local pos = Vector2.new(input.Position.X, input.Position.Y)
    if Gui:IsA("ScreenGui") and Gui.IgnoreGuiInset then
        pos += GuiService:GetGuiInset()
    end
    return pos
end

local function isPointInside(gui: GuiObject, point: Vector2): boolean
    local pos = gui.AbsolutePosition
    local size = gui.AbsoluteSize

    return point.X >= pos.X
        and point.X <= pos.X + size.X
        and point.Y >= pos.Y
        and point.Y <= pos.Y + size.Y
end

local function getHoveredContainer(point: Vector2): GuiObject?
    if isPointInside(Hotbar, point) then
        return Hotbar
    end

    if Inventory.Visible and isPointInside(Inventory, point) then
        return Inventory.ScrollingFrame
    end

    return nil
end

local function startDrag(card: typeof(Template))
    dragging = true
    draggingItem = card
    draggedFromHotbar = card.Parent == Hotbar

    local pos = card.AbsolutePosition
    local size = card.AbsoluteSize

    dragOrigin.Size = card.Size
    dragOrigin.AnchorPoint = card.AnchorPoint
    dragOrigin.ZIndex = card.ZIndex

    card.AnchorPoint = Vector2.zero
    card.Size = UDim2.fromOffset(size.X, size.Y)
    card.ZIndex = 100
    card.Parent = Gui

    local rel = pos - Gui.AbsolutePosition
    card.Position = UDim2.fromOffset(rel.X, rel.Y)
end

local function createCard(self: InventoryClient, name: string)
    local card = Template:Clone()
    card.Name = name
    card.ItemImage.Image = ImageIds[name] or ""
    card.ItemName.Text = name
    card.ItemAmount.Text = ""

    local stroke = Instance.new("UIStroke")
    stroke.Name = "EquippedEffect"
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 0.5
    stroke.Thickness = 2
    stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
    stroke.Enabled = false
    stroke.Parent = card

    card.Activated:Connect(function()
        if not self.Enabled then return end
        if os.clock() < suppressUntil then return end

        self.Net:fire("equip", name)
    end)

    card.InputBegan:Connect(function(input: InputObject)
        if not self.Enabled then return end
        if not verifyInputType(input) then return end
        if dragging or pendingItem then return end

        pendingItem = card
        pendingStart = getPointer(input)
        dragOffset = pendingStart - card.AbsolutePosition
    end)

    return card
end

local function connectSearchBar()
    Inventory.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
        local text = string.lower(Inventory.TextBox.Text)

        for _, card in Inventory.ScrollingFrame:GetChildren() do
            if card:IsA("GuiObject") then
                card.Visible = string.find(string.lower(card.Name), text, 1, true) ~= nil
            end
        end
    end)
end

local function computeOrder(self: InventoryClient, name: string, container: GuiObject?, point: Vector2): ({string}?, number?)
    if not container then return nil, nil end

    local order = table.clone(self.Inventory)
    local current = table.find(order, name)
    if not current then return nil, nil end
    table.remove(order, current)

    local count = self.HotbarCount
    if draggedFromHotbar then
        count -= 1
    end

    if container == Hotbar then
        if count >= hotbarLimit then return nil, nil end

        local pos = 0
        for i = 1, count do
            local other = self.Cards[order[i]]
            if other and point.X > other.AbsolutePosition.X + other.AbsoluteSize.X / 2 then
                pos += 1
            end
        end

        table.insert(order, pos + 1, name)
        return order, count + 1
    end

    if not draggedFromHotbar then return nil, nil end

    table.insert(order, count + 1, name)
    return order, count
end

local function restoreCard(card: typeof(Template))
    card.Size = dragOrigin.Size
    card.AnchorPoint = dragOrigin.AnchorPoint
    card.ZIndex = dragOrigin.ZIndex
    card.Position = UDim2.new()
end

local function cancelDrag(self: InventoryClient)
    local card = draggingItem

    dragging = false
    draggingItem = nil
    pendingItem = nil
    dragOffset = Vector2.zero

    if card then
        restoreCard(card)
        self:sync(self.Items, self.Equipped, self.HotbarCount)
    end
end

local function endDrag(self: InventoryClient)
    local card = draggingItem
    if not card then return end

    local point = card.AbsolutePosition + card.AbsoluteSize / 2

    restoreCard(card)

    local container = getHoveredContainer(point)
    local order, count = computeOrder(self, card.Name, container, point)

    dragging = false
    draggingItem = nil
    pendingItem = nil
    dragOffset = Vector2.zero
    suppressUntil = os.clock() + 0.15

    if order and count then
        local lookup = {}
        for _, info in self.Items do
            lookup[info.Name] = info
        end

        local items = {}
        for _, itemName in order do
            if lookup[itemName] then
                table.insert(items, lookup[itemName])
            end
        end

        self:sync(items, self.Equipped, count)
        self.Net:fire("reorder", order, count)
    else
        self:sync(self.Items, self.Equipped, self.HotbarCount)
    end
end

local function bindInput(self: InventoryClient)
    self.Janitor:Add(
        UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
            if gpe then return end

            if input.KeyCode == inventoryKeybind then
                Inventory.Visible = not Inventory.Visible
                return
            end

            local index = table.find(keybinds, input.KeyCode)
            if index and index <= self.HotbarCount then
                local name = self.Inventory[index]
                if name then
                    self.Net:fire("equip", name)
                end
            end
        end), "Disconnect", "InputBegan"
    )

    self.Janitor:Add(
        UserInputService.InputChanged:Connect(function(input: InputObject)
            if not verifyMoveType(input) then return end

            local point = getPointer(input)

            if pendingItem and not dragging then
                if (point - pendingStart).Magnitude >= dragThreshold then
                    startDrag(pendingItem)
                else
                    return
                end
            end

            if not dragging or not draggingItem then return end

            local rel = point - dragOffset - Gui.AbsolutePosition
            draggingItem.Position = UDim2.fromOffset(rel.X, rel.Y)
        end), "Disconnect", "InputChanged"
    )

    self.Janitor:Add(
        UserInputService.InputEnded:Connect(function(input: InputObject)
            if not verifyInputType(input) then return end

            if dragging and draggingItem then
                endDrag(self)
            else
                pendingItem = nil
            end
        end), "Disconnect", "InputEnded"
    )
end

local function unbindInput(self: InventoryClient)
    self.Janitor:Remove("InputBegan")
    self.Janitor:Remove("InputChanged")
    self.Janitor:Remove("InputEnded")
end

function InventoryClient.disable(self: InventoryClient)
    if not self.Enabled then return end
    self.Enabled = false

    unbindInput(self)
    cancelDrag(self)

    if self.Equipped then
        self.Net:fire("equip", self.Equipped)
    end

    Inventory.TextBox:ReleaseFocus()
    Inventory.Visible = false
    Hotbar.Visible = false
end

function InventoryClient.enable(self: InventoryClient)
    if self.Enabled then return end
    self.Enabled = true

    bindInput(self)
    Hotbar.Visible = true
end

function InventoryClient.sync(self: InventoryClient, items: {{Name: string, Amount: number}}, equipped: string?, hotbarCount: number)
    local seen = {}
    local inventory = {}

    for index, info in items do
        local card = self.Cards[info.Name]
        if not card then
            card = createCard(self, info.Name)
            self.Cards[info.Name] = card
        end

        local inHotbar = index <= hotbarCount
        local targetParent = if inHotbar then Hotbar else Inventory.ScrollingFrame
        if card ~= draggingItem and card.Parent ~= targetParent then
            card.Parent = targetParent
        end

        seen[info.Name] = true
        inventory[index] = info.Name

        card.LayoutOrder = index
        card.ItemAmount.Text = if info.Amount > 1 then "x" .. info.Amount else ""
        card.ItemNumber.Text = if inHotbar then tostring(index) else ""
        card.EquippedEffect.Enabled = (info.Name == equipped)
    end

    for name, card in self.Cards do
        if not seen[name] then
            if card == draggingItem then
                dragging = false
                draggingItem = nil
            end

            if card == pendingItem then
                pendingItem = nil
            end

            card:Destroy()
            self.Cards[name] = nil
        end
    end

    local previousEquipped = self.Equipped

    self.Inventory = inventory
    self.Items = items
    self.Equipped = equipped
    self.HotbarCount = hotbarCount

    --// Support for different items (seeds, tools, etc.)

    if Seeds.Order[equipped] then
        PlantingClient:equipped()
    elseif Seeds.Order[previousEquipped] then
        PlantingClient:unequipped()
    end
end

function InventoryClient.Init(self: InventoryClient)
    self.Net = Networker.client.new("Inventory", self)
    self.Janitor = Janitor.new()
    self.Cards = {}
    self.Inventory = {}
    self.Items = {}
    self.Equipped = nil
    self.HotbarCount = 0
    self.Enabled = false

    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    connectSearchBar()
    self:enable()

    self.Net:fire("onClientReady")
end

type InventoryClient = typeof(InventoryClient) & {
    Net: typeof(Networker.client),
    Cards: {[string]: GuiButton},
    Inventory: {string},
    Items: {{Name: string, Amount: number}},
    Equipped: string?,
    HotbarCount: number,
    Enabled: boolean,
    Janitor: typeof(Janitor.new())
}

return InventoryClient :: InventoryClient