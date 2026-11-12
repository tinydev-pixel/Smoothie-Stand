local ServerScriptService = game:GetService("ServerScriptService")
local SeedShopServiceServer = require(ServerScriptService.Features.SeedShop.SeedShopServiceServer)

return function(plr: Player)
    SeedShopServiceServer:restock()
    return Enum.ProductPurchaseDecision.PurchaseGranted
end