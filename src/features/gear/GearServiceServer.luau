local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlantingServer = require(ServerScriptService.Features.Planting.PlantingServer)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local GearServiceServer = {}

function GearServiceServer.deletePlant(self: GearServiceServer, plr: Player, plantId: number)
    if type(plantId) ~= "number" then return end
    PlantingServer:removePlant(plr, plantId)
end

function GearServiceServer.Init(self: GearServiceServer)
    self.net = Networker.server.new("GearService", self, {self.deletePlant})
end

type GearServiceServer = typeof(GearServiceServer) & {
    net: typeof(Networker.server)
}

return GearServiceServer :: GearServiceServer