local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Plant = require(ServerScriptService.Features.Planting.Classes.Plant)
local PlotServer = require(ServerScriptService.Features.Plots.PlotServer)
local GetEquippedTool = require(ReplicatedStorage.Core.Platform.GetEquippedTool)
local Plants = require(ReplicatedStorage.Game.Configurations.Plants)
local Seeds = require(ReplicatedStorage.Game.Configurations.Seeds)
local Data = require(ReplicatedStorage.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)

local PlantingServer = {}

local function rollWeight(plantName: string): number
    local config = Plants[plantName].Weight
    local min = config.Min
    local average = config.Average
    local max = config.Max

    local total = 0

    for _ = 1, 5 do
        total += math.random()
    end

    local normalized = total / 5
    local weight

    if normalized < 0.5 then
        weight = min + (average - min) * (normalized * 2)
    else
        weight = average + (max - average) * ((normalized - 0.5) * 2)
    end

    return weight
end

function PlantingServer.plant(self: PlantingServer, plr: Player, pos: Vector3)
    if typeof(pos) ~= "Vector3" or not PlotServer:canPlant(plr, pos) then return end

    local seed = GetEquippedTool(plr)
    if not seed then return end

    if not Seeds.Order[seed.Name] or not Seeds.Data[seed.Name] then
        warn("Seed config is missing for " .. seed.Name .. "!")
        return
    end
    
    local i = table.find(Data[plr].inventory.seeds(), seed.Name)
    if not i then return end

    local weight = rollWeight(seed.Name)

    Plant.new(self.Net, plr, seed.Name, pos, weight)

    Data[plr].inventory.seeds.Remove(i)
    seed:Destroy()

    self.Net:fire(plr, "playAnimation", pos, seed.Name)
end

function PlantingServer.Init(self: PlantingServer)
    self.Net = Networker.server.new("Planting", {self.plant})
end

type PlantingServer = typeof(PlantingServer) & {
    Net: typeof(Networker.server)
}

return PlantingServer :: PlantingServer