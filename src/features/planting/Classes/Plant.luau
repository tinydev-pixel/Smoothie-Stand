local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local Crops = require(ReplicatedStorage.Source.Game.Configurations.Crops)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local PlantModels = ReplicatedStorage.Assets.Plants
local spawnOffsets: {[string]: {CFrame}} = {}

local Plant = {}
Plant.__index = Plant

local function isFullyGrown(self: Plant, stage: number?): boolean
    return stage ~= nil and stage >= self.Config.GrowthStages
end

local function getSpawnOffsets(plantName: string): {CFrame}
    local cached = spawnOffsets[plantName]
    if cached then return cached end

    local offsets = {}
    local config = Plants[plantName]
    local container = PlantModels:FindFirstChild(plantName)
    local model = container and container:FindFirstChild(tostring(config.GrowthStages))
    local folder = model and (model:FindFirstChild("CropSpawnPoints") or container:FindFirstChild("CropSpawnPoints"))

    if model and model:IsA("Model") and folder then
        local pivot = model:GetPivot()
        local points = folder:GetChildren()

        table.sort(points, function(a, b)
            return a.Name < b.Name
        end)

        for _, point in points do
            if point:IsA("BasePart") then
                table.insert(offsets, pivot:ToObjectSpace(point.CFrame))
            elseif point:IsA("Attachment") then
                table.insert(offsets, pivot:ToObjectSpace(point.WorldCFrame))
            end
        end
    end

    if #offsets == 0 then
        warn("No crop spawn points found for " .. plantName .. "!")
    end

    spawnOffsets[plantName] = offsets
    return offsets
end

local function saveCrops(self: Plant)
    local saved = self.Saved
    if not saved then return end

    local crops = {}

    for _, crop in self.Crops do
        table.insert(crops, crop)
    end

    saved.Crops = crops
end

local function updateCrops(self: Plant)
    for slot, crop in self.Crops do
        local stage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime)

        if stage and stage ~= self.CropStages[slot] then
            self.CropStages[slot] = stage
            self.Net:fireAll("updateCrop", self.Id, slot, crop.Name, stage)
        end
    end
end

local function spawnCrops(self: Plant)
    if not Crops[self.CropName] then return end

    local offsets = getSpawnOffsets(self.Name)
    local free = {}
    local count = 0

    for slot = 1, #offsets do
        if self.Crops[slot] then
            count += 1
        else
            table.insert(free, slot)
        end
    end

    local missing = math.min(self.Config.CropAmount - count, #free)
    if missing <= 0 then return end

    local origin = CFrame.new(self.Pos)

    for _ = 1, missing do
        local slot = table.remove(free, math.random(#free))
        local crop: Definitions.Crop = {
            Name = self.CropName,
            SpawnTime = workspace:GetServerTimeNow(),
            Weight = PlantingUtils.rollWeight(self.CropName, "Crop"),
            Slot = slot,
            CFrame = Serialize.SerializeCFrame(origin * offsets[slot])
        }

        self.Crops[slot] = crop
        self.CropStages[slot] = 1
        self.Net:fireAll("spawnCrop", self.Id, crop)
    end

    saveCrops(self)
end

function Plant.update(self: Plant)
    if self.Destroyed then return end

    if not self.FullyGrown then
        local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime)
        if not stage then return end

        if stage ~= self.LastStage then
            self.LastStage = stage
            self.Net:fireAll("updatePlant", self.Id, self.Name, stage)
        end

        if isFullyGrown(self, stage) then
            self.FullyGrown = true
        end
    end

    if not self.FullyGrown then return end

    updateCrops(self)
    spawnCrops(self)
end

function Plant.setSaved(self: Plant, saved: Definitions.Plant)
    self.Saved = saved
    saveCrops(self)
end

function Plant.snapshot(self: Plant): Definitions.PlantSnapshot
    local crops = {}

    for _, crop in self.Crops do
        table.insert(crops, crop)
    end

    return {
        Id = self.Id,
        Name = self.Name,
        PlantTime = self.PlantTime,
        Weight = self.Weight,
        Pos = Serialize.SerializeVector3(self.Pos),
        Crops = crops
    }
end

function Plant.destroy(self: Plant)
    if self.Destroyed then return end
    self.Destroyed = true

    self.Janitor:Destroy()
    table.clear(self.Crops)
    table.clear(self.CropStages)
    self.Saved = nil
end

function Plant.new(net: typeof(Networker.server), farmer: Player, id: number, plantName: string, pos: Vector3, weight: number, plantTime: number, crops: {Definitions.Crop}?, saved: Definitions.Plant?)
    local config = Plants[plantName]
    assert(config, "Plant config is missing for " .. plantName .. "!")

    local self: Plant = setmetatable({}, Plant)
    local stage = PlantingUtils.getGrowthStageFromPlantTime(plantName, plantTime)

    self.Config = config
    self.Net = net
    self.Janitor = Janitor.new()
    self.Id = id
    self.Owner = farmer
    self.Pos = pos
    self.Weight = weight
    self.Name = plantName
    self.PlantTime = plantTime
    self.LastStage = stage or 1
    self.FullyGrown = isFullyGrown(self, stage)
    self.Destroyed = false
    self.CropName = config.Crop or plantName
    self.Crops = {}
    self.CropStages = {}
    self.Saved = saved

    if not Crops[self.CropName] then
        warn("Crop config is missing for " .. self.CropName .. "!")
    end

    if crops and self.FullyGrown then
        local slotCount = #getSpawnOffsets(plantName)

        for _, crop in crops do
            local cropStage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime)
            local validSlot = type(crop.Slot) == "number" and crop.Slot >= 1 and crop.Slot <= slotCount

            if cropStage and validSlot and not self.Crops[crop.Slot] then
                self.Crops[crop.Slot] = crop
                self.CropStages[crop.Slot] = cropStage
            end
        end
    end

    return self
end

type Plant = typeof(Plant) & {
    Config: typeof(Plants.Basic),
    Net: typeof(Networker.server),
    Janitor: typeof(Janitor.new()),
    Id: number,
    Owner: Player,
    Pos: Vector3,
    Weight: number,
    Name: string,
    PlantTime: number,
    LastStage: number,
    FullyGrown: boolean,
    Destroyed: boolean,
    CropName: string,
    Crops: {[number]: Definitions.Crop},
    CropStages: {[number]: number},
    Saved: Definitions.Plant?
}

return Plant