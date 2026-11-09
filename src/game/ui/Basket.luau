local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetHUDObject = require(ReplicatedStorage.Source.Core.Platform.GetHUDObject)
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local Data = require(ReplicatedStorage.Source.Game.Data)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)

local Basket = {}

local function updateCounter(label: TextLabel, fruits: {string})
    local amt = 0 

    for _, fruit in fruits do
        local value = Fruits[fruit] and Fruits[fruit].Value
        if not value then continue end

        amt += value
    end

    label.Text = FormatNumber.Simple.FormatCompact(amt)
end

function Basket.Init()
    task.spawn(function()
        local basket = GetHUDObject("Basket")
        local label = basket and basket:FindFirstChild("Counter") or basket:WaitForChild("Counter", 5)
        if not label then return end

        Data.client.inventory.fruits.Changed(function(fruits: {string}, a1: {string}, a2: string?)
            updateCounter(label, fruits)
        end)

        updateCounter(label, Data.client.inventory.fruits())
    end)
end

type Basket = typeof(Basket)

return Basket :: Basket