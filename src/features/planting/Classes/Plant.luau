local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local Crops = require(ReplicatedStorage.Source.Game.Configurations.Crops)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local PlantModels = ReplicatedStorage.Assets.Plants
local CropTools = ReplicatedStorage.Assets.Crops.Tools
local MAX_HARVEST_DISTANCE = 25
local spawnOffsets: {[string]: {CFrame}} = {}

local Plant = {}
Plant.__index = Plant

local function getGrowthSpeed(plr: Player): number
    if plr:GetAttribute("2xGrowthSpeed") then
        return 2
    end

    return 1
end

local function isFullyGrown(self: Plant, stage: number?): boolean
    return stage ~= nil and stage >= self.Config.GrowthStages
end

local function toNetCrop(self: Plant, crop: Definitions.Crop): Definitions.Crop
    local copy = table.clone(crop)
    copy.CFrame = Serialize.SerializeCFrame(self.CFrame * Serialize.UnserializeCFrame(crop.CFrame))
    return copy
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

local function giveCropTool(backpack: Backpack, crop: Definitions.Crop)
    local template = CropTools:FindFirstChild(crop.Name)
    if not template or not template:IsA("Tool") then
        warn("Crop tool is missing for " .. crop.Name .. "!")
        return
    end

    local tool = template:Clone()
    PlantingUtils.scaleCrop(tool, "Crop", crop.Name, crop.Weight)
    tool:SetAttribute("IsCrop", true)
    tool:SetAttribute("Weight", crop.Weight)
    tool.Parent = backpack
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
    local speed = getGrowthSpeed(self.Owner)

    for slot, crop in self.Crops do
        local stage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime, speed)

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

    for _ = 1, missing do
        local slot = table.remove(free, math.random(#free))
        local crop: Definitions.Crop = {
            Name = self.CropName,
            SpawnTime = workspace:GetServerTimeNow(),
            Weight = PlantingUtils.rollWeight(self.CropName, "Crop"),
            Slot = slot,
            CFrame = Serialize.SerializeCFrame(PlantingUtils.scaleCFrame(offsets[slot], self.Scale))
        }

        self.Crops[slot] = crop
        self.CropStages[slot] = 0
        self.Net:fireAll("spawnCrop", self.Id, toNetCrop(self, crop))
    end

    saveCrops(self)
end

local function collectCrop(self: Plant, plr: Player, slot: number): boolean
    local crop = self.Crops[slot]
    if not crop then return false end

    local config = Crops[crop.Name]
    if not config then return false end

    local stage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime, getGrowthSpeed(plr))
    if not stage or stage < config.GrowthStages then return false end

    local data = Data[plr]
    local backpack = plr:FindFirstChildOfClass("Backpack")
    if not data or not backpack then return false end

    self.Crops[slot] = nil
    self.CropStages[slot] = nil
    saveCrops(self)

    self.Net:fireAll("deleteCrop", self.Id, slot)

    data.inventory.crops.Insert({
        Name = crop.Name,
        Weight = crop.Weight
    })

    giveCropTool(backpack, crop)

    return true
end

local function autoHarvest(self: Plant)
    if not self.Owner:GetAttribute("AutoHarvest") then return end

    local slots = {}

    for slot in self.Crops do
        table.insert(slots, slot)
    end

    for _, slot in slots do
        collectCrop(self, self.Owner, slot)
    end
end

function Plant.harvestCrop(self: Plant, plr: Player, slot: number)
    if self.Destroyed or plr ~= self.Owner then return end

    local crop = self.Crops[slot]
    if not crop then return end

    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local cropPos = (self.CFrame * Serialize.UnserializeCFrame(crop.CFrame)).Position
    if (root.Position - cropPos).Magnitude > MAX_HARVEST_DISTANCE then return end

    collectCrop(self, plr, slot)
end

function Plant.update(self: Plant)
    if self.Destroyed then return end

    if not self.FullyGrown then
        local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime, getGrowthSpeed(self.Owner))
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
    autoHarvest(self)
    spawnCrops(self)
end

function Plant.canGrow(self: Plant): boolean
    if self.Destroyed then return false end

    local speed = getGrowthSpeed(self.Owner)

    if not self.FullyGrown then
        local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime, speed)

        if not isFullyGrown(self, stage) then
            return true
        end
    end

    for _, crop in self.Crops do
        local config = Crops[crop.Name]
        local stage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime, speed)

        if config and stage and stage < config.GrowthStages then
            return true
        end
    end

    return false
end

function Plant.growNow(self: Plant)
    if self.Destroyed then return end

    self.PlantTime = 0

    if self.Saved then
        self.Saved.PlantTime = 0
    end

    self:update()

    for _, crop in self.Crops do
        crop.SpawnTime = 0
    end

    saveCrops(self)
    updateCrops(self)
    autoHarvest(self)
end

function Plant.setSaved(self: Plant, saved: Definitions.Plant)
    self.Saved = saved
    saveCrops(self)
end

function Plant.snapshot(self: Plant): Definitions.PlantSnapshot
    local crops = {}

    for _, crop in self.Crops do
        table.insert(crops, toNetCrop(self, crop))
    end

    return {
        Id = self.Id,
        OwnerId = self.Owner.UserId,
        Name = self.Name,
        PlantTime = self.PlantTime,
        Weight = self.Weight,
        CFrame = Serialize.SerializeCFrame(self.CFrame),
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

function Plant.new(net: typeof(Networker.server), farmer: Player, id: number, plantName: string, cframe: CFrame, weight: number, plantTime: number, crops: {Definitions.Crop}?, saved: Definitions.Plant?)
    local config = Plants[plantName]
    assert(config, "Plant config is missing for " .. plantName .. "!")

    local self: Plant = setmetatable({}, Plant)
    local speed = getGrowthSpeed(farmer)
    local stage = PlantingUtils.getGrowthStageFromPlantTime(plantName, plantTime, speed)

    self.Config = config
    self.Net = net
    self.Janitor = Janitor.new()
    self.Id = id
    self.Owner = farmer
    self.CFrame = cframe
    self.Pos = cframe.Position
    self.Weight = weight
    self.Scale = PlantingUtils.getScale("Plant", plantName, weight)
    self.Name = plantName
    self.PlantTime = plantTime
    self.LastStage = stage or 0
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
        local offsets = getSpawnOffsets(plantName)

        for _, crop in crops do
            local cropStage = PlantingUtils.getGrowthStageFromCropTime(crop.Name, crop.SpawnTime, speed)
            local validSlot = type(crop.Slot) == "number" and crop.Slot >= 1 and crop.Slot <= #offsets

            if cropStage and validSlot and not self.Crops[crop.Slot] then
                crop.CFrame = Serialize.SerializeCFrame(PlantingUtils.scaleCFrame(offsets[crop.Slot], self.Scale))
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
    CFrame: CFrame,
    Pos: Vector3,
    Weight: number,
    Scale: number,
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