local RunService = game:GetService("RunService")

return function(plr: Player, name: string)
    local t = {}
    if RunService:IsServer() then
        t = require(game.ServerScriptService.Features.Monetization.MonetizationServiceServer).ownedGamepasses[plr.UserId]
    else
        t = require(game.ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient).ownedGamepasses[plr.UserId]
    end

    return table.find(t, name)
end