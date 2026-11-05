local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Info = require(ReplicatedStorage.Source.Game.Assets.Info)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)

local rewardTimer = 600

local GroupRewardsServiceServer = {}

function GroupRewardsServiceServer.onPlrRemoving(self: GroupRewardsServiceServer, plr: Player)
    self.janitor:Remove(plr.UserId)
    self.janitor:Remove(plr.UserId .. "Data")
    self.mostGained[plr.UserId] = nil
end

function GroupRewardsServiceServer.onPlrAdded(self: GroupRewardsServiceServer, plr: Player)
    self.janitor:Add(
        task.spawn(function()
            while plr and plr.Parent == Players do
                local amount = self.mostGained[plr.UserId]
                if amount then
                    Data[plr].groupRewards(function(currentAmount)
                        return currentAmount + amount
                    end)
                end

                task.wait(rewardTimer)
            end
        end), true, plr.UserId
    )

    self.janitor:Add(
        Data[plr].storage.cash.Changed(function(cashStorage: number, a1: number, a2: string?)
            local amount = (self.mostGained[plr.UserId] or 0) + cashStorage
            self.mostGained[plr.UserId] = amount
        end), true, plr.UserId .. "Data"
    )
end

function GroupRewardsServiceServer.claim(self: GroupRewardsServiceServer, plr: Player)
    local s, r = pcall(function(...)
        return plr:IsInGroupAsync(Info.groupId)
    end)
    if not s or not r then return end

    local groupRewards = Data[plr].groupRewards()
    if groupRewards == 0 then return end

    Data[plr].cash(function(cash)
        return cash + groupRewards
    end)

    Data[plr].groupRewards(0)
end

function GroupRewardsServiceServer.Init(self: GroupRewardsServiceServer)
    self.janitor = Janitor.new()
    self.mostGained = {}
end

type GroupRewardsServiceServer = typeof(GroupRewardsServiceServer) & {
    janitor: typeof(Janitor.new()),
    mostGained: {[number]: number}
}

return GroupRewardsServiceServer :: GroupRewardsServiceServer