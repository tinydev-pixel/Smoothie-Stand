local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Seeds = require(ReplicatedStorage.Source.Game.Configurations.Seeds)

local MIN_SCALE = 0.5
local MAX_SCALE = 2

local PlantingUtils = {}

local function getGrowthStage(growTime: number, growthStages: number, startTime: number, speed: number?): number
    local progress = 1

    if growTime > 0 then
        local elapsed = (workspace:GetServerTimeNow() - startTime) * (speed or 1)
        progress = math.clamp(elapsed / growTime, 0, 1)
    end

    return math.min(math.floor(progress * growthStages), growthStages)
end

function PlantingUtils.toPlotPosition(plotCFrame: CFrame, worldPos: Vector3): Vector3
    return plotCFrame:PointToObjectSpace(worldPos)
end

function PlantingUtils.toWorldCFrame(plotCFrame: CFrame, plotPos: Vector3): CFrame
    return plotCFrame * CFrame.new(plotPos)
end

function PlantingUtils.rollWeight(plantName: string): number
    local config = Plants[plantName]
    assert(config, "Weight config is missing for " .. plantName .. "!")

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

function PlantingUtils.getScale(plantName: string, weight: number): number
    local config = Plants[plantName]
    if not config or type(weight) ~= "number" then
        return 1
    end

    local average = config.Weight.Average
    if average <= 0 or weight <= 0 then
        return 1
    end

    return math.clamp((weight / average) ^ (1 / 3), MIN_SCALE, MAX_SCALE)
end

function PlantingUtils.getFruitValue(fruitName: string): number
    local config = Fruits[fruitName]
    return config and config.Value or 0
end

function PlantingUtils.getGrowthStageFromPlantTime(plantName: string, plantTime: number, speed: number?): number?
    local config = Plants[plantName]
    if not config then
        return nil
    end

    return getGrowthStage(config.GrowTime, config.GrowthStages, plantTime, speed)
end

function PlantingUtils.getGrowthStageFromFruitTime(fruitName: string, spawnTime: number, speed: number?): number?
    local config = Fruits[fruitName]
    if not config then
        return nil
    end

    return getGrowthStage(config.GrowTime, config.GrowthStages, spawnTime, speed)
end

function PlantingUtils.isSeed(name: string?): boolean
    if not name then
        return false
    end

    local seedName = name:gsub(" Seed", "")
    return table.find(Seeds.Order, seedName) ~= nil
end

function PlantingUtils.scaleCFrame(cframe: CFrame, scale: number): CFrame
    return CFrame.new(cframe.Position * scale) * cframe.Rotation
end

type PlantingUtils = typeof(PlantingUtils)

return PlantingUtils :: PlantingUtils