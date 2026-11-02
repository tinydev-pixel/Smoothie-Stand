local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local CropConfigs = require(ReplicatedStorage.Source.Game.Configurations.Crops)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)
local Spring = require(ReplicatedStorage.Source.Packages.Spring)
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)

local LocalPlayer = Players.LocalPlayer
local SeedModels = ReplicatedStorage.Assets.Seeds.Models
local PlantModels = ReplicatedStorage.Assets.Plants
local CropModels = ReplicatedStorage.Assets.Crops.Models
local RAY_LENGTH = 500

local PlantFolder = Instance.new("Folder")
PlantFolder.Name = "ClientPlants"
PlantFolder.Parent = workspace

local equipped = false

local PlantingClient = {}

local function getGroundPosition(screenPos: Vector2): Vector3?
    local camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local filter: {Instance} = {PlantFolder}
    local character = LocalPlayer.Character
    if character then
        table.insert(filter, character)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter

    local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)

    return result and result.Position
end

local function getStageModel(models: Instance, name: string, stage: number): Model?
    local container = models:FindFirstChild(name)
    local model = container and container:FindFirstChild(tostring(stage))

    if model and model:IsA("Model") then
        return model
    end

    return nil
end

local function spawnStageModel(models: Instance, name: string, stage: number?, cframe: CFrame, scale: number): Model?
    if not stage or stage < 1 then
        return nil
    end

    local model = getStageModel(models, name, stage)
    if not model then
        warn("Model is missing for " .. name .. " at stage " .. tostring(stage) .. "!")
        return nil
    end

    local clone = model:Clone()
    clone:ScaleTo(scale)
    clone:PivotTo(cframe)
    clone.Parent = PlantFolder

    return clone
end

local function addHarvestPrompt(self: PlantingClient, plantId: number, slot: number, cropName: string, stage: number?, model: Model)
    if self.Owners[plantId] ~= LocalPlayer.UserId then return end

    local config = CropConfigs[cropName]
    if not config then return end

    local part = Instance.new("Part")
    part.Name = "HarvestPrompt"
    part.Size = Vector3.one
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CFrame = model:GetPivot()

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Harvest"
    prompt.ObjectText = cropName
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Enabled = stage ~= nil and stage >= config.GrowthStages
    prompt.Parent = part

    prompt.Triggered:Connect(function()
        self.Net:fire("harvestCrop", plantId, slot)
    end)

    part.Parent = model
end

local function clearCrop(self: PlantingClient, plantId: number, slot: number)
    local crops = self.Crops[plantId]
    local crop = crops and crops[slot]

    if crop then
        crop:Destroy()
        crops[slot] = nil
    end

    local infos = self.CropInfo[plantId]
    if infos then
        infos[slot] = nil
    end
end

local function clearCrops(self: PlantingClient, plantId: number)
    local crops = self.Crops[plantId]
    if crops then
        for _, crop in crops do
            crop:Destroy()
        end

        self.Crops[plantId] = nil
    end

    self.CropInfo[plantId] = nil
end

local function clearPlant(self: PlantingClient, id: number)
    local plant = self.Plants[id]
    if plant then
        plant:Destroy()
        self.Plants[id] = nil
    end

    clearCrops(self, id)
    self.PlantInfo[id] = nil
    self.Owners[id] = nil
end

local function createCrop(self: PlantingClient, plantId: number, crop: Definitions.Crop)
    local stage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime)
    local scale = PlantingUtils.getScale("Crop", crop.Name, crop.Weight)
    local cframe = Serialize.UnserializeCFrame(crop.CFrame)

    local infos = self.CropInfo[plantId]
    if not infos then
        infos = {}
        self.CropInfo[plantId] = infos
    end

    infos[crop.Slot] = {CFrame = cframe, Scale = scale}

    local crops = self.Crops[plantId]
    if not crops then
        crops = {}
        self.Crops[plantId] = crops
    end

    if crops[crop.Slot] then
        crops[crop.Slot]:Destroy()
        crops[crop.Slot] = nil
    end

    local clone = spawnStageModel(CropModels, crop.Name, stage, cframe, scale)
    if not clone then return end

    crops[crop.Slot] = clone
    addHarvestPrompt(self, plantId, crop.Slot, crop.Name, stage, clone)
end

local function createPlant(self: PlantingClient, plant: Definitions.PlantSnapshot)
    clearPlant(self, plant.Id)

    local stage = PlantingUtils.getGrowthStageFromPlantTime(plant.Name, plant.PlantTime)
    local scale = PlantingUtils.getScale("Plant", plant.Name, plant.Weight)
    local cframe = Serialize.UnserializeCFrame(plant.CFrame)

    self.PlantInfo[plant.Id] = {CFrame = cframe, Scale = scale}
    self.Owners[plant.Id] = plant.OwnerId

    local clone = spawnStageModel(PlantModels, plant.Name, stage, cframe, scale)
    if clone then
        self.Plants[plant.Id] = clone
    end

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
                local pos = getGroundPosition(Vector2.new(input.Position.X, input.Position.Y))
                if pos then
                    self.Net:fire("plant", pos)
                end
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
    local goalPos = pos - Vector3.new(0, 0.5, 0)

    for _, d in clone:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
        end
    end

    clone:PivotTo(CFrame.new(startPos))
    clone.Parent = PlantFolder

    local posSpring = Spring.new(startPos)
    posSpring.Damping = 0.8
    posSpring.Frequency = 1
    posSpring.Target = goalPos

    local spinSpring = Spring.new(math.pi * 4)
    spinSpring.Damping = 1
    spinSpring.Frequency = 0.6
    spinSpring.Target = 0

    local startTime = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        posSpring:Update(dt)
        spinSpring:Update(dt)

        local yaw = spinSpring.Position
        clone:PivotTo(CFrame.new(posSpring.Position) * CFrame.Angles(0, yaw, 0))

        local settled = (posSpring.Position - goalPos).Magnitude < 0.7 and math.abs(yaw) < 0.7
        if settled or os.clock() - startTime > 5 then
            conn:Disconnect()
            clone:Destroy()

            local dirt = Instance.new("Part")
            dirt.Anchored = true
            dirt.Shape = Enum.PartType.Cylinder
            dirt.Color = Color3.new(0.462745, 0.317647, 0.003922)
            dirt.Size = Vector3.new(1, 1, 1)
            dirt.CFrame = CFrame.new(pos - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
            dirt.Parent = workspace

            local t = TweenService:Create(dirt, TweenInfo.new(1), {CFrame = CFrame.new(pos - Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))})
            t:Play()
            t.Completed:Once(function()
                task.delay(1, function()
                    local t1 = TweenService:Create(dirt, TweenInfo.new(1), {Transparency = 1})
                    t1:Play()
                    t1.Completed:Once(function()
                        dirt:Destroy()
                    end)
                end)
            end)
        end
    end)
end

function PlantingClient.updatePlant(self: PlantingClient, id: number, plantName: string, stage: number)
    local info = self.PlantInfo[id]
    if not info then return end

    local clone = spawnStageModel(PlantModels, plantName, stage, info.CFrame, info.Scale)
    if not clone then return end

    local old = self.Plants[id]
    if old then
        old:Destroy()
    end

    self.Plants[id] = clone
end

function PlantingClient.updateCrop(self: PlantingClient, plantId: number, slot: number, cropName: string, stage: number)
    local infos = self.CropInfo[plantId]
    local info = infos and infos[slot]
    if not info then return end

    local clone = spawnStageModel(CropModels, cropName, stage, info.CFrame, info.Scale)
    if not clone then return end

    local crops = self.Crops[plantId]
    if not crops then
        crops = {}
        self.Crops[plantId] = crops
    end

    local old = crops[slot]
    if old then
        old:Destroy()
    end

    crops[slot] = clone
    addHarvestPrompt(self, plantId, slot, cropName, stage, clone)
end

function PlantingClient.spawnPlants(self: PlantingClient, plants: {Definitions.PlantSnapshot})
    for _, plant in plants do
        createPlant(self, plant)
    end
end

function PlantingClient.spawnCrop(self: PlantingClient, plantId: number, crop: Definitions.Crop)
    if not self.PlantInfo[plantId] then return end

    createCrop(self, plantId, crop)
end

function PlantingClient.deleteCrop(self: PlantingClient, plantId: number, slot: number)
    clearCrop(self, plantId, slot)
end

function PlantingClient.deletePlants(self: PlantingClient, plants: {number})
    for _, id in plants do
        clearPlant(self, id)
    end
end

function PlantingClient.Init(self: PlantingClient)
    self.Plants = {}
    self.PlantInfo = {}
    self.Crops = {}
    self.CropInfo = {}
    self.Owners = {}
    self.Janitor = Janitor.new()
    self.Net = Networker.client.new("Planting", self)
    self.Net:fire("requestPlants")
end

type StageInfo = {CFrame: CFrame, Scale: number}

type PlantingClient = typeof(PlantingClient) & {
    Net: typeof(Networker.client),
    Janitor: typeof(Janitor.new()),
    Plants: {[number]: Model},
    PlantInfo: {[number]: StageInfo},
    Crops: {[number]: {[number]: Model}},
    CropInfo: {[number]: {[number]: StageInfo}},
    Owners: {[number]: number}
}

return PlantingClient :: PlantingClient