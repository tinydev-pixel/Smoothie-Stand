local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local OfflineRewardsServiceServer = {}

function OfflineRewardsServiceServer.onPlrRemoving(self: OfflineRewardsServiceServer, plr: Player)
    self.claimAmounts[plr.UserId] = nil
end

function OfflineRewardsServiceServer.onPlrAdded(self: OfflineRewardsServiceServer, plr: Player)
    local data = Data[plr]
    local drainRate = data.upgrades.drainRate()
    local fruits = data.storage.fruits()
    local lastLogin = data.lastLogin()
    local timePassed = workspace:GetServerTimeNow() - lastLogin
    local claimAmount = math.min(timePassed * drainRate, fruits)
    if claimAmount <= 0 then return end

    self.claimAmounts[plr.UserId] = claimAmount
    self.net:fire(plr, "displayAmount", claimAmount)
end

function OfflineRewardsServiceServer.plrHasClaimed(self: OfflineRewardsServiceServer, plr: Player): boolean
    return self.claimAmounts[plr.UserId] == nil
end

function OfflineRewardsServiceServer.claim(self, plr: Player)
    local claimAmount = self.claimAmounts[plr.UserId]
    if not claimAmount then return end

    Data[plr].storage.fruits(function(fruits: number)
        return math.max(fruits - claimAmount, 0)
    end)

    Data[plr].cash(function(cash)
        return cash + claimAmount
    end)
    
    self.claimAmounts[plr.UserId] = nil

    Data.Service:addPlayerRemovingCallback(function(plr: Player, data)
        data.lastLogin = workspace:GetServerTimeNow()
    end)

    self.net:fire(plr, "claimed")
end

function OfflineRewardsServiceServer.Init(self: OfflineRewardsServiceServer)
    self.net = Networker.server.new("OfflineRewardsService", self, {self.claim})
    self.claimAmounts = {}
end

type OfflineRewardsServiceServer = typeof(OfflineRewardsServiceServer) & {
    net: typeof(Networker.server),
    claimAmounts: {[number]: number}
}

return OfflineRewardsServiceServer :: OfflineRewardsServiceServer