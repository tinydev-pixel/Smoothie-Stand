local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Plant = {}
Plant.__index = Plant

function Plant.new(net: typeof(Networker.server), farmer: Player, plantName: string, pos: Vector3, weight: number)
    local self = setmetatable({}, Plant)

    self.Net = net

    return self
end

type Plant = typeof(Plant)

return Plant :: Plant