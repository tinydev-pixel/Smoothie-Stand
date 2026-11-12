local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArrowBeams = require(ReplicatedStorage.Source.Core.Platform.ArrowBeams)
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local GetHUDObject = require(ReplicatedStorage.Source.Core.Platform.GetHUDObject)
local GetRoot = require(ReplicatedStorage.Source.Core.Platform.GetRoot)
local Loom = require(ReplicatedStorage.Source.Core.Utils.Loom)
local ButtonsServiceClient = require(ReplicatedStorage.Source.Features.Buttons.ButtonsServiceClient)
local PlantingClient = require(ReplicatedStorage.Source.Features.Planting.PlantingClient)
local PlantingUtils = require(ReplicatedStorage.Source.Features.Planting.PlantingUtils)
local SeedShopServiceClient = require(ReplicatedStorage.Source.Features.SeedShop.SeedShopServiceClient)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)
local Outline = require(ReplicatedStorage.Source.Game.UI.Classes.Outline)
local Audio = require(ReplicatedStorage.Source.Packages.Audio)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client

local LocalPlayer = Players.LocalPlayer

local SEED_ITEM = "Carrot Seed"
local SEED_SHOP_ITEM = "Carrot"
local OUTLINE_SCALE = 1.2
local WAIT_TIMEOUT = 15
local POLL_RATE = 0.25
local GARDEN_HEIGHT = 1

local TutorialServiceClient = {}

local function isActive(self: TutorialServiceClient, token: number): boolean
    return not self.finished and self.token == token
end

local function waitFor(self: TutorialServiceClient, token: number, getter: () -> any): any
    local startTime = os.clock()

    while isActive(self, token) and os.clock() - startTime < WAIT_TIMEOUT do
        local value = getter()

        if not isActive(self, token) then
            return nil
        end

        if value then
            return value
        end

        task.wait(POLL_RATE)
    end

    return nil
end

local function setLabel(self: TutorialServiceClient, text: string)
    if self.label then
        self.label.Text = text
    end

    self.audio:PlaySFX(SoundIds.Notification)
end

local function getBounds(target: GuiObject, parent: GuiObject): (UDim2, UDim2)
    local parentSize = parent.AbsoluteSize
    if parentSize.X <= 0 or parentSize.Y <= 0 then
        return UDim2.new(), UDim2.new()
    end

    local size = target.AbsoluteSize * OUTLINE_SCALE
    local center = target.AbsolutePosition + target.AbsoluteSize / 2 - parent.AbsolutePosition

    return UDim2.fromScale(center.X / parentSize.X, center.Y / parentSize.Y),
        UDim2.fromScale(size.X / parentSize.X, size.Y / parentSize.Y)
end

local function updateOutline(self: TutorialServiceClient, target: GuiObject)
    local frame = self.frame
    if not frame then return end

    local pos, size = getBounds(target, frame)

    if not self.outline then
        self.outline = Outline.new(size, pos, frame)
    else
        self.outline:changePos(pos)
        self.outline:changeSize(size)
    end

    if not self.outlineShown then
        self.outlineShown = true
        self.outline:enable()
    end
end

local function hideOutline(self: TutorialServiceClient)
    if self.outline and self.outlineShown then
        self.outline:disable()
    end

    self.outlineShown = false
end

local function highlight(self: TutorialServiceClient, target: GuiObject)
    local function refresh()
        updateOutline(self, target)
    end

    refresh()

    self.stepJanitor:Add(target:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh), "Disconnect")
    self.stepJanitor:Add(target:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh), "Disconnect")
end

local function clearBeam(self: TutorialServiceClient)
    self.beamTarget = nil

    if self.beam then
        self.beam:Destroy()
        self.beam = nil
    end
end

local function createBeam(self: TutorialServiceClient, target: Instance)
    if self.finished then return end

    local root = GetRoot(LocalPlayer)
    if not root then return end

    local beam = ArrowBeams.new(root)
    beam:setTarget(target)
    self.beam = beam
end

local function pointBeam(self: TutorialServiceClient, target: Instance?)
    if not target then
        clearBeam(self)
        return
    end

    self.beamTarget = target

    if self.beam then
        self.beam:setTarget(target)
    else
        createBeam(self, target)
    end
end

local function getGardenTarget(self: TutorialServiceClient, token: number): BasePart?
    local existing = self.gardenPart
    if existing and existing.Parent then
        return existing
    end

    local position = self.net:fetch("getPlotPosition")
    if not isActive(self, token) or typeof(position) ~= "Vector3" then
        return nil
    end

    if self.gardenPart then
        self.gardenPart:Destroy()
    end

    local part = Instance.new("Part")
    part.Name = "TutorialGarden"
    part.Size = Vector3.one
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Position = position + Vector3.new(0, GARDEN_HEIGHT, 0)
    part.Parent = workspace

    self.gardenPart = part

    return part
end

local function pointAtGarden(self: TutorialServiceClient, token: number)
    local target = waitFor(self, token, function()
        return getGardenTarget(self, token)
    end)

    if target then
        pointBeam(self, target)
    end
end

local function getModelPart(model: Model): BasePart?
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getHarvestTarget(): BasePart?
    local fallback: BasePart? = nil

    for plantId, model in PlantingClient.Plants do
        if PlantingClient.Owners[plantId] == LocalPlayer.UserId then
            local info = PlantingClient.PlantInfo[plantId]

            if info and info.Done and PlantingUtils.isSingleHarvest(info.Name) then
                local part = getModelPart(model)
                if part then
                    return part
                end
            end

            local fruits = PlantingClient.Fruits[plantId]
            local infos = PlantingClient.FruitInfo[plantId]

            if fruits and infos then
                for slot, fruit in fruits do
                    local fruitInfo = infos[slot]

                    if fruitInfo and fruitInfo.Done then
                        local part = getModelPart(fruit)
                        if part then
                            return part
                        end
                    end
                end
            end

            if not fallback then
                fallback = getModelPart(model)
            end
        end
    end

    return fallback
end

local function trackHarvestTarget(self: TutorialServiceClient, token: number)
    local current: BasePart? = nil

    while isActive(self, token) do
        if not current or not current:IsDescendantOf(workspace) then
            current = getHarvestTarget()
            pointBeam(self, current)
        end

        task.wait(POLL_RATE)
    end
end

local function getHotbarItem(): GuiObject?
    local frame = GetFrame("Hotbar")
    local item = frame and frame:FindFirstChild(SEED_ITEM)

    if item and item:IsA("GuiObject") then
        return item
    end

    return nil
end

local function getTeleportButton(name: string): GuiObject?
    local tpBtns = GetHUDObject("Teleportation")
    local btn = tpBtns and tpBtns:FindFirstChild(name)

    if btn and btn:IsA("GuiObject") then
        return btn
    end

    return nil
end

local function getWorldButton(btnType: string): BasePart?
    local entry = ButtonsServiceClient.btns and ButtonsServiceClient.btns[btnType]
    local btn = entry and (entry :: any).btn

    if typeof(btn) == "Instance" and btn:IsA("BasePart") then
        return btn
    end

    return nil
end

local function getShopNPC(): BasePart?
    return SeedShopServiceClient.npcRoot
end

local function getShopButton(): GuiObject?
    local items = SeedShopServiceClient.items
    local item = items and items[SEED_SHOP_ITEM]
    local btn = item and item:FindFirstChild("Cash")

    if btn and btn:IsA("GuiObject") and SeedShopServiceClient.frame then
        return btn
    end

    return nil
end

local function pointAtWorldButton(self: TutorialServiceClient, token: number, btnType: string)
    local button = waitFor(self, token, function()
        return getWorldButton(btnType)
    end)

    if button then
        pointBeam(self, button)
    end
end

local function watchShop(self: TutorialServiceClient, token: number)
    local button = waitFor(self, token, getShopButton)
    local frame = SeedShopServiceClient.frame
    if not button or not frame then return end

    local function refresh()
        if frame.Visible then
            updateOutline(self, button)
        else
            hideOutline(self)
        end
    end

    self.stepJanitor:Add(frame:GetPropertyChangedSignal("Visible"):Connect(refresh), "Disconnect")
    self.stepJanitor:Add(button:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh), "Disconnect")
    self.stepJanitor:Add(button:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh), "Disconnect")

    refresh()
end

local steps: {(TutorialServiceClient, number) -> ()} = {
    function(self, token)
        setLabel(self, "Equip your Carrot Seeds!")

        local item = waitFor(self, token, getHotbarItem)
        if item then
            highlight(self, item)
        end
    end,

    function(self, token)
        setLabel(self, "Plant them!")
        pointAtGarden(self, token)
    end,

    function(self, token)
        setLabel(self, "Wait for them to Grow!")
    end,

    function(self, token)
        setLabel(self, "Harvest them!")
        trackHarvestTarget(self, token)
    end,

    function(self, token)
        setLabel(self, "Insert them into your Smoothie Machine!")
        pointAtWorldButton(self, token, "InsertFruits")
    end,

    function(self, token)
        setLabel(self, "Claim your profits!")
        pointAtWorldButton(self, token, "ClaimMoney")
    end,

    function(self, token)
        setLabel(self, "Upgrade your Processing Power!")
        pointAtWorldButton(self, token, "DrainRate")
    end,

    function(self, token)
        setLabel(self, "Go to the Seed Shop!")
        clearBeam(self)

        local button = waitFor(self, token, function()
            return getTeleportButton("SeedShop")
        end)

        if button then
            highlight(self, button)
        end
    end,

    function(self, token)
        setLabel(self, "Purchase more Carrot Seeds!")

        task.spawn(watchShop, self, token)

        local npc = waitFor(self, token, getShopNPC)
        if npc then
            pointBeam(self, npc)
        end
    end,

    function(self, token)
        setLabel(self, "Go back to your Plot!")
        clearBeam(self)

        local frame = SeedShopServiceClient.frame
        if frame and Loom.GetCurrentFrame() == frame then
            Loom.Close(frame)
        end

        local button = waitFor(self, token, function()
            return getTeleportButton("Plot")
        end)

        if button then
            highlight(self, button)
        end
    end,

    function(self, token)
        setLabel(self, "Equip your new Carrot Seed(s)!")

        local item = waitFor(self, token, getHotbarItem)
        if item then
            highlight(self, item)
        end
    end,

    function(self, token)
        setLabel(self, "Plant them!")
        pointAtGarden(self, token)
    end
}

local function setHUDVisibility(visible: boolean)
    local leftBtns = GetHUDObject("Left")
    local hud = leftBtns and leftBtns.Parent

    if hud then
        for _, child in hud:GetChildren() do
            if child:IsA("Frame") then
                child.Visible = visible
            end
        end
    end
end

local function applyUnlocks(step: number)
    if step >= 6 then
        local currencies = GetHUDObject("Currencies")
        if currencies then
            currencies.Visible = true
        end
    end

    if step >= 8 then
        local tpBtns = GetHUDObject("Teleportation")
        if tpBtns then
            tpBtns.Visible = true
        end
    end
end

local function prepare(self: TutorialServiceClient): boolean
    local frame = GetFrame("Tutorial")
    local label = frame and (frame:FindFirstChild("Label") or frame:WaitForChild("Label", 5))

    if not frame or not label then
        warn("Tutorial Label is missing!")
        return false
    end

    setHUDVisibility(false)

    local skip = frame:FindFirstChild("Skip") or frame:WaitForChild("Skip", 5)
    if skip then
        self.janitor:Add(
            (skip :: GuiButton).Activated:Connect(function()
                self.net:fire("skip")
            end), "Disconnect"
        )
    end

    self.janitor:Add(
        LocalPlayer.CharacterAdded:Connect(function()
            local target = self.beamTarget
            if not target then return end

            if self.beam then
                self.beam:Destroy()
                self.beam = nil
            end

            task.spawn(createBeam, self, target)
        end), "Disconnect"
    )

    frame.Visible = true
    self.frame = frame
    self.label = label :: TextLabel

    return true
end

local function cleanup(self: TutorialServiceClient)
    self.finished = true
    self.token += 1

    self.janitor:Cleanup()
    self.stepJanitor:Cleanup()
    clearBeam(self)

    if self.outline then
        self.outline:cleanup()
        self.outline = nil
    end

    if self.gardenPart then
        self.gardenPart:Destroy()
        self.gardenPart = nil
    end

    setHUDVisibility(true)

    if self.frame then
        self.frame.Visible = false
    end
end

function TutorialServiceClient.runStep(self: TutorialServiceClient, step: number)
    if self.finished or type(step) ~= "number" or self.currentStep == step then return end

    self.currentStep = step
    self.token += 1

    local token = self.token

    self.stepJanitor:Cleanup()
    hideOutline(self)
    clearBeam(self)
    applyUnlocks(step)

    local handler = steps[step]
    if handler then
        task.spawn(handler, self, token)
    end
end

function TutorialServiceClient.Init(self: TutorialServiceClient)
    self.net = Networker.client.new("TutorialService", self)
    self.janitor = Janitor.new()
    self.audio = Audio.new()
    self.stepJanitor = Janitor.new()
    self.token = 0
    self.currentStep = nil
    self.finished = false
    self.outlineShown = false

    task.spawn(function()
        local tutorial = Data.tutorial()
        if tutorial.completed then return end
        if not prepare(self) then return end

        self.janitor:Add(
            Data.tutorial.Changed(function(changed: { completed: boolean, step: number }?, a1: any, a2: string?)
                local state = if type(changed) == "table" then changed else Data.tutorial()

                if state.completed then
                    cleanup(self)
                    return
                end

                self:runStep(state.step)
            end), true
        )

        self:runStep(tutorial.step)
    end)
end

type TutorialServiceClient = typeof(TutorialServiceClient) & {
    net: typeof(Networker.client),
    janitor: typeof(Janitor.new()),
    audio: typeof(Audio),
    stepJanitor: typeof(Janitor.new()),
    label: TextLabel?,
    frame: Frame?,
    outline: any,
    outlineShown: boolean,
    beam: any,
    beamTarget: Instance?,
    gardenPart: Part?,
    token: number,
    currentStep: number?,
    finished: boolean
}

return TutorialServiceClient :: TutorialServiceClient