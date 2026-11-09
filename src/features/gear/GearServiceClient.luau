local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Components = script.Parent.Components

local GearServiceClient = {}

function GearServiceClient.unequipped(self: GearServiceClient, name: string)
    local m = Components:FindFirstChild(name)
    if m then
        require(m).unequipped()
    end
end

function GearServiceClient.equipped(self: GearServiceClient, name: string)
    local m = Components:FindFirstChild(name)
    if m then
        require(m).equipped(self.net)
    end
end

function GearServiceClient.Init(self: GearServiceClient)
    self.net = Networker.client.new("GearService", self)
end

type GearServiceClient = typeof(GearServiceClient) & {
    net: typeof(Networker.client)
}

return GearServiceClient :: GearServiceClient