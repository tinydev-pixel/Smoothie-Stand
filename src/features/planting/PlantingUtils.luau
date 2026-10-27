local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crops = require(ReplicatedStorage.Source.Game.Configurations.Crops)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)

local PlantingUtils = {}

function PlantingUtils.rollWeight(name: string, type: string): number
	local config = (type == "Plant") and Plants[name].Weight or Crops[name].Weight
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

function PlantingUtils.getGrowthStageFromPlantTime(plantName: string, plantTime: number): number?
	local config = Plants[plantName]
	if not config then
		return nil
	end

	local growTime = config.GrowTime
	local growthStages = config.GrowthStages
	local timePassed = workspace:GetServerTimeNow() - plantTime
	local progress = math.clamp(timePassed / growTime, 0, 1)
	local stage = math.floor(progress * growthStages) + 1

	return math.min(stage, growthStages)
end

type PlantingUtils = typeof(PlantingUtils)

return PlantingUtils :: PlantingUtils