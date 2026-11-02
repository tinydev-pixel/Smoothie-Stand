local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local Loom = require(ReplicatedStorage.Source.Core.Utils.Loom)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local OfflineRewardsServiceClient = {}

function OfflineRewardsServiceClient.claimed(self: OfflineRewardsServiceClient)
    self.janitor:Cleanup()
    
    local frame = GetFrame("OfflineRewards")
    if frame then
        frame.Visible = false
    end
end

function OfflineRewardsServiceClient.displayAmount(self: OfflineRewardsServiceClient, claimAmount: number)
    local frame = GetFrame("OfflineRewards")
    local label = frame and frame:FindFirstChild("CashAmount") :: TextLabel
    local btn = frame and frame:FindFirstChild("ClaimBtn") :: GuiButton
    if not label or not btn then 
        warn("Offline Rewards Frame is missing, or hasn't loaded in yet!")
        self.net:fire("claim")
        return
    end

    label.Text = "$" .. FormatNumber.Simple.FormatCompact(claimAmount)
    frame.Visible = true
    Loom.Animate(frame)
    
    self.janitor:Add(
        btn.Activated:Connect(function(a0: InputObject, a1: number)
            self.net:fire("claim")
        end), "Disconnect"
    )
end

function OfflineRewardsServiceClient.Init(self: OfflineRewardsServiceClient)
    self.net = Networker.client.new("OfflineRewardsService", self)
    self.janitor = Janitor.new()
end

type OfflineRewardsServiceClient = typeof(OfflineRewardsServiceClient) & {
    net: typeof(Networker.client),
    janitor: typeof(Janitor.new())
}

return OfflineRewardsServiceClient :: OfflineRewardsServiceClient