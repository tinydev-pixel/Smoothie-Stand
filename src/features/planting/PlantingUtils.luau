local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crops = require(ReplicatedStorage.Source.Game.Configurations.Crops)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Seeds = require(ReplicatedStorage.Source.Game.Configurations.Seeds)

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

function PlantingUtils.isSeed(name: string): boolean
    if not name then return end

    local seedName = name:gsub(" Seed", "")
    return table.find(Seeds.Order, seedName) ~= nil
end

function PlantingUtils.scaleCFrame(cframe: CFrame, scale: number): CFrame
    return CFrame.new(cframe.Position * scale) * cframe.Rotation
end

function PlantingUtils.scaleCrop(tool: Tool, kind: string, name: string, weight: number)
    local scale = PlantingUtils.getScale(kind, name, weight)
    if scale == 1 then return end

    local handle = tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        warn("Crop tool " .. tool.Name .. " has no Handle, it cannot be scaled!")
        return
    end

    local rootCFrame = handle.CFrame
    local parts = {}
    local welds = {}

    for _, descendant in tool:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        elseif descendant:IsA("WeldConstraint") and descendant.Enabled then
            descendant.Enabled = false
            table.insert(welds, descendant)
        elseif descendant:IsA("JointInstance") then
            descendant.C0 = PlantingUtils.scaleCFrame(descendant.C0, scale)
            descendant.C1 = PlantingUtils.scaleCFrame(descendant.C1, scale)
        elseif descendant:IsA("Attachment") then
            descendant.Position *= scale
        elseif descendant:IsA("SpecialMesh") then
            descendant.Offset *= scale
        end
    end

    for _, part in parts do
        local relative = rootCFrame:ToObjectSpace(part.CFrame)

        part.Size *= scale
        part.CFrame = rootCFrame * PlantingUtils.scaleCFrame(relative, scale)
    end

    for _, weld in welds do
        weld.Enabled = true
    end

    tool.Grip = PlantingUtils.scaleCFrame(tool.Grip, scale)
end

type PlantingUtils = typeof(PlantingUtils)

return PlantingUtils :: PlantingUtils