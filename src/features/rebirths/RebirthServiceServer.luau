local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Notifications = require(ReplicatedStorage.Source.Core.Utils.Notifications)
local PlantingServer = require(ServerScriptService.Features.Planting.PlantingServer)
local Rebirths = require(ReplicatedStorage.Source.Game.Configurations.Rebirths)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local RebirthServiceServer = {}

function RebirthServiceServer.canRebirth(self: RebirthServiceServer, plr: Player)
    local rebirths = Data[plr].rebirths()
    local nextRebirth = Rebirths.Data[rebirths + 1]
    return nextRebirth ~= nil
end

function RebirthServiceServer.rebirthConfirmed(self: RebirthServiceServer, plr: Player)
    if not RebirthServiceServer:canRebirth(plr) then 
        Notifications.Show(plr, {message = "You have maxed out rebirths!"})
        return 
    end

    --// Rewards
    local gardenLevel = Rebirths.getRewardValue(Data[plr].rebirths() + 1, "GardenLevel")
    Data[plr].gardenLevel(gardenLevel)
    Data[plr].rebirths(function(amt)
        return amt + 1
    end)

    --// Losses
    Data[plr].cash(0)
    Data[plr].upgrades.drainRate(1)
    Data[plr].storage(
        {
            cash = 0,
            fruits = 0
        }
    )
    Data[plr].plants({})
    PlantingServer:cleanupPlants(plr)
end

function RebirthServiceServer.rebirth(self: RebirthServiceServer, plr: Player)
    local rebirths = Data[plr].rebirths()
    local nextRebirth = Rebirths.Data[rebirths + 1]
    if not nextRebirth then 
        Notifications.Show(plr, {message = "You have maxed out rebirths!"})
        return 
    end

    local cash = Data[plr].cash()
    local price = nextRebirth.Price
    if not price or price > cash then return end

    self:rebirthConfirmed(plr)
end

function RebirthServiceServer.Init(self: RebirthServiceServer)
    self.net = Networker.server.new("RebirthService", self, {self.rebirth})
end

type RebirthServiceServer= typeof(RebirthServiceServer) & {
    net: typeof(Networker.server)
}

return RebirthServiceServer :: RebirthServiceServer