local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Notifications = require(ReplicatedStorage.Source.Core.Utils.Notifications)
local PlantingServer = require(ServerScriptService.Features.Planting.PlantingServer)
local RebirthsServiceServer = require(ServerScriptService.Features.Rebirths.RebirthsServiceServer)
local MonetizationServiceUtils = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceUtils)
local GamepassIds = require(ReplicatedStorage.Source.Game.Assets.GamepassIds)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Handlers = script.Parent.Handlers

local MonetizationServiceServer = {}

local function notifyOnPurchaseResults(plr: Player, wasPurchased: boolean)
    Notifications.Show(plr, {message = (wasPurchased and "Thank you for your purchase!" or "Purchase has not been processed!"), color = (wasPurchased and Color3.new(0, 1, 0) or Color3.new(1, 0, 0))})
end

local function checkConditions(plr: Player, name: string): (boolean, string?)
    if name == "SkipRebirth" then
        return RebirthsServiceServer:canRebirth(plr), "You have reached maximum rebirths!"
    elseif name == "FinishAll" then
        return Data[plr].storage.fruits() > 0, "You have no corn in storage!"
    elseif name == "GrowAll" then
        return PlantingServer:canGrowAll(plr), "You have nothing to currently grow!"
    end

    return true, nil
end

local function setAsOwned(self: MonetizationServiceServer, plr: Player, name: string)
    local owned = self.ownedGamepasses[plr.UserId]
    if not owned then return end

    if not table.find(owned, name) then
        table.insert(owned, name)
    end

    plr:SetAttribute(name, true)
end

function MonetizationServiceServer.onPlrRemoving(self: MonetizationServiceServer, plr: Player)
    self.ownedGamepasses[plr.UserId] = nil
end

function MonetizationServiceServer.onPlrAdded(self: MonetizationServiceServer, plr: Player)
    if self.ownedGamepasses[plr.UserId] then return end
    self.ownedGamepasses[plr.UserId] = {}

    local pending = 0

    for name, id in GamepassIds do
        pending += 1
        task.spawn(function()
            local s, r = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, id)
            end)

            if s and r then
                setAsOwned(self, plr, name)
            end

            pending -= 1
        end)
    end

    while pending > 0 and self.ownedGamepasses[plr.UserId] do
        task.wait()
    end

    if self.ownedGamepasses[plr.UserId] then
        self.net:fire(plr, "updateOwnedGamepasses", self.ownedGamepasses[plr.UserId])
    end
end

function MonetizationServiceServer.purchasedGamepass(self: MonetizationServiceServer, plr: Player, name: string)
    if not self.ownedGamepasses[plr.UserId] then return end

    setAsOwned(self, plr, name)
    self.net:fire(plr, "updateOwnedGamepasses", self.ownedGamepasses[plr.UserId])
end

function MonetizationServiceServer.processReceipt(self: MonetizationServiceServer, receiptInfo)
    local plr = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not plr then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productId = receiptInfo.ProductId
    local productName = MonetizationServiceUtils.getNameFromId(productId)
    if not productName then
        warn("Configuration is not set up for product " .. tostring(productId) .. "!")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local handler = Handlers:FindFirstChild(productName)
    if handler then
        local s, result = pcall(function()
            return require(handler)(plr)
        end)

        if not s then
            warn(result)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        return result or Enum.ProductPurchaseDecision.PurchaseGranted
    end

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationServiceServer.requestPurchase(self: MonetizationServiceServer, plr: Player, name: string)
    local id, type = MonetizationServiceUtils.getInfoFromName(name)
    if not id or not type then return end

    if type == "GamePass" then
        local owned = self.ownedGamepasses[plr.UserId]
        if owned and table.find(owned, name) then return end
    end

    local s, msg = checkConditions(plr, name)
    if not s then
        Notifications.Show(plr, {message = msg, color = Color3.new(1, 0, 0)})
        return
    end

    if type == "GamePass" then
        MarketplaceService:PromptGamePassPurchase(plr, id)
    elseif type == "Product" then
        MarketplaceService:PromptProductPurchase(plr, id)
    end
end

function MonetizationServiceServer.Init(self: MonetizationServiceServer)
    self.net = Networker.server.new("MonetizationService", self, {self.requestPurchase})
    self.ownedGamepasses = {}

    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(self.onPlrAdded, self, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player)
        self:onPlrRemoving(plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(self.onPlrAdded, self, plr)
    end

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, gamePassId: number, wasPurchased: boolean)
        notifyOnPurchaseResults(plr, wasPurchased)

        local name = MonetizationServiceUtils.getNameFromId(gamePassId)
        if name and wasPurchased then
            self:purchasedGamepass(plr, name)
        end
    end)

    MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, wasPurchased: boolean)
        local plr = Players:GetPlayerByUserId(userId)
        if not plr then return end

        notifyOnPurchaseResults(plr, wasPurchased)
    end)

    MarketplaceService.ProcessReceipt = function(receiptInfo)
        return self:processReceipt(receiptInfo)
    end
end

type MonetizationServiceServer = typeof(MonetizationServiceServer) & {
   net: typeof(Networker.server),
   ownedGamepasses: {[number]: {string}}
}

return MonetizationServiceServer :: MonetizationServiceServer