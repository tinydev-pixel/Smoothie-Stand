local DrainRateUpgrades = {}

local START_RATE = 1        -- rate players spawn with (level 0)
local RATE_GROWTH = 1.2     -- how fast the rate grows per level
local BASE_PRICE = 5        -- price of level 1
local PRICE_GROWTH = 1.2    -- how fast the price grows per level
local MAX_LEVEL = math.huge 

export type Upgrade = {Level: number, Rate: number, Price: number}

function DrainRateUpgrades.getRate(level: number): number
    return START_RATE + level + math.floor(RATE_GROWTH ^ level) - 1
end

function DrainRateUpgrades.getPrice(level: number): number
    if level <= 0 then return 0 end
    return math.floor(BASE_PRICE * PRICE_GROWTH ^ (level - 1))
end

function DrainRateUpgrades.getUpgrade(level: number): Upgrade
    return {
        Level = level,
        Rate = DrainRateUpgrades.getRate(level),
        Price = DrainRateUpgrades.getPrice(level),
    }
end

function DrainRateUpgrades.getLevel(rate: number): number
    local level = 0
    while level < MAX_LEVEL and DrainRateUpgrades.getRate(level + 1) <= rate do
        level += 1
    end
    
    return level
end

function DrainRateUpgrades.getNextUpgrade(rate: number): Upgrade?
    local nextLevel = DrainRateUpgrades.getLevel(rate) + 1
    if nextLevel > MAX_LEVEL then return end

    return DrainRateUpgrades.getUpgrade(nextLevel)
end

return DrainRateUpgrades