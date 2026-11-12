local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetHUDObject = require(ReplicatedStorage.Source.Core.Platform.GetHUDObject)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)
local Currency = require(ReplicatedStorage.Source.Game.UI.Classes.Currency)

return {
    Init = function()   
        task.spawn(function()
            local currencies = GetHUDObject("Currencies")
            local cashLabel = currencies and (currencies:FindFirstChild("Cash") or currencies:WaitForChild("Cash", 5))
            local rebirthsLabel = currencies and (currencies:FindFirstChild("Rebirths") or currencies:WaitForChild("Rebirths", 5))

            if cashLabel then
                task.spawn(Currency.new, cashLabel, "cash", nil, "$", nil, SoundIds.ChaChing)
            end

            if rebirthsLabel then
                task.spawn(Currency.new, rebirthsLabel, "rebirths", nil, nil, " Rebirths")
            end
        end)
    end
}