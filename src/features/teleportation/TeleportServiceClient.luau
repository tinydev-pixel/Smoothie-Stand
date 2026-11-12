local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetHUDObject = require(ReplicatedStorage.Source.Core.Platform.GetHUDObject)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local db = false
local cd = 0.3

local TeleportServiceClient = {}

function TeleportServiceClient.newBtn(self: TeleportServiceClient, btn: Instance)
    if not btn:IsA("GuiButton") or self.connected[btn] then return end
    self.connected[btn] = true

    btn.Activated:Connect(function()
        if db then return end
        db = true
        task.delay(cd, function()
            db = false
        end)

        self.net:fire("teleport", btn.Name)
    end)

    btn.Destroying:Once(function()
        self.connected[btn] = nil
    end)
end

function TeleportServiceClient.Init(self: TeleportServiceClient)
    self.net = Networker.client.new("TeleportService", self)
    self.connected = {}

    task.spawn(function()
        local cont = GetHUDObject("Teleportation")
        if not cont then return end

        cont.ChildAdded:Connect(function(btn: Instance)
            self:newBtn(btn)
        end)

        for _, btn in cont:GetChildren() do
            self:newBtn(btn)
        end
    end)
end

type TeleportServiceClient = typeof(TeleportServiceClient) & {
    net: typeof(Networker.client),
    connected: {[Instance]: boolean}
}

return TeleportServiceClient :: TeleportServiceClient