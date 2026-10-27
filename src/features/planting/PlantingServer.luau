local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Plant = require(ServerScriptService.Features.Planting.Classes.Plant)
local PlotServer = require(ServerScriptService.Features.Plots.PlotServer)
local Seeds = require(ReplicatedStorage.Game.Configurations.Seeds)
local GetEquippedTool = require(ReplicatedStorage.Source.Core.Platform.GetEquippedTool)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local nextId = 0

local PlantingServer = {}

local function generateId(): number
    nextId += 1
    return nextId
end

local function snapshot(self: PlantingServer, t: any, method: string)
    self.Net:fireAll(method, t)
end

local function createPlant(self: PlantingServer, plr: Player, plant: Definitions.Plant, replicate: boolean?): number 
    local id = generateId()
    local c = Plant.new(self.Net, plr, id, plant.Name, plant.Pos, plant.Weight, plant.PlantTime, replicate)
    self.Plants[id] = c

    return id
end

local function cleanupPlants(self: PlantingServer, plr: Player)
    local t = {}

    for id, plant in self.Plants do
        if plant.Owner == plr then
            plant:destroy()
            self.Plants[id] = nil
            table.insert(t, id)
        end
    end

    snapshot(self, t, "deletePlants")
end

local function initializePlants(self: PlantingServer, plr: Player)
    local t = {}
    local plants = Data.Service:waitForData(plr).plants()
    for _, plant in plants do
        local id = createPlant(self, plr, plant, false)
        t[id] = self.Plants[id]
    end

    snapshot(self, t, "spawnPlants")
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

    local time = workspace:GetServerTimeNow()
    local weight = PlantingUtils.rollWeight(seed.Name, "Plant")
    local serPos = Serialize.SerializeVector3(pos)

    Data[plr].plants.Insert({
        Name = seed.Name,
        PlantTime = time,
        Weight = weight,
        Pos = serPos
    })

    createPlant(self, plr, {
        Name = seed.Name,
        PlantTime = time,
        Weight = weight,
        Pos = serPos
    })

    Data[plr].inventory.seeds.Remove(i)
    seed:Destroy()

    self.Net:fire(plr, "playAnimation", pos, seed.Name)
end

function PlantingServer.Init(self: PlantingServer)
    self.Net = Networker.server.new("Planting", {self.plant}) 
    self.Plants = {}

    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(function()
            initializePlants(self, plr)
        end)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player, a1: Enum.PlayerExitReason)
        task.spawn(function()
            cleanupPlants(self, plr)
        end)
    end)

    for _, plr in Players:GetPlayers() do 
        task.spawn(function()
            initializePlants(self, plr)
        end)
    end
end

type PlantingServer = typeof(PlantingServer) & {
    Net: typeof(Networker.server),
    Plants: {[number]: typeof(Plant)}
}

return PlantingServer :: PlantingServer