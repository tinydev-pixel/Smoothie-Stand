local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local GetRarityGradient = require(ReplicatedStorage.Source.Core.Platform.GetRarityGradient)
local ImageIds = require(ReplicatedStorage.Source.Game.Assets.ImageIds)
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local Data = require(ReplicatedStorage.Source.Game.Data)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)

local IndexTemplate = ReplicatedStorage.Assets.UI.IndexTemplate

local IndexServiceClient = {}

function IndexServiceClient.newEntry(self: IndexServiceClient, name: string, cont: ScrollingFrame)
    local clone = IndexTemplate:Clone()
    clone.Name = name
    clone.FruitImage.Image = ImageIds[name] or ""
    clone.FruitImage.ImageColor3 = Color3.new(0, 0, 0)
    clone.ValueLabel.Text = "???"

    local rarity = Fruits[name] and Fruits[name].Rarity
    if rarity then
        local gradient = Instance.new("UIGradient") 
        gradient.Color = GetRarityGradient(rarity)
        gradient.Parent = clone.ValueLabel
    end

    clone.Parent = cont
end

function IndexServiceClient.setAsDiscovered(self: IndexServiceClient, name: string, cont: ScrollingFrame)
    local clone = cont:FindFirstChild(name)
    if not clone then return end

    local value = Fruits[name] and Fruits[name].Value
    if not value then return end

    clone.ValueLabel.Text = FormatNumber.Simple.FormatCompact(value)
    clone.FruitImage.ImageColor3 = Color3.new(1, 1, 1)
end

function IndexServiceClient.Init(self: IndexServiceClient)
    task.spawn(function()
        local frame = GetFrame("Index") 
        local cont = frame and (frame:FindFirstChild("Scrolling") or frame:WaitForChild("Scrolling", 5))
        if not cont then return end

        for name, info in Fruits do
            task.spawn(self.newEntry, self, name, cont)
        end

        Data.client.index.OnInsert(function(name: string, a1: number?)
            self:setAsDiscovered(name, cont)
        end)

        for _, name in Data.client.index() do
            task.spawn(self.setAsDiscovered, self, name, cont)
        end
    end)
end

type IndexServiceClient = typeof(IndexServiceClient)

return IndexServiceClient