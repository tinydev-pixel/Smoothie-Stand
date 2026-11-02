local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage.Source.Game.Data).server
local OfflineRewardsServiceServer = require(ServerScriptService.Features.OfflineRewards.OfflineRewardsServiceServer)
local Signals = require(ReplicatedStorage.Source.Game.Signals)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local ButtonsServiceServer = {}

local function destroyCropTool(container: Instance?, name: string, weight: number): boolean
    if not container then return false end

    for _, item in container:GetChildren() do
        if item:IsA("Tool") and item.Name == name and item:GetAttribute("IsCrop") and item:GetAttribute("Weight") == weight then
            item:Destroy()
            return true
        end
    end

    return false
end

local function claimMoney(plr: Player)
    local data = Data[plr]
    if not data then return end

    local cashStorage = data.storage.cash()
    if cashStorage <= 0 then return end

    data.storage.cash(0)
    data.cash(function(cash)
        return cash + cashStorage
    end)
end

local function insertCorn(plr: Player)
    local data = Data[plr]
    if not data then return end

    local spaceLeft = data.upgrades.cornStorage() - data.storage.corn()
    if spaceLeft <= 0 then return end

    local crops = data.inventory.crops()
    local picked = {}
    local total = 0

    for i, crop in crops do
        if total + crop.Weight <= spaceLeft then
            total += crop.Weight
            table.insert(picked, i)
        end
    end

    for n = #picked, 1, -1 do
        local i = picked[n]
        local crop = crops[i]
        local name = crop.Name
        local weight = crop.Weight

        data.inventory.crops.Remove(i)
        data.storage.corn(function(corn)
            return corn + weight
        end)

        if not destroyCropTool(plr:FindFirstChildOfClass("Backpack"), name, weight) then
            destroyCropTool(plr.Character, name, weight)
        end
    end
end

function ButtonsServiceServer.btnActivated(self: ButtonsServiceServer, plr: Player, btnType: string)
    if not OfflineRewardsServiceServer:plrHasClaimed(plr) then 
        -- Notification
        return
    end
    if type(btnType) ~= "string" then return end

    if btnType == "ClaimMoney" then
        claimMoney(plr)
    elseif btnType == "InsertCorn" then
        insertCorn(plr)
    end
end

function ButtonsServiceServer.onPlrRemoving(self: ButtonsServiceServer, plr: Player)
    self.janitor:Remove(plr.UserId)
    OfflineRewardsServiceServer:onPlrRemoving(plr)
end

function ButtonsServiceServer.onPlrAdded(self: ButtonsServiceServer, plr: Player)
    Data.Service:waitForData(plr)
    OfflineRewardsServiceServer:onPlrAdded(plr)

    self.janitor:Add(
        task.spawn(function()            
            while plr.Parent == Players do
                local data = Data[plr]
                local cornStorage = data and data.storage.corn() or 0

                if OfflineRewardsServiceServer:plrHasClaimed(plr) and data and cornStorage > 0 then
                    local drained = math.min(cornStorage, data.upgrades.drainRate())

                    if drained > 0 then
                        data.storage.corn(function(corn)
                            return corn - drained
                        end)

                        data.storage.cash(function(cash)
                            return cash + drained
                        end)
                    end
                end

                task.wait(1)
            end
        end), true, plr.UserId
    )
end

function ButtonsServiceServer.Init(self: ButtonsServiceServer)
    self.Net = Networker.server.new("ButtonsService", self, {self.btnActivated})
    self.janitor = Janitor.new()

    Signals.plotAssigned:Connect(function(plr: Player, plotId: number)
        self.Net:fire(plr, "onPlotAssigned", plotId)
    end)

    Players.PlayerAdded:Connect(function(plr: Player)
        task.spawn(self.onPlrAdded, self, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr: Player)
        task.spawn(self.onPlrRemoving, self, plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(self.onPlrAdded, self, plr)
    end
end

type ButtonsServiceServer = typeof(ButtonsServiceServer) & {
    Net: typeof(Networker.server),
    janitor: typeof(Janitor.new())
}

return ButtonsServiceServer :: ButtonsServiceServer