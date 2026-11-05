local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamepassIds = require(ReplicatedStorage.Source.Game.Assets.GamepassIds)
local ProductIds = require(ReplicatedStorage.Source.Game.Assets.ProductIds)

local MonetizationServiceUtils = {}

function MonetizationServiceUtils.getInfoFromName(givenName: string): number? | string?
    if typeof(givenName) ~= "string" then return end

    for name, id in GamepassIds do
        if name == givenName then
            return id, "GamePass"
        end
    end

    for name, id in ProductIds do
        if name == givenName then
            return id, "Product"
        end
    end

    return 
end

function MonetizationServiceUtils.getNameFromId(givenId: number): string?
    if typeof(givenId) ~= "number" then return end

    for name, id in GamepassIds do
        if id == givenId then
            return name
        end
    end

    for name, id in ProductIds do
        if id == givenId then
            return name
        end
    end

    return 
end

type MonetizationServiceUtils = typeof(MonetizationServiceUtils)

return MonetizationServiceUtils :: MonetizationServiceUtils