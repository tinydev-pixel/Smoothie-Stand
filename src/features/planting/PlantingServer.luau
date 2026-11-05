local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Plant = require(ServerScriptService.Features.Planting.Classes.Plant)
local PlotServer = require(ServerScriptService.Features.Plots.PlotServer)
local GetEquippedTool = require(ReplicatedStorage.Source.Core.Platform.GetEquippedTool)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local nextId = 0

local PlantingServer = {}

local function generateId(): number
    nextId += 1
    return nextId
end

local function isFinite(n: number): boolean
    return n == n and math.abs(n) ~= math.huge
end

local function isValidPosition(pos: Vector3): boolean
    return isFinite(pos.X) and isFinite(pos.Y) and isFinite(pos.Z)
end

local function migrateSave(saved: Definitions.Plant)
    if saved.Space == "Plot" then return end

    local worldPos = Serialize.UnserializeVector3(saved.Pos)
    local nearest = PlotServer:getNearestPlotCFrame(worldPos)
    if not nearest then return end

    saved.Pos = Serialize.SerializeVector3(PlantingUtils.toPlotPosition(nearest, worldPos))
    saved.Space = "Plot"
end

local function createPlant(self: PlantingServer, plr: Player, data: Definitions.Plant, saved: Definitions.Plant?, plotCFrame: CFrame)
    local id = generateId()
    local plotPos = Serialize.UnserializeVector3(data.Pos)
    local cframe = PlantingUtils.toWorldCFrame(plotCFrame, plotPos)
    local plant = Plant.new(self.Net, plr, id, data.Name, cframe, data.Weight, data.PlantTime, data.Crops, saved)

    self.Plants[id] = plant

    return plant
end

local function initializePlants(self: PlantingServer, plr: Player)
    if self.Loaded[plr] then return end
    self.Loaded[plr] = true

    local data = Data.Service:waitForData(plr)
    if not data or plr.Parent ~= Players then return end

    local profile = Data.Service:getProfile(plr)
    if not profile then return end

    local plotCFrame = PlotServer:waitForPlotCFrame(plr)
    if not plotCFrame then return end

    local snapshots = {}

    for _, saved in profile.Data.plants do
        migrateSave(saved)

        local ok, result = pcall(createPlant, self, plr, saved, saved, plotCFrame)

        if ok then
            table.insert(snapshots, result:snapshot())
        else
            warn("Failed to load plant for " .. plr.Name .. ": " .. tostring(result))
        end
    end

    if #snapshots > 0 then
        self.Net:fireAll("spawnPlants", snapshots)
    end
end

function PlantingServer.cleanupPlants(self: PlantingServer, plr: Player)
    local removed = {}

    for id, plant in self.Plants do
        if plant.Owner == plr then
            plant:destroy()
            self.Plants[id] = nil
            table.insert(removed, id)
        end
    end

    if #removed > 0 then
        self.Net:fireAll("deletePlants", removed)
    end
end

function PlantingServer.requestPlants(self: PlantingServer, plr: Player)
    if self.Synced[plr] then return end
    self.Synced[plr] = true

    local snapshots = {}

    for _, plant in self.Plants do
        table.insert(snapshots, plant:snapshot())
    end

    if #snapshots > 0 then
        self.Net:fire(plr, "spawnPlants", snapshots)
    end
end

function PlantingServer.harvestCrop(self: PlantingServer, plr: Player, plantId: number, slot: number)
    if type(plantId) ~= "number" or type(slot) ~= "number" then return end

    local plant = self.Plants[plantId]
    if not plant then return end

    plant:harvestCrop(plr, slot)
end

function PlantingServer.plant(self: PlantingServer, plr: Player, pos: Vector3)
    if typeof(pos) ~= "Vector3" or not isValidPosition(pos) or not PlotServer:canPlant(plr, pos) then return end

    local plotCFrame = PlotServer:getPlotCFrame(plr)
    if not plotCFrame then return end

    local seed = GetEquippedTool(plr)
    if not seed then return end

    local seedName = seed.Name:gsub(" Seed", "")

    if not PlantingUtils.isSeed(seed.Name) then
        warn("Seed config is missing for " .. seedName .. "!")
        return
    end

    if not Plants[seedName] then
        warn("Plant config is missing for " .. seedName .. "!")
        return
    end

    local i = table.find(Data[plr].inventory.seeds(), seedName)
    if not i then return end

    local plantData: Definitions.Plant = {
        Name = seedName,
        PlantTime = workspace:GetServerTimeNow(),
        Weight = PlantingUtils.rollWeight(seedName, "Plant"),
        Pos = Serialize.SerializeVector3(PlantingUtils.toPlotPosition(plotCFrame, pos)),
        Space = "Plot"
    }

    local ok, plant = pcall(createPlant, self, plr, plantData, plantData, plotCFrame)
    if not ok then
        warn("Failed to create plant: " .. tostring(plant))
        return
    end

    Data[plr].plants.Insert(plantData)
    Data[plr].inventory.seeds.Remove(i)
    seed:Destroy()

    self.Net:fireAll("spawnPlants", {plant:snapshot()})
    self.Net:fire(plr, "playAnimation", pos, seedName)
end

function PlantingServer.canGrowAll(self: PlantingServer, plr: Player): boolean
    for _, plant in self.Plants do
        if plant.Owner == plr and plant:canGrow() then
            return true
        end
    end

    return false
end

function PlantingServer.growAll(self: PlantingServer, plr: Player): boolean
    if not self:canGrowAll(plr) then return false end

    for _, plant in self.Plants do
        if plant.Owner == plr then
            plant:growNow()
        end
    end

    return true
end

function PlantingServer.Init(self: PlantingServer)
    self.Net = Networker.server.new("Planting", self, {self.plant, self.requestPlants, self.harvestCrop})
    self.Plants = {}
    self.Loaded = {}
    self.Synced = {}

    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(initializePlants, self, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player)
        self.Loaded[plr] = nil
        self.Synced[plr] = nil
        PlantingServer.cleanupPlants(self, plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(initializePlants, self, plr)
    end

    task.spawn(function()
        while true do
            for _, plant in self.Plants do
                local ok, err = pcall(plant.update, plant)

                if not ok then
                    warn("Plant " .. plant.Id .. " failed to update: " .. tostring(err))
                end
            end

            task.wait(1)
        end
    end)
end

type PlantingServer = typeof(PlantingServer) & {
    Net: typeof(Networker.server),
    Plants: {[number]: typeof(Plant)},
    Loaded: {[Player]: boolean},
    Synced: {[Player]: boolean}
}

return PlantingServer :: PlantingServer