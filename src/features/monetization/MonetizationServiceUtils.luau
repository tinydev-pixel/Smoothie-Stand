local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamepassIds = require(ReplicatedStorage.Source.Game.Assets.GamepassIds)
local ProductIds = require(ReplicatedStorage.Source.Game.Assets.ProductIds)

local MonetizationServiceUtils = {}

function MonetizationServiceUtils.getInfoFromName(givenName: string): (number?, string?)
    if typeof(givenName) ~= "string" then return nil, nil end

    local gamepassId = GamepassIds[givenName]
    if gamepassId then
        return gamepassId, "GamePass"
    end

    local productId = ProductIds[givenName]
    if productId then
        return productId, "Product"
    end

    return nil, nil
end

function MonetizationServiceUtils.getNameFromId(givenId: number): string?
    if typeof(givenId) ~= "number" then return nil end

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

    return nil
end

type MonetizationServiceUtils = typeof(MonetizationServiceUtils)

return MonetizationServiceUtils :: MonetizationServiceUtils