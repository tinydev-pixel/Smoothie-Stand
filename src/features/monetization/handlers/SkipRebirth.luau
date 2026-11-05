local ServerScriptService = game:GetService("ServerScriptService")
local RebirthsServiceServer = require(ServerScriptService.Features.Rebirths.RebirthsServiceServer)

return function(plr: Player)
    RebirthsServiceServer:rebirthConfirmed(plr)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end