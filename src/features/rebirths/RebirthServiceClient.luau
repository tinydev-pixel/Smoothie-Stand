local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Source.Game.Data).client
local Flashbang = require(ReplicatedStorage.Source.Core.Platform.Flashbang)
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local Loom = require(ReplicatedStorage.Source.Core.Utils.Loom)
local ImageIds = require(ReplicatedStorage.Source.Game.Assets.ImageIds)
local ImageDefinitions = require(ReplicatedStorage.Source.Game.Configurations.ImageDefinitions)
local Rebirths = require(ReplicatedStorage.Source.Game.Configurations.Rebirths)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local RewardTemplate = ReplicatedStorage.Assets.UI.RebirthReward

local debounce = false
local cooldown = 1

local RebirthServiceClient = {}

local function updateCash(cash: number)
    local frame = GetFrame("Rebirth")
    if not frame then return end
    
    local main = frame:FindFirstChild("Main") or frame:WaitForChild("Main", 5)
    local bar = main and main:FindFirstChild("Bar")
    if not bar then return end

    local progress = bar and bar:FindFirstChild("Progress") or bar:WaitForChild("Progress", 5)
    local label = bar and bar:FindFirstChild("Label") or bar:WaitForChild("Label", 5)
    if not progress or not label then return end

    local price = Rebirths.Data[Data.rebirths() + 1] and Rebirths.Data[Data.rebirths() + 1].Price
    if not price then return end

    label.Text = "$" .. FormatNumber.Simple.FormatCompact(cash) .. " / $" .. FormatNumber.Simple.FormatCompact(price) 

    local progressInt = math.clamp(cash / price, 0, 1)
    progress.Size = UDim2.fromScale(progressInt, 1)
end

local function createReward(rewardType: string, value: number, cont: Frame)
    local clone = RewardTemplate:Clone()
    clone.Image.Image = ImageIds[ImageDefinitions[rewardType]]
    
    if string.find(rewardType, "Mult") then
        clone.Amount.Text = value .. "x"
    elseif string.find(rewardType, "Level") then
        clone.Amount.Text = "Level " .. value
    end

    clone.Parent = cont
end

local function clearList(rewards: Frame)
    for _, c in rewards:GetChildren() do
        if c:IsA("Frame") then
            c:Destroy()
        end
    end
end

local function updateRebirths(rebirths: number)
    local frame = GetFrame("Rebirth")
    if not frame then return end

    local cashBtn = frame:FindFirstChild("Cash") or frame:WaitForChild("CashBtn", 5)
    local priceLabel = cashBtn and cashBtn:FindFirstChild("Price") or cashBtn:WaitForChild("Price", 5)
    if not priceLabel then return end

    local main = frame:FindFirstChild("Main") or frame:WaitForChild("Main", 5)
    local rewards = main and main:FindFirstChild("Rewards") or main:WaitForChild("Rewards", 5)
    local bar = main and main:FindFirstChild("Bar")
    if not bar or not rewards then return end

    local progress = bar and bar:FindFirstChild("Progress") or bar:WaitForChild("Progress", 5)
    local label = bar and bar:FindFirstChild("Label") or bar:WaitForChild("Label", 5)
    if not progress or not label then return end

    clearList(rewards)

    local nextRebirth = Rebirths.Data[rebirths + 1]
    if not nextRebirth then
        label.Text = ""
        priceLabel = ""

        local completedFrame = frame:FindFirstChild("Completed")
        if completedFrame then
            completedFrame.Visible = true
        end
        
        return
    end

    task.spawn(function()
        for _, reward in nextRebirth.Rewards do
            createReward(reward.Type, reward.Value, rewards)
        end
    end)

    priceLabel.Text = "$" .. FormatNumber.Simple.FormatCompact(nextRebirth.Price)

    updateCash(Data.cash())
end

local function connectBtns(self: RebirthServiceClient)
    local frame = GetFrame("Rebirth")
    local cashBtn = frame and frame:FindFirstChild("Cash") or frame:WaitForChild("CashBtn", 5)
    if not cashBtn then return end

    cashBtn.Activated:Connect(function()
        if debounce then return end
        debounce = true
        task.delay(cooldown, function()
            debounce = false
        end)

        self.net:fire("rebirth")
    end)
end

function RebirthServiceClient.Init(self: RebirthServiceClient)
    self.net = Networker.client.new("RebirthService", self)

    Data.cash.Changed(function(cash: number, a1: number, a2: string?)
        updateCash(cash)
    end)

    Data.rebirths.Changed(function(rebirths: number, a1: number, a2: string?)
        Flashbang.new()
        local frame = GetFrame("Rebirth")
        local openedFrame = Loom.GetCurrentFrame()
        if frame and openedFrame and openedFrame == frame then
            Loom.Close(frame)
        end

        updateRebirths(rebirths)
    end)
    
    task.spawn(updateCash, Data.cash())
    task.spawn(updateRebirths, Data.rebirths())
    task.spawn(connectBtns, self)
end

type RebirthServiceClient = typeof(RebirthServiceClient) & {
    net: typeof(Networker.client)
}

return RebirthServiceClient :: RebirthServiceClient