local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationServiceUtils = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceUtils)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local tag = "RobuxButton"
local att = "ProductName"

local db = false
local cd = 0.5

local MonetizationServiceClient = {}

local function connectRobuxBtn(self: MonetizationServiceClient, btn: GuiButton)
    if not btn:IsA('GuiButton') then return end

    local att = btn:GetAttribute(att)
    if not att then return end

    local id, type = MonetizationServiceUtils.getInfoFromName(att)
    if not id or not type then return end

    btn.Activated:Connect(function(a0: InputObject, a1: number)
        if db then return end
        db = true
        task.delay(cd, function()
            db = false
        end)

        self.net:fire("requestPurchase", att)
    end)

    local s, price = pcall(function(...)
        return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType[type])
    end)
    if not s or not price then return end

    local label = btn:FindFirstChild('Price') or btn:WaitForChild("Price", 5)
    if not label then return end

    label.Text = "" .. price
end

function MonetizationServiceClient.updateOwnedGamepasses(self: MonetizationServiceClient, t: {string})
    self.ownedGamepasses = t
end

function MonetizationServiceClient.Init(self: MonetizationServiceClient)
    self.net = Networker.client.new("MonetizationService", self)
    self.ownedGamepasses = {}

    CollectionService:GetInstanceAddedSignal(tag):Connect(function(btn: Instance)
        connectRobuxBtn(self, btn)
    end)

    task.spawn(function()
        for _, btn in CollectionService:GetTagged(tag) do
            task.spawn(connectRobuxBtn(self, btn))
        end
    end)
end

type MonetizationServiceClient = typeof(MonetizationServiceClient) & {
   net: typeof(Networker.client),
   ownedGamepasses: {string}
}

return MonetizationServiceClient :: MonetizationServiceClient