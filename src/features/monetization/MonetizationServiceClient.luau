local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationServiceUtils = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceUtils)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local tag = "RobuxButton"
local att = "ProductName"
local cd = 0.5

local connected = {}

local MonetizationServiceClient = {}

local function connectRobuxBtn(self: MonetizationServiceClient, btn: Instance)
    if connected[btn] then return end
    if not btn:IsA("Model") and not btn:IsA("GuiButton") then return end
    connected[btn] = true

    local isModel = btn:IsA("Model")
    local attGot = btn:GetAttribute(isModel and "ButtonType" or att)
    if not attGot then return end

    local id, type = MonetizationServiceUtils.getInfoFromName(attGot)
    if not id or not type then return end

    local s, info = pcall(function()
        return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType[type])
    end)
    if not s or not info or not info.PriceInRobux then return end

    local priceText = "\u{E002} " .. info.PriceInRobux

    if isModel then
        local gui = btn:FindFirstChildWhichIsA("BillboardGui", true) or btn:WaitForChild("BillboardGui", 5)
        if not gui then return end

        local label = gui:FindFirstChild("Price") or gui:WaitForChild("Price", 5)
        if not label then return end

        label.Text = priceText
    else
        local db = false

        btn.Activated:Connect(function()
            if db then return end
            db = true
            task.delay(cd, function()
                db = false
            end)

            self.net:fire("requestPurchase", attGot)
        end)

        local label = btn:FindFirstChild("Price") or btn:WaitForChild("Price", 5)
        if not label then return end

        label.Text = priceText
    end
end

function MonetizationServiceClient.updateOwnedGamepasses(self: MonetizationServiceClient, t: {string})
    self.ownedGamepasses = t
end

function MonetizationServiceClient.Init(self: MonetizationServiceClient)
    self.net = Networker.client.new("MonetizationService", self)
    self.ownedGamepasses = {}

    CollectionService:GetInstanceAddedSignal(tag):Connect(function(btn: Instance)
        task.spawn(connectRobuxBtn, self, btn)
    end)

    for _, btn in CollectionService:GetTagged(tag) do
        task.spawn(connectRobuxBtn, self, btn)
    end
end

type MonetizationServiceClient = typeof(MonetizationServiceClient) & {
   net: typeof(Networker.client),
   ownedGamepasses: {string}
}

return MonetizationServiceClient :: MonetizationServiceClient