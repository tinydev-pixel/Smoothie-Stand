local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OwnsGamepass = require(script.Parent.OwnsGamepass)
local Rebirths = require(ReplicatedStorage.Source.Game.Configurations.Rebirths)

return function(plr: Player, rebirths: number, cash: number): number
    local mult = Rebirths.getRewardValue(rebirths, "CashMultiplier") or 1
    mult *= OwnsGamepass(plr, "2xCash") and 2 or 1
    return cash * mult
end