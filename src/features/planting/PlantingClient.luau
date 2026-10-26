local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Spring = require(ReplicatedStorage.Packages.Spring)

local Mouse = Players.LocalPlayer:GetMouse()
local SeedModels = ReplicatedStorage.Assets.Seeds

local equipped = false

local PlantingClient = {}

function PlantingClient.unequipped(self: PlantingClient)
    if not equipped then return end
    equipped = false

    self.Janitor:Cleanup()
end

function PlantingClient.equipped(self: PlantingClient)
    if equipped then return end
    equipped = true

    self.Janitor:Add(
        UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
            if gpe then return end

            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                self.Net:fire("plant", Mouse.Hit.Position)
            end
        end), "Disconnect"
    )
end

function PlantingClient.playAnimation(self: PlantingClient, pos: Vector3, seedName: string)
    local model = SeedModels:FindFirstChild(seedName)
    if not model then
        warn("Seed model is missing for " .. seedName .. "!")
        return
    end

    local clone = model:Clone()
    local startPos = pos + Vector3.new(0, 5, 0)

    clone:PivotTo(CFrame.new(startPos))
    clone.Parent = workspace

    local posSpring = Spring.new(startPos, 0.8, 1)
    posSpring.Target = pos

    local rotation = Vector3.new(
        math.random() * math.pi,
        math.random() * math.pi,
        math.random() * math.pi
    )

    local rotSpring = Spring.new(rotation, 0.5, 0.6)
    rotSpring.Target = Vector3.zero

    local conn
    conn = RunService.Heartbeat:Connect(function()
        clone:PivotTo(
            CFrame.new(posSpring.Position)
                * CFrame.Angles(
                    rotSpring.Position.X,
                    rotSpring.Position.Y,
                    rotSpring.Position.Z
                )
        )

        if (posSpring.Position - posSpring.Target).Magnitude < 0.05 and rotSpring.Position.Magnitude < 0.05 then
            conn:Disconnect()
            clone:Destroy()
        end
    end)
end

function PlantingClient.Init(self: PlantingClient)
    self.Net = Networker.client.new("Planting", self)
    self.Janitor = Janitor.new()
end

type PlantingClient = typeof(PlantingClient) & {
    Net: typeof(Networker.client),
    Janitor: typeof(Janitor.new())
}

return PlantingClient :: PlantingClient