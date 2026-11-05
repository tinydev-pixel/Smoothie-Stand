local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local DrainRateUpgrades = require(ReplicatedStorage.Source.Game.Configurations.DrainRateUpgrades)
local GroupRewardsServiceServer = require(ServerScriptService.Features.GroupRewards.GroupRewardsServiceServer)
local OfflineRewardsServiceServer = require(ServerScriptService.Features.OfflineRewards.OfflineRewardsServiceServer)
local Signals = require(ReplicatedStorage.Source.Game.Signals)
local CalculateCash = require(ReplicatedStorage.Source.Game.Utils.CalculateCash)
local OwnsGamepass = require(ReplicatedStorage.Source.Game.Utils.OwnsGamepass)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local ButtonsServiceServer = {}

local function destroyCropTool(container: Instance?, name: string, weight: number): boolean
    if not container then return false end

    for _, item in container:GetChildren() do
        if item:IsA("Tool") and item.Name == name and item:GetAttribute("IsCrop") and item:GetAttribute("Weight") == weight then
            item:Destroy()
            return true
        end
    end

    return false
end

local function claimMoney(plr: Player)
    local data = Data[plr]
    if not data then return end

    local cashStorage = data.storage.cash()
    if cashStorage <= 0 then return end

    data.storage.cash(0)
    data.cash(function(cash)
        return cash + cashStorage
    end)
end

local function insertCorn(plr: Player)
    local data = Data[plr]
    if not data then return end

    local crops = data.inventory.crops()
    if #crops == 0 then return end

    local doubleTheCorn = OwnsGamepass(plr, "2xCorn")

    local toInsert = {}
    for i, crop in crops do
        table.insert(toInsert, {index = i, name = crop.Name, weight = crop.Weight})
    end

    for n = #toInsert, 1, -1 do
        local entry = toInsert[n]

        data.inventory.crops.Remove(entry.index)
        data.storage.corn(function(corn)
            return corn + entry.weight * (doubleTheCorn and 2 or 1)
        end)

        if not destroyCropTool(plr:FindFirstChildOfClass("Backpack"), entry.name, entry.weight) then
            destroyCropTool(plr.Character, entry.name, entry.weight)
        end
    end
end

local function upgradeDrainRate(plr: Player)
    local rate = Data[plr].upgrades.drainRate()
    local cash = Data[plr].cash()
    local nextUpg = DrainRateUpgrades.getNextUpgrade(rate)
    if cash < nextUpg.Price then return end

    Data[plr].upgrades.drainRate(nextUpg.Rate)
    Data[plr].cash(function(oldAmt)
        return oldAmt - nextUpg.Price
    end)
end

function ButtonsServiceServer.btnActivated(self: ButtonsServiceServer, plr: Player, btnType: string)
    if not OfflineRewardsServiceServer:plrHasClaimed(plr) then 
        -- Notification
        return
    end
    if type(btnType) ~= "string" then return end

    if btnType == "ClaimMoney" then
        claimMoney(plr)
    elseif btnType == "InsertCorn" then
        insertCorn(plr)
    elseif btnType == "GroupRewards" then
        GroupRewardsServiceServer:claim(plr)
    elseif btnType == "DrainRate" then
        upgradeDrainRate(plr)
    end
end

function ButtonsServiceServer.process(self: ButtonsServiceServer, plr: Player, toDrain: number?)
    local data = Data[plr]
    local cornStorage = data and data.storage.corn() or 0

    if OfflineRewardsServiceServer:plrHasClaimed(plr) and data and cornStorage > 0 then
        local drained = toDrain or math.min(cornStorage, data.upgrades.drainRate())
        local totalCash = CalculateCash(plr, data.rebirths(), drained)

        if drained > 0 then
            data.storage.corn(function(corn)
                return math.max(corn - drained, 0)
            end)

            data.storage.cash(function(cash)
                return cash + totalCash
            end)
        end
    end
end

function ButtonsServiceServer.onPlrRemoving(self: ButtonsServiceServer, plr: Player)
    self.janitor:Remove(plr.UserId)
    OfflineRewardsServiceServer:onPlrRemoving(plr)
    GroupRewardsServiceServer:onPlrRemoving(plr)
end

function ButtonsServiceServer.onPlrAdded(self: ButtonsServiceServer, plr: Player)
    Data.Service:waitForData(plr)
    OfflineRewardsServiceServer:onPlrAdded(plr)
    GroupRewardsServiceServer:onPlrAdded(plr)

    self.janitor:Add(
        task.spawn(function()            
            while plr.Parent == Players do
                self:process(plr)
                task.wait(1)
            end
        end), true, plr.UserId
    )
end

function ButtonsServiceServer.Init(self: ButtonsServiceServer)
    self.Net = Networker.server.new("ButtonsService", self, {self.btnActivated})
    self.janitor = Janitor.new()

    Signals.plotAssigned:Connect(function(plr: Player, plotId: number)
        self.Net:fire(plr, "onPlotAssigned", plotId)
    end)

    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(self.onPlrAdded, self, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player)
        task.spawn(self.onPlrRemoving, self, plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(self.onPlrAdded, self, plr)
    end
end

type ButtonsServiceServer = typeof(ButtonsServiceServer) & {
    Net: typeof(Networker.server),
    janitor: typeof(Janitor.new())
}

return ButtonsServiceServer :: ButtonsServiceServer