local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)
local Data = require(ReplicatedStorage.Source.Game.Data).client

local Currency = {}

local function onDataChanged(label: TextLabel, value: number | string, prefix: string?)
    label.Text = prefix or "" .. FormatNumber.Simple.FormatCompact(value)
end

function Currency.new(label: TextLabel, dataType: string, nestedDataType: string?, prefix: string?)
    if not label or not label:IsA("TextLabel") or not dataType or not Data[dataType] then return end

    if nestedDataType then
        if not Data[dataType][nestedDataType] then return end

        Data[dataType][nestedDataType].Changed(function(value)
            onDataChanged(label, value, prefix)
        end)
    else
        Data[dataType].Changed(function(value)
            onDataChanged(label, value, prefix)
        end)
    end
end

type Currency = typeof(Currency)

return Currency :: Currency