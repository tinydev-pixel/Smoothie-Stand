local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PlaySoundInSpace = require(ReplicatedStorage.Source.Core.Platform.PlaySoundInSpace)
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)
local FruitConfigs = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local PlantConfigs = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)
local Spring = require(ReplicatedStorage.Source.Packages.Spring)
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)

local LocalPlayer = Players.LocalPlayer
local SeedModels = ReplicatedStorage.Assets.Seeds.Models
local PlantModels = ReplicatedStorage.Assets.Plants
local FruitModels = ReplicatedStorage.Assets.Fruits
local RAY_LENGTH = 500
local PIN_DURATION = 4
local SFX_LIFETIME = 5
local NAME_SUFFIX = " Plant"

local PlantFolder = Instance.new("Folder")
PlantFolder.Name = "ClientPlants"
PlantFolder.Parent = workspace

local hoverParams = RaycastParams.new()
hoverParams.FilterType = Enum.RaycastFilterType.Include
hoverParams.FilterDescendantsInstances = {PlantFolder}

local equipped = false
local touchMode = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local PlantingClient = {}

local function playSfxAt(soundId: any, position: Vector3)
    local emitter = Instance.new("Part")
    emitter.Name = "SfxEmitter"
    emitter.Size = Vector3.one
    emitter.Transparency = 1
    emitter.Anchored = true
    emitter.CanCollide = false
    emitter.CanQuery = false
    emitter.CanTouch = false
    emitter.CFrame = CFrame.new(position)
    emitter.Parent = PlantFolder

    PlaySoundInSpace(soundId, emitter)

    task.delay(SFX_LIFETIME, function()
        emitter:Destroy()
    end)
end

local function tagModel(model: Model, plantId: number, ownerId: number, slot: number?)
    model:SetAttribute("PlantId", plantId)
    model:SetAttribute("OwnerId", ownerId)

    if slot then
        model:SetAttribute("Slot", slot)
    end
end

local function getGroundPosition(screenPos: Vector2): Vector3?
    local camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local filter: {Instance} = {PlantFolder}
    local character = LocalPlayer.Character
    if character then
        table.insert(filter, character)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter

    local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)

    return result and result.Position
end

local function getStageModel(models: Instance, name: string, stage: number): Model?
    local container = models:FindFirstChild(name)
    local model = container and container:FindFirstChild(tostring(stage))

    if model and model:IsA("Model") then
        return model
    end

    return nil
end

local function spawnStageModel(models: Instance, name: string, stage: number?, cframe: CFrame): Model?
    if not stage or stage < 1 then
        return nil
    end

    local model = getStageModel(models, name, stage)
    if not model then
        warn("Model is missing for " .. name .. " at stage " .. tostring(stage) .. "!")
        return nil
    end

    local clone = model:Clone()
    clone:PivotTo(cframe)
    clone.Parent = PlantFolder

    return clone
end

local function getGrowthSpeed(ownerId: number?): number
    local owner = ownerId and Players:GetPlayerByUserId(ownerId)

    if owner and owner:GetAttribute("2xGrowthSpeed") then
        return 2
    end

    return 1
end

local function getTimeLeft(growTime: number, startTime: number, speed: number): number
    if growTime <= 0 then
        return 0
    end

    local elapsed = (workspace:GetServerTimeNow() - startTime) * speed

    return math.max(growTime - elapsed, 0) / speed
end

local function formatTime(seconds: number): string
    seconds = math.ceil(seconds)

    if seconds >= 3600 then
        return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
    end

    if seconds >= 60 then
        return string.format("%dm %ds", seconds // 60, seconds % 60)
    end

    return seconds .. "s"
end

local function findTaggedModel(instance: Instance?): Model?
    local current = instance

    while current and current ~= PlantFolder do
        if current:IsA("Model") and current:GetAttribute("PlantId") then
            return current
        end

        current = current.Parent
    end

    return nil
end

local function getTargetFromRay(ray: Ray): (number?, number?)
    local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, hoverParams)
    if not result then
        return nil, nil
    end

    local model = findTaggedModel(result.Instance)
    if not model then
        return nil, nil
    end

    return model:GetAttribute("PlantId"), model:GetAttribute("Slot")
end

local function getTargetModel(self: PlantingClient, plantId: number, slot: number?): Model?
    if slot then
        local fruits = self.Fruits[plantId]
        return fruits and fruits[slot]
    end

    return self.Plants[plantId]
end

local function getTargetInfo(self: PlantingClient, plantId: number, slot: number?): StageInfo?
    if slot then
        local infos = self.FruitInfo[plantId]
        return infos and infos[slot]
    end

    return self.PlantInfo[plantId]
end

local function buildTooltip(self: PlantingClient, playerGui: PlayerGui)
    local gui = Instance.new("ScreenGui")
    gui.Name = "PlantTooltip"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10

    local frame = Instance.new("Frame")
    frame.Name = "Tooltip"
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.AutomaticSize = Enum.AutomaticSize.XY
    frame.Size = UDim2.fromOffset(0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Active = false
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 2)
    layout.Parent = frame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PlantName"
    nameLabel.LayoutOrder = 1
    nameLabel.AutomaticSize = Enum.AutomaticSize.XY
    nameLabel.Size = UDim2.fromOffset(0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = ""
    nameLabel.Parent = frame

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "TimeLeft"
    timeLabel.LayoutOrder = 2
    timeLabel.AutomaticSize = Enum.AutomaticSize.XY
    timeLabel.Size = UDim2.fromOffset(0, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 15
    timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeLabel.Text = ""
    timeLabel.Parent = frame

    gui.Parent = playerGui

    self.TooltipFrame = frame
    self.NameLabel = nameLabel
    self.TimeLabel = timeLabel
end

local function updateTooltip(self: PlantingClient)
    local frame = self.TooltipFrame
    local nameLabel = self.NameLabel
    local timeLabel = self.TimeLabel
    if not frame or not nameLabel or not timeLabel then return end

    local camera = workspace.CurrentCamera
    if not camera then
        frame.Visible = false
        return
    end

    local plantId: number?
    local slot: number?

    if touchMode then
        if self.PinnedPlant and os.clock() > self.PinExpires then
            self.PinnedPlant = nil
            self.PinnedSlot = nil
        end

        plantId = self.PinnedPlant
        slot = self.PinnedSlot
    else
        local location = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(location.X, location.Y)
        plantId, slot = getTargetFromRay(ray)
    end

    if not plantId then
        frame.Visible = false
        return
    end

    local model = getTargetModel(self, plantId, slot)
    local info = getTargetInfo(self, plantId, slot)
    if not model or not info then
        frame.Visible = false
        return
    end

    local config = if slot then FruitConfigs[info.Name] else PlantConfigs[info.Name]
    if not config then
        frame.Visible = false
        return
    end

    local speed = getGrowthSpeed(self.Owners[plantId])
    local left = getTimeLeft(config.GrowTime, info.StartTime, speed)
    local harvestable = slot ~= nil or PlantingUtils.isSingleHarvest(info.Name)

    nameLabel.Text = if slot then info.Name else info.Name .. NAME_SUFFIX

    if info.Done or left <= 0 then
        timeLabel.Text = if harvestable then "Ready to harvest" else "Fully grown"
    else
        timeLabel.Text = "Time left: " .. formatTime(left)
    end

    local boxCFrame, boxSize = model:GetBoundingBox()
    local worldPos = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0)
    local viewportPos, onScreen = camera:WorldToViewportPoint(worldPos)

    if not onScreen then
        frame.Visible = false
        return
    end

    frame.Position = UDim2.fromOffset(viewportPos.X, viewportPos.Y - 8)
    frame.Visible = true
end

local function addHarvestPrompt(self: PlantingClient, plantId: number, slot: number, fruitName: string, stage: number?, model: Model)
    if self.Owners[plantId] ~= LocalPlayer.UserId then return end

    local config = FruitConfigs[fruitName]
    if not config then return end

    local part = Instance.new("Part")
    part.Name = "HarvestPrompt"
    part.Size = Vector3.one
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CFrame = model:GetPivot()

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Harvest"
    prompt.ObjectText = fruitName
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Enabled = stage ~= nil and stage >= config.GrowthStages
    prompt.Parent = part

    prompt.Triggered:Connect(function()
        playSfxAt(SoundIds.Harvest, part.Position)
        self.Net:fire("harvestFruit", plantId, slot)
    end)

    part.Parent = model
end

local function addPlantHarvestPrompt(self: PlantingClient, plantId: number, plantName: string, stage: number?, model: Model)
    if self.Owners[plantId] ~= LocalPlayer.UserId then return end
    if not PlantingUtils.isSingleHarvest(plantName) then return end

    local config = PlantConfigs[plantName]
    if not config then return end

    local part = Instance.new("Part")
    part.Name = "HarvestPrompt"
    part.Size = Vector3.one
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CFrame = model:GetPivot()

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Harvest"
    prompt.ObjectText = config.Fruit or plantName
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Enabled = stage ~= nil and stage >= config.GrowthStages
    prompt.Parent = part

    prompt.Triggered:Connect(function()
        playSfxAt(SoundIds.Harvest, part.Position)
        self.Net:fire("harvestPlant", plantId)
    end)

    part.Parent = model
end

local function clearFruit(self: PlantingClient, plantId: number, slot: number)
    local fruits = self.Fruits[plantId]
    local fruit = fruits and fruits[slot]

    if fruit then
        fruit:Destroy()
        fruits[slot] = nil
    end

    local infos = self.FruitInfo[plantId]
    if infos then
        infos[slot] = nil
    end
end

local function clearFruits(self: PlantingClient, plantId: number)
    local fruits = self.Fruits[plantId]
    if fruits then
        for _, fruit in fruits do
            fruit:Destroy()
        end

        self.Fruits[plantId] = nil
    end

    self.FruitInfo[plantId] = nil
end

local function clearPlant(self: PlantingClient, id: number)
    local plant = self.Plants[id]
    if plant then
        plant:Destroy()
        self.Plants[id] = nil
    end

    clearFruits(self, id)
    self.PlantInfo[id] = nil
    self.Owners[id] = nil

    if self.PinnedPlant == id then
        self.PinnedPlant = nil
        self.PinnedSlot = nil
    end
end

local function createFruit(self: PlantingClient, plantId: number, fruit: Definitions.Fruit)
    local stage = PlantingUtils.getGrowthStageFromFruitTime(fruit.Name, fruit.SpawnTime)
    local cframe = Serialize.UnserializeCFrame(fruit.CFrame)
    local fruitConfig = FruitConfigs[fruit.Name]

    local infos = self.FruitInfo[plantId]
    if not infos then
        infos = {}
        self.FruitInfo[plantId] = infos
    end

    infos[fruit.Slot] = {
        CFrame = cframe,
        Name = fruit.Name,
        StartTime = fruit.SpawnTime,
        Done = fruitConfig ~= nil and stage ~= nil and stage >= fruitConfig.GrowthStages
    }

    local fruits = self.Fruits[plantId]
    if not fruits then
        fruits = {}
        self.Fruits[plantId] = fruits
    end

    if fruits[fruit.Slot] then
        fruits[fruit.Slot]:Destroy()
        fruits[fruit.Slot] = nil
    end

    local clone = spawnStageModel(FruitModels, fruit.Name, stage, cframe)
    if not clone then return end

    tagModel(clone, plantId, self.Owners[plantId], fruit.Slot)
    fruits[fruit.Slot] = clone
    addHarvestPrompt(self, plantId, fruit.Slot, fruit.Name, stage, clone)
end

local function createPlant(self: PlantingClient, plant: Definitions.PlantSnapshot)
    clearPlant(self, plant.Id)

    local stage = PlantingUtils.getGrowthStageFromPlantTime(plant.Name, plant.PlantTime)
    local cframe = Serialize.UnserializeCFrame(plant.CFrame)
    local plantConfig = PlantConfigs[plant.Name]

    self.PlantInfo[plant.Id] = {
        CFrame = cframe,
        Name = plant.Name,
        StartTime = plant.PlantTime,
        Done = plantConfig ~= nil and stage ~= nil and stage >= plantConfig.GrowthStages
    }
    self.Owners[plant.Id] = plant.OwnerId

    local clone = spawnStageModel(PlantModels, plant.Name, stage, cframe)
    if clone then
        tagModel(clone, plant.Id, plant.OwnerId)
        self.Plants[plant.Id] = clone
        addPlantHarvestPrompt(self, plant.Id, plant.Name, stage, clone)
    end

    for _, fruit in plant.Fruits or {} do
        createFruit(self, plant.Id, fruit)
    end
end

function PlantingClient.ownsPlant(self: PlantingClient, model: Instance): boolean
    local current: Instance? = model

    while current and current ~= PlantFolder do
        local plantId = current:GetAttribute("PlantId")
        if plantId then
            return self.Owners[plantId] == LocalPlayer.UserId
        end

        current = current.Parent
    end

    return false
end

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
                local pos = getGroundPosition(Vector2.new(input.Position.X, input.Position.Y))
                if pos then
                    self.Net:fire("plant", pos)
                end
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
    local goalPos = pos - Vector3.new(0, 0.5, 0)

    for _, d in clone:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
        end
    end

    clone:PivotTo(CFrame.new(startPos))
    clone.Parent = PlantFolder

    local posSpring = Spring.new(startPos)
    posSpring.Damping = 0.8
    posSpring.Frequency = 1
    posSpring.Target = goalPos

    local spinSpring = Spring.new(math.pi * 4)
    spinSpring.Damping = 1
    spinSpring.Frequency = 0.6
    spinSpring.Target = 0

    local startTime = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        posSpring:Update(dt)
        spinSpring:Update(dt)

        local yaw = spinSpring.Position
        clone:PivotTo(CFrame.new(posSpring.Position) * CFrame.Angles(0, yaw, 0))

        local settled = (posSpring.Position - goalPos).Magnitude < 0.7 and math.abs(yaw) < 0.7
        if settled or os.clock() - startTime > 5 then
            conn:Disconnect()
            clone:Destroy()

            playSfxAt(SoundIds.Plant, pos)

            local dirt = Instance.new("Part")
            dirt.Anchored = true
            dirt.Shape = Enum.PartType.Cylinder
            dirt.Color = Color3.new(0.462745, 0.317647, 0.003922)
            dirt.Size = Vector3.new(1, 1, 1)
            dirt.CFrame = CFrame.new(pos - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
            dirt.Parent = workspace

            local t = TweenService:Create(dirt, TweenInfo.new(1), {CFrame = CFrame.new(pos - Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))})
            t:Play()
            t.Completed:Once(function()
                task.delay(1, function()
                    local t1 = TweenService:Create(dirt, TweenInfo.new(1), {Transparency = 1})
                    t1:Play()
                    t1.Completed:Once(function()
                        dirt:Destroy()
                    end)
                end)
            end)
        end
    end)
end

function PlantingClient.updatePlant(self: PlantingClient, id: number, plantName: string, stage: number)
    local info = self.PlantInfo[id]
    if not info then return end

    local plantConfig = PlantConfigs[plantName]
    if plantConfig and stage >= plantConfig.GrowthStages then
        info.Done = true
    end

    local clone = spawnStageModel(PlantModels, plantName, stage, info.CFrame)
    if not clone then return end

    tagModel(clone, id, self.Owners[id])

    local old = self.Plants[id]
    if old then
        old:Destroy()
    end

    self.Plants[id] = clone
    addPlantHarvestPrompt(self, id, plantName, stage, clone)
end

function PlantingClient.updateFruit(self: PlantingClient, plantId: number, slot: number, fruitName: string, stage: number)
    local infos = self.FruitInfo[plantId]
    local info = infos and infos[slot]
    if not info then return end

    local fruitConfig = FruitConfigs[fruitName]
    if fruitConfig and stage >= fruitConfig.GrowthStages then
        info.Done = true
    end

    local clone = spawnStageModel(FruitModels, fruitName, stage, info.CFrame)
    if not clone then return end

    tagModel(clone, plantId, self.Owners[plantId], slot)

    local fruits = self.Fruits[plantId]
    if not fruits then
        fruits = {}
        self.Fruits[plantId] = fruits
    end

    local old = fruits[slot]
    if old then
        old:Destroy()
    end

    fruits[slot] = clone
    addHarvestPrompt(self, plantId, slot, fruitName, stage, clone)
end

function PlantingClient.spawnPlants(self: PlantingClient, plants: {Definitions.PlantSnapshot})
    for _, plant in plants do
        createPlant(self, plant)
    end
end

function PlantingClient.spawnFruit(self: PlantingClient, plantId: number, fruit: Definitions.Fruit)
    if not self.PlantInfo[plantId] then return end

    createFruit(self, plantId, fruit)
end

function PlantingClient.deleteFruit(self: PlantingClient, plantId: number, slot: number)
    clearFruit(self, plantId, slot)
end

function PlantingClient.deletePlants(self: PlantingClient, plants: {number})
    for _, id in plants do
        clearPlant(self, id)
    end
end

function PlantingClient.Init(self: PlantingClient)
    self.Plants = {}
    self.PlantInfo = {}
    self.Fruits = {}
    self.FruitInfo = {}
    self.Owners = {}
    self.PinnedPlant = nil
    self.PinnedSlot = nil
    self.PinExpires = 0
    self.Janitor = Janitor.new()
    self.Net = Networker.client.new("Planting", self)
    self.Net:fire("requestPlants")

    task.spawn(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        buildTooltip(self, playerGui)
    end)

    UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end

        touchMode = true
        if gpe then return end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
        local plantId, slot = getTargetFromRay(ray)

        self.PinnedPlant = plantId
        self.PinnedSlot = slot
        self.PinExpires = os.clock() + PIN_DURATION
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            touchMode = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        updateTooltip(self)
    end)
end

type StageInfo = {
    CFrame: CFrame,
    Name: string,
    StartTime: number,
    Done: boolean
}

type PlantingClient = typeof(PlantingClient) & {
    Net: typeof(Networker.client),
    Janitor: typeof(Janitor.new()),
    Plants: {[number]: Model},
    PlantInfo: {[number]: StageInfo},
    Fruits: {[number]: {[number]: Model}},
    FruitInfo: {[number]: {[number]: StageInfo}},
    Owners: {[number]: number},
    TooltipFrame: Frame?,
    NameLabel: TextLabel?,
    TimeLabel: TextLabel?,
    PinnedPlant: number?,
    PinnedSlot: number?,
    PinExpires: number
}

return PlantingClient :: PlantingClient