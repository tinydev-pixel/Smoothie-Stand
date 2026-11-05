local ServerScriptService = game:GetService("ServerScriptService")
local OfflineRewardsServiceServer = require(ServerScriptService.Features.OfflineRewards.OfflineRewardsServiceServer)

return function(plr: Player)
    if not OfflineRewardsServiceServer.claimAmounts[plr.UserId] then return Enum.ProductPurchaseDecision.NotProcessedYet end

    OfflineRewardsServiceServer.claimAmounts[plr.UserId] *= 2
    OfflineRewardsServiceServer:claim(plr)

    return Enum.ProductPurchaseDecision.PurchaseGranted
end