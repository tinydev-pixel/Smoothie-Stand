local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local Serialize = require(ReplicatedStorage.Source.Core.Utils.Serialize)
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local Plants = require(ReplicatedStorage.Source.Game.Configurations.Plants)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Definitions = require(ReplicatedStorage.Source.Game.Definitions)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local PlantModels = ReplicatedStorage.Assets.Plants
local MAX_HARVEST_DISTANCE = 25
local spawnOffsets: {[string]: {CFrame}} = {}

local Plant = {}
Plant.__index = Plant

local function getGrowthSpeed(plr: Player): number
    if plr:GetAttribute("2xGrowthSpeed") then
        return 2
    end

    return 1
end

local function isFullyGrown(self: Plant, stage: number?): boolean
    return stage ~= nil and stage >= self.Config.GrowthStages
end

local function toNetFruit(self: Plant, fruit: Definitions.Fruit): Definitions.Fruit
    local copy = table.clone(fruit)
    copy.CFrame = Serialize.SerializeCFrame(self.CFrame * Serialize.UnserializeCFrame(fruit.CFrame))
    return copy
end

local function getSpawnOffsets(plantName: string): {CFrame}
    local cached = spawnOffsets[plantName]
    if cached then return cached end

    local offsets = {}
    local config = Plants[plantName]
    local container = PlantModels:FindFirstChild(plantName)
    local model = container and container:FindFirstChild(tostring(config.GrowthStages))
    local folder = model and (model:FindFirstChild("FruitSpawnPoints") or container:FindFirstChild("FruitSpawnPoints"))

    if model and model:IsA("Model") and folder then
        local pivot = model:GetPivot()
        local points = folder:GetChildren()

        table.sort(points, function(a, b)
            return a.Name < b.Name
        end)

        for _, point in points do
            if point:IsA("BasePart") then
                table.insert(offsets, pivot:ToObjectSpace(point.CFrame))
            elseif point:IsA("Attachment") then
                table.insert(offsets, pivot:ToObjectSpace(point.WorldCFrame))
            end
        end
    end

    if #offsets == 0 then
        warn("No fruit spawn points found for " .. plantName .. "!")
    end

    spawnOffsets[plantName] = offsets
    return offsets
end

local function saveFruits(self: Plant)
    local saved = self.Saved
    if not saved then return end

    local fruits = {}

    for _, fruit in self.Fruits do
        table.insert(fruits, fruit)
    end

    saved.Fruits = fruits
end

local function updateFruits(self: Plant)
    local speed = getGrowthSpeed(self.Owner)

    for slot, fruit in self.Fruits do
        local stage = PlantingUtils.getGrowthStageFromFruitTime(fruit.Name, fruit.SpawnTime, speed)

        if stage and stage ~= self.FruitStages[slot] then
            self.FruitStages[slot] = stage
            self.Net:fireAll("updateFruit", self.Id, slot, fruit.Name, stage)
        end
    end
end

local function spawnFruits(self: Plant)
    if not Fruits[self.FruitName] then return end

    local offsets = getSpawnOffsets(self.Name)
    local free = {}
    local count = 0

    for slot = 1, #offsets do
        if self.Fruits[slot] then
            count += 1
        else
            table.insert(free, slot)
        end
    end

    local missing = math.min(self.Config.FruitAmount - count, #free)
    if missing <= 0 then return end

    for _ = 1, missing do
        local slot = table.remove(free, math.random(#free))
        local fruit: Definitions.Fruit = {
            Name = self.FruitName,
            SpawnTime = workspace:GetServerTimeNow(),
            Slot = slot,
            CFrame = Serialize.SerializeCFrame(offsets[slot])
        }

        self.Fruits[slot] = fruit
        self.FruitStages[slot] = 0
        self.Net:fireAll("spawnFruit", self.Id, toNetFruit(self, fruit))
    end

    saveFruits(self)
end

local function giveFruit(plr: Player, fruitName: string): boolean
    local data = Data[plr]
    if not data then return false end

    local multiplier = plr:GetAttribute("2xCorn") and 2 or 1

    for i = 1, multiplier do
        data.inventory.fruits.Insert(fruitName)
    end

    if not table.find(data.index(), fruitName) then
        data.index.Insert(fruitName)
    end

    return true
end

local function collectFruit(self: Plant, plr: Player, slot: number): boolean
    local fruit = self.Fruits[slot]
    if not fruit then return false end

    local config = Fruits[fruit.Name]
    if not config then return false end

    local stage = PlantingUtils.getGrowthStageFromFruitTime(fruit.Name, fruit.SpawnTime, getGrowthSpeed(plr))
    if not stage or stage < config.GrowthStages then return false end

    if not giveFruit(plr, fruit.Name) then return false end

    self.Fruits[slot] = nil
    self.FruitStages[slot] = nil
    saveFruits(self)

    self.Net:fireAll("deleteFruit", self.Id, slot)

    if self.OnHarvest then
        self.OnHarvest(plr)
    end

    return true
end

local function collectPlant(self: Plant, plr: Player): boolean
    if self.Harvested or not self.SingleHarvest then return false end
    if not Fruits[self.FruitName] then return false end

    local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime, getGrowthSpeed(plr))
    if not isFullyGrown(self, stage) then return false end

    if not giveFruit(plr, self.FruitName) then return false end

    self.Harvested = true

    if self.OnHarvest then
        self.OnHarvest(plr)
    end

    return true
end

local function autoHarvest(self: Plant)
    if not self.Owner:GetAttribute("AutoHarvest") then return end

    if self.SingleHarvest then
        collectPlant(self, self.Owner)
        return
    end

    local slots = {}

    for slot in self.Fruits do
        table.insert(slots, slot)
    end

    for _, slot in slots do
        collectFruit(self, self.Owner, slot)
    end
end

local function growFruits(self: Plant)
    local speed = getGrowthSpeed(self.Owner)

    for _, fruit in self.Fruits do
        local config = Fruits[fruit.Name]
        local stage = PlantingUtils.getGrowthStageFromFruitTime(fruit.Name, fruit.SpawnTime, speed)

        if config and (not stage or stage < config.GrowthStages) then
            fruit.SpawnTime = 0
        end
    end

    saveFruits(self)
    updateFruits(self)
    autoHarvest(self)
end

function Plant.harvestFruit(self: Plant, plr: Player, slot: number)
    if self.Destroyed or self.SingleHarvest or plr ~= self.Owner then return end

    local fruit = self.Fruits[slot]
    if not fruit then return end

    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local fruitPos = (self.CFrame * Serialize.UnserializeCFrame(fruit.CFrame)).Position
    if (root.Position - fruitPos).Magnitude > MAX_HARVEST_DISTANCE then return end

    collectFruit(self, plr, slot)
end

function Plant.harvestPlant(self: Plant, plr: Player)
    if self.Destroyed or self.Harvested or not self.SingleHarvest or plr ~= self.Owner then return end

    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if (root.Position - self.Pos).Magnitude > MAX_HARVEST_DISTANCE then return end

    collectPlant(self, plr)
end

function Plant.update(self: Plant)
    if self.Destroyed or self.Harvested then return end

    if not self.FullyGrown then
        local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime, getGrowthSpeed(self.Owner))
        if not stage then return end

        if stage ~= self.LastStage then
            self.LastStage = stage
            self.Net:fireAll("updatePlant", self.Id, self.Name, stage)
        end

        if isFullyGrown(self, stage) then
            self.FullyGrown = true
        end
    end

    if not self.FullyGrown then return end

    if self.SingleHarvest then
        autoHarvest(self)
        return
    end

    updateFruits(self)
    autoHarvest(self)
    spawnFruits(self)
end

function Plant.canGrow(self: Plant): boolean
    if self.Destroyed or self.Harvested then return false end

    local speed = getGrowthSpeed(self.Owner)

    if not self.FullyGrown then
        local stage = PlantingUtils.getGrowthStageFromPlantTime(self.Name, self.PlantTime, speed)

        if not isFullyGrown(self, stage) then
            return true
        end
    end

    if self.SingleHarvest then
        return false
    end

    for _, fruit in self.Fruits do
        local config = Fruits[fruit.Name]
        local stage = PlantingUtils.getGrowthStageFromFruitTime(fruit.Name, fruit.SpawnTime, speed)

        if config and stage and stage < config.GrowthStages then
            return true
        end
    end

    return false
end

function Plant.growNow(self: Plant)
    if self.Destroyed or self.Harvested then return end

    if not self.FullyGrown then
        self.PlantTime = 0

        if self.Saved then
            self.Saved.PlantTime = 0
        end
    end

    self:update()

    if self.Destroyed or self.Harvested or self.SingleHarvest or not self.FullyGrown then return end

    growFruits(self)
end

function Plant.setSaved(self: Plant, saved: Definitions.Plant)
    self.Saved = saved
    saveFruits(self)
end

function Plant.snapshot(self: Plant): Definitions.PlantSnapshot
    local fruits = {}

    for _, fruit in self.Fruits do
        table.insert(fruits, toNetFruit(self, fruit))
    end

    return {
        Id = self.Id,
        OwnerId = self.Owner.UserId,
        Name = self.Name,
        PlantTime = self.PlantTime,
        CFrame = Serialize.SerializeCFrame(self.CFrame),
        Fruits = fruits
    }
end

function Plant.destroy(self: Plant)
    if self.Destroyed then return end
    self.Destroyed = true

    self.Janitor:Destroy()
    table.clear(self.Fruits)
    table.clear(self.FruitStages)
    self.Saved = nil
    self.OnHarvest = nil
end

function Plant.new(net: typeof(Networker.server), farmer: Player, id: number, plantName: string, cframe: CFrame, plantTime: number, fruits: {Definitions.Fruit}?, saved: Definitions.Plant?)
    local config = Plants[plantName]
    assert(config, "Plant config is missing for " .. plantName .. "!")

    local self: Plant = setmetatable({}, Plant)
    local speed = getGrowthSpeed(farmer)
    local stage = PlantingUtils.getGrowthStageFromPlantTime(plantName, plantTime, speed)

    self.Config = config
    self.Net = net
    self.Janitor = Janitor.new()
    self.Id = id
    self.Owner = farmer
    self.CFrame = cframe
    self.Pos = cframe.Position
    self.Name = plantName
    self.PlantTime = plantTime
    self.LastStage = stage or 0
    self.FullyGrown = isFullyGrown(self, stage)
    self.Destroyed = false
    self.Harvested = false
    self.SingleHarvest = PlantingUtils.isSingleHarvest(plantName)
    self.FruitName = config.Fruit or plantName
    self.Fruits = {}
    self.FruitStages = {}
    self.Saved = saved
    self.OnHarvest = nil

    if not Fruits[self.FruitName] then
        warn("Fruit config is missing for " .. self.FruitName .. "!")
    end

    if fruits and self.FullyGrown and not self.SingleHarvest then
        local offsets = getSpawnOffsets(plantName)

        for _, fruit in fruits do
            local fruitStage = PlantingUtils.getGrowthStageFromFruitTime(fruit.Name, fruit.SpawnTime, speed)
            local validSlot = type(fruit.Slot) == "number" and fruit.Slot >= 1 and fruit.Slot <= #offsets

            if fruitStage and validSlot and not self.Fruits[fruit.Slot] then
                (fruit :: any).Weight = nil
                fruit.CFrame = Serialize.SerializeCFrame(offsets[fruit.Slot])
                self.Fruits[fruit.Slot] = fruit
                self.FruitStages[fruit.Slot] = fruitStage
            end
        end
    end

    return self
end

type Plant = typeof(Plant) & {
    Config: typeof(Plants.Basic),
    Net: typeof(Networker.server),
    Janitor: typeof(Janitor.new()),
    Id: number,
    Owner: Player,
    CFrame: CFrame,
    Pos: Vector3,
    Name: string,
    PlantTime: number,
    LastStage: number,
    FullyGrown: boolean,
    Destroyed: boolean,
    Harvested: boolean,
    SingleHarvest: boolean,
    FruitName: string,
    Fruits: {[number]: Definitions.Fruit},
    FruitStages: {[number]: number},
    Saved: Definitions.Plant?,
    OnHarvest: ((Player) -> ())?
}

return Plant