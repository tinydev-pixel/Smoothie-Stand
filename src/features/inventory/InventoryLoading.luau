local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)
local Data = require(ReplicatedStorage.Source.Game.Data).server

local SeedTools = ReplicatedStorage.Assets.Seeds.Tools
local CropTools = ReplicatedStorage.Assets.Crops.Tools

local InventoryLoading = {}

local function loadCrops(self: InventoryLoading, backpack: Backpack, crops: {Definitions.InventoryCrop})
    for _, crop in crops do
        local tool = CropTools:FindFirstChild(crop)
        if tool then
            local clone = tool:Clone()
            PlantingUtils.scaleCrop(clone, "Crop", crop.Name, crop.Weight)
            clone.Parent = backpack
        end
    end
end

local function loadSeeds(self: InventoryLoading, backpack: Backpack, seeds: {string})
    for _, seed in seeds do
        local tool = SeedTools:FindFirstChild(seed .. " Seed")
        if tool then
            tool:Clone().Parent = backpack
        end
    end
end

function InventoryLoading.load(self: InventoryLoading, plr: Player)
    local data = Data.Service:waitForData(plr)
    local backpack = plr.Backpack or plr:WaitForChild("Backpack", 5)
    if not backpack then 
        warn("Backpack failed to load for player" .. plr.UserId .. "!")
        return
    end

    loadSeeds(self, backpack, data.inventory.seeds)
    loadCrops(self, backpack, data.inventory.crops)
end

function InventoryLoading.Init(self: InventoryLoading)
    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(self.load, plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(self.load, plr)
    end
end

type InventoryLoading = typeof(InventoryLoading)

return InventoryLoading :: InventoryLoading