local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)

local hotbarLimit = 6

type Data = {
    Order: {string},
    HotbarCount: number,
    Queued: boolean,
}

local InventoryServer = {}

local function collect(plr: Player)
    local counts: {[string]: number} = {}
    local names: {string} = {}
    local equipped: string? = nil

    local function add(tool: Tool)
        if not counts[tool.Name] then
            counts[tool.Name] = 0
            table.insert(names, tool.Name)
        end

        counts[tool.Name] += 1
    end

    local backpack = plr:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, child in backpack:GetChildren() do
            if child:IsA("Tool") then
                add(child)
            end
        end
    end

    local char = plr.Character
    if char then
        for _, child in char:GetChildren() do
            if child:IsA("Tool") then
                add(child)
                equipped = child.Name
            end
        end
    end

    return counts, names, equipped
end

function InventoryServer.sync(self: InventoryServer, plr: Player)
    local data = self.Data[plr]
    if not data then return end

    local counts, names, equipped = collect(plr)
    local order, used = {}, {}
    local hotbarCount = 0

    for index, name in data.Order do
        if counts[name] and not used[name] then
            used[name] = true
            table.insert(order, name)
            if index <= data.HotbarCount then
                hotbarCount += 1
            end
        end
    end

    for _, name in names do
        if not used[name] then
            used[name] = true
            if hotbarCount < hotbarLimit then
                hotbarCount += 1
                table.insert(order, hotbarCount, name)
            else
                table.insert(order, name)
            end
        end
    end

    data.Order = order
    data.HotbarCount = hotbarCount

    local items = {}
    for _, name in order do
        table.insert(items, { Name = name, Amount = counts[name] })
    end

    self.Net:fire(plr, "sync", items, equipped, hotbarCount)
end

function InventoryServer.queueSync(self: InventoryServer, plr: Player)
    local data = self.Data[plr]
    if not data or data.Queued then return end

    data.Queued = true

    task.defer(function()
        data.Queued = false

        if self.Data[plr] == data then
            self:sync(plr)
        end
    end)
end

function InventoryServer.onPlrAdded(self: InventoryServer, plr: Player)
    self.Data[plr] = {Order = {}, HotbarCount = 0, Queued = false}

    local function watch(container: Instance)
        container.ChildAdded:Connect(function()
            self:queueSync(plr)
        end)

        container.ChildRemoved:Connect(function()
            self:queueSync(plr)
        end)

        self:queueSync(plr)
    end

    plr.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watch(child)
        end
    end)

    for _, child in plr:GetChildren() do
        if child:IsA("Backpack") then
            watch(child)
        end
    end

    plr.CharacterAdded:Connect(watch)
    if plr.Character then
        watch(plr.Character)
    end
end

function InventoryServer.onPlrRemoving(self: InventoryServer, plr: Player)
    self.Data[plr] = nil
end

function InventoryServer.onClientReady(self: InventoryServer, plr: Player)
    self:sync(plr)
end

function InventoryServer.reorder(self: InventoryServer, plr: Player, order: {string}, hotbarCount: number)
    local data = self.Data[plr]
    if not data then return end
    if typeof(order) ~= "table" or #order > 200 then return end
    if typeof(hotbarCount) ~= "number" then return end

    local counts = collect(plr)
    local clean, used = {}, {}

    for _, name in order do
        if typeof(name) == "string" and counts[name] and not used[name] then
            used[name] = true
            table.insert(clean, name)
        end
    end

    data.Order = clean
    data.HotbarCount = math.clamp(math.floor(hotbarCount), 0, math.min(hotbarLimit, #clean))
    self:sync(plr)
end

function InventoryServer.equip(self: InventoryServer, plr: Player, item: string)
    if typeof(item) ~= "string" then return end

    local char = plr.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end

    local current = char:FindFirstChildWhichIsA("Tool")
    if current and current.Name == item then
        hum:UnequipTools()
        return
    end

    local backpack = plr:FindFirstChildOfClass("Backpack")
    local tool = backpack and backpack:FindFirstChild(item)
    if tool and tool:IsA("Tool") then
        hum:EquipTool(tool)
    end
end

function InventoryServer.Init(self: InventoryServer)
    self.Net = Networker.server.new("Inventory", self, {self.equip, self.onClientReady, self.reorder})
    self.Data = {}

    Players.PlayerAdded:Connect(function(plr: Player)
        self:onPlrAdded(plr)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player)
        self:onPlrRemoving(plr)
    end)

    for _, plr in Players:GetPlayers() do
        self:onPlrAdded(plr)
    end
end

type InventoryServer = typeof(InventoryServer) & {
    Net: typeof(Networker.server),
    Data: {[Player]: Data},
}

return InventoryServer :: InventoryServer