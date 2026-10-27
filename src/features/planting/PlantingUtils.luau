local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crops = require(ReplicatedStorage.Source.Game.Configurations.Crops)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)

local MIN_SCALE = 0.5
local MAX_SCALE = 2

local PlantingUtils = {}

local function getGrowthStage(growTime: number, growthStages: number, startTime: number): number
    local progress = 1

    if growTime > 0 then
        progress = math.clamp((workspace:GetServerTimeNow() - startTime) / growTime, 0, 1)
    end

    return math.min(math.floor(progress * growthStages) + 1, growthStages)
end

function PlantingUtils.rollWeight(name: string, kind: string): number
    local config = if kind == "Plant" then Plants[name] else Crops[name]
    assert(config, "Weight config is missing for " .. name .. "!")

    local min = config.Weight.Min
    local average = config.Weight.Average
    local max = config.Weight.Max

    local total = 0

    for _ = 1, 5 do
        total += math.random()
    end

    local normalized = total / 5

    if normalized < 0.5 then
        return min + (average - min) * (normalized * 2)
    end

    return average + (max - average) * ((normalized - 0.5) * 2)
end

function PlantingUtils.getScale(kind: string, name: string, weight: number): number
    local config = if kind == "Plant" then Plants[name] else Crops[name]
    if not config or type(weight) ~= "number" then
        return 1
    end

    local average = config.Weight.Average
    if average <= 0 or weight <= 0 then
        return 1
    end

    return math.clamp((weight / average) ^ (1 / 3), MIN_SCALE, MAX_SCALE)
end

function PlantingUtils.getGrowthStageFromPlantTime(plantName: string, plantTime: number): number?
    local config = Plants[plantName]
    if not config then
        return nil
    end

    return getGrowthStage(config.GrowTime, config.GrowthStages, plantTime)
end

function PlantingUtils.getGrowthStageFromCropTime(cropName: string, spawnTime: number): number?
    local config = Crops[cropName]
    if not config then
        return nil
    end

    return getGrowthStage(config.GrowTime, config.GrowthStages, spawnTime)
end

type PlantingUtils = typeof(PlantingUtils)

return PlantingUtils :: PlantingUtils