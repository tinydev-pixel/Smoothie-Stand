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
        local tool = CropTools:FindFirstChild(crop.Name)
        if tool then
            local clone = tool:Clone()
            PlantingUtils.scaleCrop(clone, "Crop", crop.Name, crop.Weight)
            clone:SetAttribute("IsCrop", true)
            clone:SetAttribute("Weight", crop.Weight)
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
    local data = Data[plr] or Data.Service:waitForData(plr)
    local backpack = plr.Backpack or plr:WaitForChild("Backpack", 5)
    if not backpack then 
        warn("Backpack failed to load for player " .. plr.UserId .. "!")
        return
    end

    loadSeeds(self, backpack, data.inventory.seeds())
    loadCrops(self, backpack, data.inventory.crops())
end

function InventoryLoading.onPlrAdded(self: InventoryLoading, plr: Player)
    plr.CharacterAdded:Connect(function(char: Model)
        self:load(plr)
    end)

    if plr.Character then
        self:load(plr)
    end
end

function InventoryLoading.Init(self: InventoryLoading)
    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(self.onPlrAdded, self, plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(self.onPlrAdded, self, plr)
    end
end

type InventoryLoading = typeof(InventoryLoading)

return InventoryLoading :: InventoryLoading