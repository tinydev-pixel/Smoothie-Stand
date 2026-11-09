local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local ButtonsServiceServer = require(ServerScriptService.Features.Buttons.ButtonsServiceServer)

return function(plr: Player)
    ButtonsServiceServer:process(plr, Data[plr].storage.fruits())
    return Enum.ProductPurchaseDecision.PurchaseGranted
end