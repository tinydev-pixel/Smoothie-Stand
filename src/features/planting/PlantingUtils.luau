local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Seeds = require(ReplicatedStorage.Source.Game.Configurations.Seeds)

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

function PlantingUtils.getFruitValue(fruitName: string): number
    local config = Fruits[fruitName]
    return config and config.Value or 0
end

function PlantingUtils.isSingleHarvest(plantName: string): boolean
    local config = Plants[plantName]
    return config ~= nil and config.SingleHarvest == true
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

type PlantingUtils = typeof(PlantingUtils)

return PlantingUtils :: PlantingUtils