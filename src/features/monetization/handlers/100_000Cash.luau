local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Source.Game.Data).server

return function(plr: Player)
    Data[plr].cash(function(cash)
        return cash + 100_000
    end)

    return Enum.ProductPurchaseDecision.PurchaseGranted
end