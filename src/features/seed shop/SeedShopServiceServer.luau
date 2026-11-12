local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)
local Seeds = require(ReplicatedStorage.Source.Game.Configurations.Seeds)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local SeedTools = ReplicatedStorage.Assets.Seeds.Tools

local SeedShopServiceServer = {}

local function rollsIn(chance: number?): boolean
    local percent = chance or 100

    if percent >= 100 then return true end
    if percent <= 0 then return false end

    return math.random() * 100 < percent
end

local function rollStock(): {[string]: number}
    local stock = {}

    for _, seed in Seeds.Order do
        local data = Seeds.Data[seed]
        local range = data and data.Stock

        if range and rollsIn(data.Chance) then
            stock[seed] = math.random(range.Min, range.Max)
        else
            stock[seed] = 0
        end
    end

    return stock
end

local function getToolTemplate(seed: string): Tool?
    local template = SeedTools:FindFirstChild(seed .. " Seed")

    if template and template:IsA("Tool") then
        return template
    end

    return nil
end

local function giveTool(plr: Player, template: Tool): boolean
    local backpack = plr:FindFirstChildOfClass("Backpack")
    if not backpack then return false end

    local tool = template:Clone()
    tool.Name = template.Name
    tool.Parent = backpack

    return true
end

local function ensureStock(self: SeedShopServiceServer, plr: Player): {[string]: number}
    local stock = self.perPlrStock[plr.UserId]

    if not stock then
        stock = rollStock()
        self.perPlrStock[plr.UserId] = stock
    end

    return stock
end

function SeedShopServiceServer.restock(self: SeedShopServiceServer)
    self.nextRestock = os.clock() + Seeds.RestockTime

    for _, plr in Players:GetPlayers() do
        local stock = rollStock()
        self.perPlrStock[plr.UserId] = stock
        self.net:fire(plr, "stock", table.clone(stock), true)
    end
end

function SeedShopServiceServer.getStock(self: SeedShopServiceServer, plr: Player): {[string]: number}
    return table.clone(ensureStock(self, plr))
end

function SeedShopServiceServer.purchase(self: SeedShopServiceServer, plr: Player, seed: string)
    if type(seed) ~= "string" then return end

    local seedData = Seeds.Data[seed]
    if not seedData or not table.find(Seeds.Order, seed) then return end

    local data = Data[plr]
    if not data then return end

    local stock = ensureStock(self, plr)
    if (stock[seed] or 0) <= 0 then return end

    local cash = data.cash()
    if type(cash) ~= "number" or cash < seedData.Cost then return end

    local template = getToolTemplate(seed)
    if not template then
        warn("Seed tool is missing for " .. seed .. "!")
        return
    end

    data.cash(function(current)
        return current - seedData.Cost
    end)

    stock[seed] -= 1
    data.inventory.seeds.Insert(seed)
    giveTool(plr, template)

    self.net:fire(plr, "stock", table.clone(stock))

    TutorialServiceServer:onSeedPurchased(plr, seed)
end

function SeedShopServiceServer.Init(self: SeedShopServiceServer)
    self.net = Networker.server.new("SeedShopService", self, {self.getStock, self.purchase})
    self.perPlrStock = {}
    self.nextRestock = os.clock() + Seeds.RestockTime

    Players.PlayerAdded:Connect(function(plr: Player)
        ensureStock(self, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player)
        self.perPlrStock[plr.UserId] = nil
    end)

    for _, plr in Players:GetPlayers() do
        ensureStock(self, plr)
    end

    task.spawn(function()
        while true do
            task.wait(1)

            if os.clock() >= self.nextRestock then
                self:restock()
            end

            self.net:fireAll("updateTimer", math.max(math.ceil(self.nextRestock - os.clock()), 0))
        end
    end)
end

type SeedShopServiceServer = typeof(SeedShopServiceServer) & {
    net: typeof(Networker.server),
    perPlrStock: {[number]: {[string]: number}},
    nextRestock: number
}

return SeedShopServiceServer :: SeedShopServiceServer