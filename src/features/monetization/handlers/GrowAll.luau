local ServerScriptService = game:GetService("ServerScriptService")
local PlantingServer = require(ServerScriptService.Features.Planting.PlantingServer)

return function(plr: Player)
    PlantingServer:growAll(plr)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end