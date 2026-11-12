local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Source.Game.Data).server

local SeedTools = ReplicatedStorage.Assets.Seeds.Tools

return function(plr: Player, name: string)
    local seedName = (name:gsub(" Seed", ""))

    local data = Data[plr]
    if not data then
        warn("Player " .. plr.UserId .. " is missing data at the time of purchase!")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local template = SeedTools:FindFirstChild(seedName .. " Seed") 
    if not template or not template:IsA("Tool") then
        warn("Tool is missing for seed " .. seedName .. "!")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local backpack = plr:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("Player " .. plr.UserId .. " is missing a backpack at the time of purchase!")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    data.inventory.seeds.Insert(seedName)

    local tool = template:Clone()
    tool.Name = template.Name
    tool.Parent = backpack

    return Enum.ProductPurchaseDecision.PurchaseGranted
end