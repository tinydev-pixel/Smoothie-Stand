local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local GetRarityGradient = require(ReplicatedStorage.Source.Core.Platform.GetRarityGradient)
local FormatTime = require(ReplicatedStorage.Source.Core.Utils.FormatTime)
local Loom = require(ReplicatedStorage.Source.Core.Utils.Loom)
local Notifications = require(ReplicatedStorage.Source.Core.Utils.Notifications)
local ImageIds = require(ReplicatedStorage.Source.Game.Assets.ImageIds)
local Fruits = require(ReplicatedStorage.Source.Game.Configurations.Fruits)
local Seeds = require(ReplicatedStorage.Source.Game.Configurations.Seeds)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local SeedTemplate = ReplicatedStorage.Assets.UI.SeedTemplate

local IN_STOCK_COLOR = Color3.fromRGB(85, 255, 127)
local OUT_OF_STOCK_COLOR = Color3.new(1, 0, 0)

local db = false
local cd = 0.1

local SeedShopServiceClient = {}

local function setStockText(item: any, amt: number)
    if amt > 0 then
        item.StockCount.Text = "x" .. amt .. " in Stock"
        item.StockCount.TextColor3 = IN_STOCK_COLOR
    else
        item.StockCount.Text = "Out of Stock!"
        item.StockCount.TextColor3 = OUT_OF_STOCK_COLOR
    end
end

local function addSeed(self: SeedShopServiceClient, name: string, price: number)
    local clone = SeedTemplate:Clone()

    local rarity = Fruits[name] and Fruits[name].Rarity 
    if rarity then
        local colorSeq = GetRarityGradient(rarity)
        if colorSeq then
            local g = Instance.new("UIGradient")
            g.Color = colorSeq
            g.Parent = clone.ProductName
        end
    end

    clone.ProductImage.Image = ImageIds[name] or ""
    clone.ProductName.Text = name .. " Seed"
    clone.Cash.Price.Text = "$" .. FormatNumber.Simple.FormatCompact(price)
    setStockText(clone, 0)
    clone.Cash.Activated:Connect(function(a0: InputObject, a1: number)
        if db then return end
        db = true
        task.delay(cd, function()
            db = false
        end)

        self.net:fire("purchase", name)
    end)
    
    clone.Robux:SetAttribute("ProductName", name .. " Seed")
    CollectionService:AddTag(clone.Robux, "RobuxButton")
    
    clone.LayoutOrder = table.find(Seeds.Order, name) or 0
    clone.Parent = self.container
    self.items[name] = clone
end

local function connectSeedShopNPC(self: SeedShopServiceClient)
    local map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 5)
    local plaza = map and (map:FindFirstChild("Plaza") or map:WaitForChild("Plaza", 5))
    local npc = plaza and (plaza:FindFirstChild("SeedShop") or plaza:WaitForChild("SeedShop"))
    local primary = npc and (npc:FindFirstChild("HumanoidRootPart") or npc:WaitForChild("HumanoidRootPart"))
    if not primary then return end

    self.npcRoot = primary

    local prompt = primary:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.ObjectText = "Seed Shop"
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.Parent = primary
    end

    prompt.Triggered:Connect(function(plr: Player)
        Loom.Open(self.frame)
    end)
end

function SeedShopServiceClient.updateTimer(self: SeedShopServiceClient, timeLeft: number)
    if not self.loaded then return end
    self.timer.Text = FormatTime(timeLeft)
end

function SeedShopServiceClient.stock(self: SeedShopServiceClient, stock: {[string]: number}, restocked: boolean?)
    if not self.loaded then
        self.pendingStock = stock
        return
    end

    for seed, amt in stock do
        local item = self.items[seed]
        if item then
            setStockText(item, amt)
        end
    end

    if restocked then
        Notifications.Show({message = "Seed shop has restocked!"})
    end
end

function SeedShopServiceClient.Init(self: SeedShopServiceClient)
    self.net = Networker.client.new("SeedShopService", self)
    self.items = {}
    self.loaded = false
    self.pendingStock = nil
    self.npcRoot = nil

    task.spawn(connectSeedShopNPC, self)
    task.spawn(function()
        local frame = GetFrame("Seeds")
        local container = frame and (frame:FindFirstChild("Scrolling") or frame:WaitForChild("Scrolling", 5))
        local title = frame and (frame:FindFirstChild("Title") or frame:WaitForChild("Title", 5))
        local timer = title and (title:FindFirstChild("Timer") or title:WaitForChild("Timer", 5))
        if not container or not timer then return end

        self.container = container
        self.frame = frame
        self.timer = timer

        for _, seed in Seeds.Order do
            addSeed(self, seed, Seeds.Data[seed].Cost)
        end

        self.loaded = true

        local stock = self.net:fetch("getStock") or self.pendingStock
        self.pendingStock = nil

        if stock then
            self:stock(stock)
        end
    end)
end

type SeedShopServiceClient = typeof(SeedShopServiceClient) & {
    net: typeof(Networker.client),
    loaded: boolean,
    container: ScrollingFrame,
    frame: Frame,
    timer: TextLabel,
    items: {[string]: any},
    npcRoot: BasePart?,
    pendingStock: {[string]: number}?
}

return SeedShopServiceClient :: SeedShopServiceClient