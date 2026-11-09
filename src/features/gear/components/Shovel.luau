local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor).new()
local PlantingClient = require(ReplicatedStorage.Source.Features.Planting.PlantingClient)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local RAY_LENGTH = 500

local currentPlant: Model? = nil

local Shovel = {}

local function createHighlight(): Highlight
    local h = Janitor:Add(Instance.new("Highlight"), "Destroy", "Highlight")
    h.FillColor = Color3.new(0.913725, 0.039216, 0.039216)
    h.FillTransparency = 0.5
    h.OutlineTransparency = 1

    return h
end

local function findPlantModel(target: Instance?): Model?
    local current = target

    while current and current ~= workspace do
        if current:IsA("Model") and current:GetAttribute("PlantId") then
            return current
        end

        current = current.Parent
    end

    return nil
end

local function getOwnedPlantAt(position: Vector2): Model?
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}

    local ray = camera:ViewportPointToRay(position.X, position.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
    if not result then return nil end

    local model = findPlantModel(result.Instance)
    if model and PlantingClient:ownsPlant(model) then
        return model
    end

    return nil
end

local function select(model: Model?)
    if model == currentPlant then return end
    currentPlant = model

    Janitor:Remove("Highlight")

    if model then
        createHighlight().Parent = model
    end
end

function Shovel.equipped(net: typeof(Networker.client))
    Janitor:Add(
        RunService.Heartbeat:Connect(function()
            if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then return end

            if currentPlant and not currentPlant:IsDescendantOf(workspace) then
                select(nil)
            end

            local model = findPlantModel(Mouse.Target)
            if model and not PlantingClient:ownsPlant(model) then
                model = nil
            end

            select(model)
        end)
    )

    Janitor:Add(
        UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
            if gpe then return end

            local isTouch = input.UserInputType == Enum.UserInputType.Touch
            local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
            if not isTouch and not isClick then return end

            if isTouch then
                local model = getOwnedPlantAt(Vector2.new(input.Position.X, input.Position.Y))

                if model and model == currentPlant then
                    local plantId = model:GetAttribute("PlantId")
                    select(nil)
                    net:fire("deletePlant", plantId)
                else
                    select(model)
                end

                return
            end

            if currentPlant then
                local plantId = currentPlant:GetAttribute("PlantId")
                select(nil)
                net:fire("deletePlant", plantId)
            end
        end)
    )
end

function Shovel.unequipped()
    currentPlant = nil
    Janitor:Cleanup()
end

return Shovel