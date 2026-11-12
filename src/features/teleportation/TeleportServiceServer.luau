local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlotServer = require(ServerScriptService.Features.Plots.PlotServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local Plaza = workspace.Map.Plaza
local SeedShop = Plaza:FindFirstChild("SeedShop")
local UpdateArea = Plaza:FindFirstChild("Updates")

local cd = 0.3

local TeleportServiceServer = {}

local function getTarget(plr: Player, location: string): CFrame?
    if location == "Plot" then
        return PlotServer:getSpawnCFrame(plr)
    elseif location == "SeedShop" then
        local p = SeedShop:FindFirstChild("TeleportPart")
        return p and p.CFrame
    elseif location == "Event" then
        local p = UpdateArea:FindFirstChild("TeleportPart")
        return p and p.CFrame
    end

    return nil
end

function TeleportServiceServer.teleport(self: TeleportServiceServer, plr: Player, location: string)
    if typeof(location) ~= "string" or self.cooldown[plr.UserId] then return end

    local target = getTarget(plr, location)
    if not target then return end

    local character = plr.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then return end

    self.cooldown[plr.UserId] = true
    task.delay(cd, function()
        self.cooldown[plr.UserId] = nil
    end)

    character:PivotTo(target)

    TutorialServiceServer:onTeleported(plr, location)
end

function TeleportServiceServer.Init(self: TeleportServiceServer)
    self.net = Networker.server.new("TeleportService", self, {self.teleport})
    self.cooldown = {}

    Players.PlayerRemoving:Connect(function(plr: Player)
        self.cooldown[plr.UserId] = nil
    end)
end

type TeleportServiceServer = typeof(TeleportServiceServer) & {
    net: typeof(Networker.server),
    cooldown: {[number]: boolean}
}

return TeleportServiceServer :: TeleportServiceServer