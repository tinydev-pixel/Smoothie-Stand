local Rebirths = {}

Rebirths.Data = {
    {
        Rewards = {
            {
                Type = "CashMultiplier",
                Value = 2
            },
            {
                Type = "GardenLevel",
                Value = 2
            }
        },
        Price = 1 --1_000
    },
    {
        Rewards = {
            {
                Type = "CashMultiplier",
                Value = 5
            },
            {
                Type = "GardenLevel",
                Value = 3
            }
        },
        Price = 1 --50_000
    },
    {
        Rewards = {
            {
                Type = "CashMultiplier",
                Value = 10
            },
            {
                Type = "GardenLevel",
                Value = 4
            }
        },
        Price = 1 --1_000_000
    },
    {
        Rewards = {
            {
                Type = "CashMultiplier",
                Value = 20
            },
            {
                Type = "GardenLevel",
                Value = 5
            }
        },
        Price = 1 --100_000_000
    }
}

function Rebirths.getRewardValue(rebirths: number, rewardType: string): number?
    local rebirth = Rebirths.Data[rebirths]
    if not rebirth then return end

    for _, reward in rebirth.Rewards do
        if reward.Type == rewardType then
            return reward.Value
        end
    end

    return 
end

return Rebirths