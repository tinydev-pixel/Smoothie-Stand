local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Plant = {}
Plant.__index = Plant

function Plant.connectGrowthLoop(self: Plant)
    self.Janitor:Add(
        task.spawn(function()
            while true do
                local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime)
                if stage ~= self.LastStage then
                    self.Net:fireAll("updatePlant", self.Id, self.Name, stage)
                    self.LastStage = stage
                end

                task.wait(1)
            end
        end), true
    )
end

function Plant.destroy(self: Plant)
    self.Janitor:Cleanup()
end

function Plant.new(net: typeof(Networker.server), farmer: Player, id: number, plantName: string, pos: Vector3, weight: number, plantTime: number, replicate: boolean?)
    local self: Plant = setmetatable({}, Plant)

    self.Net = net
    self.Janitor = Janitor.new()
    self.Id = id
    self.Owner = farmer
    self.Pos = pos
    self.Weight = weight
    self.Name = plantName
    self.PlantTime = plantTime
    self.LastStage = 1

    self:connectGrowthLoop()

    return self
end

type Plant = typeof(Plant) & {
    Janitor: typeof(Janitor.new()),
    Net: typeof(Networker.server),
    Id: number,
    Owner: Player,
    Pos: Vector3,
    Weight: number,
    Name: string,
    PlantTime: number,
    LastStage: number,
}

return Plant 