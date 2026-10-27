local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)
local Spring = require(ReplicatedStorage.Source.Packages.Spring)
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)

local Mouse = Players.LocalPlayer:GetMouse()
local SeedModels = ReplicatedStorage.Assets.Seeds
local PlantModels = ReplicatedStorage.Assets.Plants
local CropModels = ReplicatedStorage.Assets:FindFirstChild("Crops")

local equipped = false

local PlantingClient = {}

local function getStageModel(models: Instance?, name: string, stage: number?): Model?
    if not models or not stage then
        return nil
    end

    local container = models:FindFirstChild(name)
    local model = container and container:FindFirstChild(tostring(stage))

    if model and model:IsA("Model") then
        return model
    end

    return nil
end

local function spawnStageModel(models: Instance?, name: string, stage: number?, cframe: CFrame): Model?
    local model = getStageModel(models, name, stage)
    if not model then
        warn("Model is missing for " .. name .. " at stage " .. tostring(stage) .. "!")
        return nil
    end

    local clone = model:Clone()
    clone:PivotTo(cframe)
    clone.Parent = workspace

    return clone
end

local function clearCrops(self: PlantingClient, plantId: number)
    local crops = self.Crops[plantId]
    if not crops then return end

    for _, crop in crops do
        crop:Destroy()
    end

    self.Crops[plantId] = nil
end

local function clearPlant(self: PlantingClient, id: number)
    local plant = self.Plants[id]
    if plant then
        plant:Destroy()
        self.Plants[id] = nil
    end

    clearCrops(self, id)
end

local function createCrop(self: PlantingClient, plantId: number, crop: Definitions.Crop)
    local stage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime)
    local clone = spawnStageModel(CropModels, crop.Name, stage, Serialize.UnserializeCFrame(crop.CFrame))
    if not clone then return end

    local crops = self.Crops[plantId]
    if not crops then
        crops = {}
        self.Crops[plantId] = crops
    end

    if crops[crop.Slot] then
        crops[crop.Slot]:Destroy()
    end

    crops[crop.Slot] = clone
end

local function createPlant(self: PlantingClient, plant: Definitions.PlantSnapshot)
    clearPlant(self, plant.Id)

    local stage = PlantingUtils.getGrowthStageFromPlantTime(plant.Name, plant.PlantTime)
    local pos = Serialize.UnserializeVector3(plant.Pos)
    local clone = spawnStageModel(PlantModels, plant.Name, stage, CFrame.new(pos))
    if not clone then return end

    self.Plants[plant.Id] = clone

    for _, crop in plant.Crops or {} do
        createCrop(self, plant.Id, crop)
    end
end

function PlantingClient.unequipped(self: PlantingClient)
    if not equipped then return end
    equipped = false

    self.Janitor:Cleanup()
end

function PlantingClient.equipped(self: PlantingClient)
    if equipped then return end
    equipped = true

    self.Janitor:Add(
        UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
            if gpe then return end

            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                self.Net:fire("plant", Mouse.Hit.Position)
            end
        end), "Disconnect"
    )
end

function PlantingClient.playAnimation(self: PlantingClient, pos: Vector3, seedName: string)
    local model = SeedModels:FindFirstChild(seedName)
    if not model then
        warn("Seed model is missing for " .. seedName .. "!")
        return
    end

    local clone = model:Clone()
    local startPos = pos + Vector3.new(0, 5, 0)

    clone:PivotTo(CFrame.new(startPos))
    clone.Parent = workspace

    local posSpring = Spring.new(startPos, 0.8, 1)
    posSpring.Target = pos

    local rotation = Vector3.new(
        math.random() * math.pi,
        math.random() * math.pi,
        math.random() * math.pi
    )

    local rotSpring = Spring.new(rotation, 0.5, 0.6)
    rotSpring.Target = Vector3.zero

    local startTime = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local rot = rotSpring.Position

        clone:PivotTo(
            CFrame.new(posSpring.Position)
                * CFrame.Angles(rot.X, rot.Y, rot.Z)
        )

        local settled = (posSpring.Position - posSpring.Target).Magnitude < 0.05 and rot.Magnitude < 0.05
        if settled or os.clock() - startTime > 5 then
            conn:Disconnect()
            clone:Destroy()
        end
    end)
end

function PlantingClient.updatePlant(self: PlantingClient, id: number, plantName: string, stage: number)
    local old = self.Plants[id]
    if not old then return end

    local clone = spawnStageModel(PlantModels, plantName, stage, old:GetPivot())
    if not clone then return end

    old:Destroy()
    self.Plants[id] = clone
end

function PlantingClient.updateCrop(self: PlantingClient, plantId: number, slot: number, cropName: string, stage: number)
    local crops = self.Crops[plantId]
    local old = crops and crops[slot]
    if not old then return end

    local clone = spawnStageModel(CropModels, cropName, stage, old:GetPivot())
    if not clone then return end

    old:Destroy()
    crops[slot] = clone
end

function PlantingClient.spawnPlants(self: PlantingClient, plants: {Definitions.PlantSnapshot})
    for _, plant in plants do
        createPlant(self, plant)
    end
end

function PlantingClient.spawnCrop(self: PlantingClient, plantId: number, crop: Definitions.Crop)
    if not self.Plants[plantId] then return end

    createCrop(self, plantId, crop)
end

function PlantingClient.deletePlants(self: PlantingClient, plants: {number})
    for _, id in plants do
        clearPlant(self, id)
    end
end

function PlantingClient.Init(self: PlantingClient)
    self.Plants = {}
    self.Crops = {}
    self.Janitor = Janitor.new()
    self.Net = Networker.client.new("Planting", self)
    self.Net:fire("requestPlants")
end

type PlantingClient = typeof(PlantingClient) & {
    Net: typeof(Networker.client),
    Janitor: typeof(Janitor.new()),
    Plants: {[number]: Model},
    Crops: {[number]: {[number]: Model}}
}

return PlantingClient :: PlantingClient