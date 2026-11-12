local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Notifications = require(ReplicatedStorage.Source.Core.Utils.Notifications)
local MonetizationServiceUtils = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceUtils)
local DrainRateUpgrades = require(ReplicatedStorage.Source.Game.Configurations.DrainRateUpgrades)
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local GroupRewardsServiceServer = require(ServerScriptService.Features.GroupRewards.GroupRewardsServiceServer)
local MonetizationServiceServer = require(ServerScriptService.Features.Monetization.MonetizationServiceServer)
local OfflineRewardsServiceServer = require(ServerScriptService.Features.OfflineRewards.OfflineRewardsServiceServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)
local Signals = require(ReplicatedStorage.Source.Game.Signals)
local CalculateCash = require(ReplicatedStorage.Source.Game.Utils.CalculateCash)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local restrictedByOfflineRewards = {
    "ClaimMoney", 
    "InsertFruits",
}

local ButtonsServiceServer = {}

local function claimMoney(plr: Player)
    local data = Data[plr]
    if not data then return end

    local cashStorage = data.storage.cash()
    if cashStorage <= 0 then return end

    data.storage.cash(0)
    data.cash(function(cash)
        return cash + cashStorage
    end)

    TutorialServiceServer:advance(plr, 6)
end

local function insertFruits(self: ButtonsServiceServer, plr: Player)
    local data = Data[plr]
    if not data then return end

    local fruits = data.inventory.fruits()
    if #fruits == 0 then return end

    local toInsert = {}
    for i, name in fruits do
        local config = Fruits[name]

        if config then
            table.insert(toInsert, {index = i, value = config.Value})
        end
    end

    for n = #toInsert, 1, -1 do
        local entry = toInsert[n]

        data.inventory.fruits.Remove(entry.index)
        data.storage.fruits(function(corn)
            return corn + entry.value 
        end)
    end

    self.Net:fire(plr, "onFruitsInsert")

    if #toInsert > 0 then
        TutorialServiceServer:advance(plr, 5)
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

    TutorialServiceServer:advance(plr, 7)
end

function ButtonsServiceServer.btnActivated(self: ButtonsServiceServer, plr: Player, btnType: string)
    if type(btnType) ~= "string" then return end

    if not OfflineRewardsServiceServer:plrHasClaimed(plr) and table.find(restrictedByOfflineRewards, btnType) then
        Notifications.Show(plr, {message = "Claim offline rewards first!", color = Color3.new(1, 0, 0)})
        return
    end

    if btnType == "ClaimMoney" then
        claimMoney(plr)
    elseif btnType == "InsertFruits" then
        insertFruits(self, plr)
    elseif btnType == "GroupRewards" then
        GroupRewardsServiceServer:claim(plr)
    elseif btnType == "DrainRate" then
        upgradeDrainRate(plr)
    elseif MonetizationServiceUtils.getInfoFromName(btnType) ~= nil then
        MonetizationServiceServer:requestPurchase(plr, btnType)
    end
end

function ButtonsServiceServer.process(self: ButtonsServiceServer, plr: Player, toDrain: number?)
    local data = Data[plr]
    local fruits = data and data.storage.fruits() or 0

    if OfflineRewardsServiceServer:plrHasClaimed(plr) and data and fruits > 0 then
        local drained = toDrain or math.min(fruits, data.upgrades.drainRate())
        local totalCash = CalculateCash(plr, data.rebirths(), drained)

        if drained > 0 then
            data.storage.fruits(function(corn)
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