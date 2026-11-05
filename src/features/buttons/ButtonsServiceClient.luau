local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Flash = require(ReplicatedStorage.Source.Core.Platform.Flash)
local PlaySoundInSpace = require(ReplicatedStorage.Source.Core.Platform.PlaySoundInSpace)
local ButtonClient = require(ReplicatedStorage.Source.Features.Buttons.Classes.ButtonClient)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)
local DrainRateUpgrades = require(ReplicatedStorage.Source.Game.Configurations.DrainRateUpgrades)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local Networker = require(ReplicatedStorage.Source.Packages.Networker)
local Spring = require(ReplicatedStorage.Source.Packages.Spring)

local Plots = workspace.Plots
local Cars = ReplicatedStorage.Assets.Cars

local redColor = Color3.new(0.890196, 0.254902, 0.443137) 
local greenColor =Color3.new(0.07451, 0.862745, 0.113725)

local ButtonsServiceClient = {}

local function getPlotStuff(plotId: number): Folder? | SurfaceGui? | Part?
    local plot = Plots:FindFirstChild(plotId) or Plots:WaitForChild(plotId, 5)
    local main = plot and plot:FindFirstChild("Main") or plot:WaitForChild("Main", 5)
    local buttons = main and main:FindFirstChild("Buttons") or main:WaitForChild("Buttons", 5)
    local stand = main and main:FindFirstChild("Stand")
    local carPart = stand and stand:FindFirstChild("CarPart")
    local signPart = main and main:FindFirstChild("Sign")
    local sign = signPart and signPart:FindFirstChildWhichIsA("SurfaceGui")
    return buttons, sign, carPart
end

local function getBtn(self: ButtonsServiceClient, btnType: string): Part?
    return self.btns[btnType] and self.btns[btnType].btn
end

local function updateBtnColor(btn: Part, value: number)
    if value == 0 then
        btn.Color = redColor
    else
        btn.Color = greenColor
    end
end

local function spawnCar(self: ButtonsServiceClient)
    self.carSpawned = true

    local cars = Cars:GetChildren()
    local car = cars[math.random(1, #cars)]
    local clone = car:Clone() :: Model
    clone.Parent = workspace
    Flash.play(clone)

    local startPos = self.carPart.Position - Vector3.new(80, 0, 0)
    local midPos = self.carPart.Position
    local endPos = self.carPart.Position + Vector3.new(150, 0, 0)

    local spring = Spring.new(startPos)
    spring.Damping = 0.8
    spring.Frequency = 0.6
    spring.Target = midPos

    local startTime = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt: number)
        spring:Update(dt)
        clone:PivotTo(CFrame.new(spring.Position) * CFrame.Angles(0, math.rad(90), 0))

        local completed = (spring.Position - midPos).Magnitude < 0.1
        if completed or os.clock() - startTime > 5 then
            conn:Disconnect()

            task.delay(1, function()
                PlaySoundInSpace(SoundIds.Beep, clone.PrimaryPart)
                -- Other effects

                task.delay(1, function()
                    local spring2 = spring.new(midPos)
                    spring2.Damping = 0.4
                    spring2.Frequency = 1
                    spring2.Target = endPos

                    local transparencyStarted = false
                    local startTime2 = os.clock()
                    local conn2

                    conn2 = RunService.Heartbeat:Connect(function(dt: number)
                        spring2:Update(dt)
                        clone:PivotTo(CFrame.new(spring2.Position) * CFrame.Angles(0, math.rad(90), 0))

                        local distance = (spring2.Position - endPos).Magnitude
                        if distance < 0.7 and not transparencyStarted then
                            transparencyStarted = true

                            for _, part in clone:GetDescendants() do
                                if part:IsA("BasePart") then
                                    TweenService:Create(part, TweenInfo.new(0.5), {Transparency = 1}):Play()
                                end
                            end
                        end

                        if distance < 0.1 or os.clock() - startTime2 > 5 then
                            conn2:Disconnect()
                            clone:Destroy()
                            self.carSpawned = false
                        end
                    end)
                end)
            end)
        end
    end)
end

local function updateMoneyStorage(self: ButtonsServiceClient, cashStorage: number)
    local btn = getBtn(self, "ClaimMoney")
    if btn and btn.Parent then
        local gui = btn.Parent:FindFirstChildWhichIsA("BillboardGui") or btn.Parent:WaitForChild("BillboardGui", 5)
        local label = gui and (gui:FindFirstChild("CashAmount") or gui:WaitForChild("CashAmount", 5))
        if label then
            label.Text = "$" .. FormatNumber.Simple.FormatCompact(cashStorage)
        end

        updateBtnColor(btn, cashStorage)

        if cashStorage ~= 0 and not self.carSpawned and self.carPart then
            spawnCar(self)
        end
    end
end

local function updateGroupRewards(self: ButtonsServiceClient, groupRewards: number)
    local btn = getBtn(self, "GroupRewards")
    if btn and btn.Parent then
        local gui = btn.Parent:FindFirstChildWhichIsA("BillboardGui") or btn.Parent:WaitForChild("BillboardGui", 5)
        local label = gui and (gui:FindFirstChild("CashAmount") or gui:WaitForChild("CashAmount", 5))
        if label then
            label.Text = "$" .. FormatNumber.Simple.FormatCompact(groupRewards)
        end

        updateBtnColor(btn, groupRewards)
    end
end

local function updateDrainRate(self: ButtonsServiceClient, drainRate: number, cash: number)
    local btn = getBtn(self, "DrainRate")
    if not btn or not btn.Parent then return end

    local gui = btn.Parent:FindFirstChildWhichIsA("BillboardGui") or btn.Parent:WaitForChild("BillboardGui", 5)
    if not gui then return end

    local priceLabel = gui:FindFirstChild("Price") or gui:WaitForChild("Price", 5)
    local rateLabel = gui:FindFirstChild("Label") or gui:WaitForChild("Label", 5)
    if not priceLabel or not rateLabel then return end

    local nextUpg = DrainRateUpgrades.getNextUpgrade(drainRate)
    priceLabel.Text = "$" .. FormatNumber.Simple.FormatCompact(nextUpg.Price)
    rateLabel.Text = "-> " .. FormatNumber.Simple.FormatCompact(nextUpg.Rate) .. "/sec"

    updateBtnColor(btn, (cash >= nextUpg.Price) and 1 or 0)
end

function ButtonsServiceClient.onPlotAssigned(self: ButtonsServiceClient, plotId: number)
    local buttons, sign, carPart = getPlotStuff(plotId)
    if not buttons or not sign then 
        warn("Plot " .. plotId .. " is missing it's buttons and/or sign, or it just hasn't loaded in on the client!")
        return 
    end

    for _, btn in buttons:GetChildren() do
        local btnType = btn:GetAttribute("ButtonType") or btn.Name
        self.btns[btnType] = ButtonClient.new(btn, self.Net, btnType)
    end

    self.sign = sign
    self.carPart = carPart

    task.spawn(updateDrainRate, self, Data.upgrades.drainRate(), Data.cash())
    task.spawn(updateGroupRewards, self, Data.groupRewards())
    task.spawn(updateMoneyStorage, self, Data.storage.cash())
end

function ButtonsServiceClient.updateSign(self: ButtonsServiceClient, cornStorage: number, drainRate: number)
    local startTime = os.clock()
    local waitTime = 5
    if not self.sign then repeat task.wait() until self.sign or os.clock() - startTime > waitTime end

    self.sign.CornAmount.Text = FormatNumber.Simple.FormatCompact(cornStorage)
    self.sign.AmountPerSecond.Text = FormatNumber.Simple.FormatCompact(drainRate) .. " per second"
end

function ButtonsServiceClient.Init(self: ButtonsServiceClient)
    self.Net = Networker.client.new("ButtonsService", self)
    self.btns = {}

    Data.storage.corn.Changed(function(corn: number, a1: number, a2: string?)
        self:updateSign(corn, Data.upgrades.drainRate())
    end)

    Data.upgrades.drainRate.Changed(function(drainRate: number, a1: number, a2: string?)
        updateDrainRate(self, drainRate, Data.cash())
        task.spawn(self.updateSign, self, Data.storage.corn(), Data.upgrades.drainRate())
    end)

    Data.storage.cash.Changed(function(cashStorage: number, a1: number, a2: string?)
        updateMoneyStorage(self, cashStorage)
    end)

    Data.groupRewards.Changed(function(groupRewards: number, a1: number, a2: string?)
        updateGroupRewards(self, groupRewards)
    end)

    Data.cash.Changed(function(cash: number, a1: number, a2: string?)
        updateDrainRate(self, Data.upgrades.drainRate(), cash)
    end)

    task.spawn(self.updateSign, self, Data.storage.corn(), Data.upgrades.drainRate())
end

type ButtonsServiceClient = typeof(ButtonsServiceClient) & {
    Net: typeof(Networker.client),
    btns: {[string]: typeof(ButtonClient)},
    sign: SurfaceGui,
    carSpawned: boolean,
    carPart: Part
}

return ButtonsServiceClient :: ButtonsServiceClient