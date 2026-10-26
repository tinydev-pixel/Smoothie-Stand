local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Plant = {}
Plant.__index = Plant

local function saveToData(plr: Player, plantName: string, pos: Vector3, weight: number)
    local serPos = Serialize.SerializeVector3(pos)

    
end

function Plant.new(net: typeof(Networker.server), farmer: Player, plantName: string, pos: Vector3, weight: number)
    local self: Plant = setmetatable({}, Plant)

    --[[ 
        First thing, the plant should be saved to the player's data
        Second, the plant should be replicated to all clients
        Third, the plant should be constantly updated and when fully grown, including the growth of crops
    ]]

    

    return self
end

type Plant = typeof(Plant) & {
    Net: typeof(Networker.server),
    Owner: Player,
    Model: Model,
    Name: string
}

return Plant 