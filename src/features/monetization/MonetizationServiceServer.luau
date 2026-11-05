local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlantingServer = require(ServerScriptService.Features.Planting.PlantingServer)
local RebirthsServiceServer = require(ServerScriptService.Features.Rebirths.RebirthsServiceServer)
local MonetizationServiceUtils = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceUtils)
local GamepassIds = require(ReplicatedStorage.Source.Game.Assets.GamepassIds)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Handlers = script.Parent.Handlers

local MonetizationServiceServer = {}

local function checkConditions(plr: Player, name: string): boolean | string?
    if name == "SkipRebirth" then
        return RebirthsServiceServer:canRebirth(plr), "You have reached maximum rebirths!"
    elseif name == "FinishAll" then
        return Data[plr].storage.corn() > 0, "You have no corn in storage!"
    elseif name == "GrowAll" then
        return PlantingServer:canGrowAll(plr), "You have nothing to currently grow!"
    end

    return false
end

local function setAsOwned(self: MonetizationServiceServer, plr: Player, name: string)
    table.insert(self.ownedGamepasses[plr.UserId], name)
    plr:SetAttribute(name, true)
end

function MonetizationServiceServer.onPlrRemoving(self: MonetizationServiceServer, plr: Player)
    self.ownedGamepasses[plr.UserId] = nil
end

function MonetizationServiceServer.onPlrAdded(self: MonetizationServiceServer, plr: Player)
    for name, id in GamepassIds do
        task.spawn(function()
            local s, r = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, id)
            end)

            if s and r then
                setAsOwned(self, plr, name)
            end
        end)
    end

    self.net:fire(plr, "updateOwnedGamepasses", self.ownedGamepasses[plr.UserId])
end

function MonetizationServiceServer.purchasedGamepass(self, plr: Player, name: string)
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
        warn("Configuration is not set up for product or gamepass " .. productId .. "!")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local _, type = MonetizationServiceUtils.getInfoFromName(productName)
    if type == "GamePass" then
        self:purchasedGamepass(plr, productName)
    end

    local handler = Handlers:FindFirstChild(productName)
    if handler then
        return require(handler)(plr)
    end

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationServiceServer.requestPurchase(self: MonetizationServiceServer, plr: Player, name: string)
    local id, type = MonetizationServiceUtils.getInfoFromName(name)
    if not id or not type then return end

    local s, msg = checkConditions(plr, name) 
    if not s then
        -- Notification using msg 
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

    Players.PlayerRemoving:Connect(function(plr: Player, a1: Enum.PlayerExitReason)
        task.spawn(self.onPlrRemoving, self, plr)
    end)

    task.spawn(function()
        for _, plr in Players:GetPlayers() do
            task.spawn(self.onPlrAdded, self, plr)
        end
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