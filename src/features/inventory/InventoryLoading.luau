local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Source.Game.Data).server

local SeedTools = ReplicatedStorage.Assets.Seeds.Tools

local InventoryLoading = {}

local function loadSeeds(self: InventoryLoading, backpack: Backpack, seeds: {string})
    for _, seed in seeds do
        local tool = SeedTools:FindFirstChild(seed .. " Seed")
        if tool and tool:IsA("Tool") then
            tool:Clone().Parent = backpack
        end
    end
end

function InventoryLoading.load(self: InventoryLoading, plr: Player)
    local data = Data[plr] or Data.Service:waitForData(plr)
    if not data then return end

    local backpack = plr:FindFirstChildOfClass("Backpack") or plr:WaitForChild("Backpack", 5)
    if not backpack then
        warn("Backpack failed to load for player " .. plr.UserId .. "!")
        return
    end

    loadSeeds(self, backpack, data.inventory.seeds())
end

function InventoryLoading.onPlrAdded(self: InventoryLoading, plr: Player)
    plr.CharacterAdded:Connect(function()
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