local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlotServer = require(ServerScriptService.Features.Plots.PlotServer)
local GetEquippedTool = require(ReplicatedStorage.Source.Core.Platform.GetEquippedTool)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local FINAL_STEP = 12
local SEED_TOOL = "Carrot Seed"
local SEED_PRODUCT = "Carrot"

local TutorialServiceServer = {}

local function getTutorial(plr: Player)
    local data = Data[plr]
    return data and data.tutorial
end

local function isHoldingSeed(plr: Player): boolean
    local tool = GetEquippedTool(plr)
    return tool ~= nil and tool.Name == SEED_TOOL
end

function TutorialServiceServer.advance(self: TutorialServiceServer, plr: Player, fromStep: number)
    local tutorial = getTutorial(plr)
    if not tutorial then return end

    local state = tutorial()
    if state.completed or (state.step or 1) ~= fromStep then return end

    if fromStep >= FINAL_STEP then
        tutorial.completed(true)
        return
    end

    local nextStep = fromStep + 1
    tutorial.step(nextStep)

    if nextStep == 11 and isHoldingSeed(plr) then
        self:advance(plr, nextStep)
    end
end

function TutorialServiceServer.onEquipped(self: TutorialServiceServer, plr: Player, item: string)
    if item ~= SEED_TOOL then return end

    self:advance(plr, 1)
    self:advance(plr, 11)
end

function TutorialServiceServer.onTeleported(self: TutorialServiceServer, plr: Player, location: string)
    if location == "SeedShop" then
        self:advance(plr, 8)
    elseif location == "Plot" then
        self:advance(plr, 10)
    end
end

function TutorialServiceServer.onSeedPurchased(self: TutorialServiceServer, plr: Player, seed: string)
    if seed ~= SEED_PRODUCT then return end

    self:advance(plr, 9)
end

function TutorialServiceServer.getPlotPosition(self: TutorialServiceServer, plr: Player): Vector3?
    local plotCFrame = PlotServer:waitForPlotCFrame(plr)
    if not plotCFrame then return nil end

    return PlotServer:getGardenPosition(plr) or plotCFrame.Position
end

function TutorialServiceServer.skip(self: TutorialServiceServer, plr: Player)
    local tutorial = getTutorial(plr)
    if not tutorial then return end

    if not tutorial().completed then
        tutorial.completed(true)
    end
end

function TutorialServiceServer.Init(self: TutorialServiceServer)
    self.Net = Networker.server.new("TutorialService", self, {self.skip, self.getPlotPosition})
end

type TutorialServiceServer = typeof(TutorialServiceServer) & {
    Net: typeof(Networker.server)
}

return TutorialServiceServer :: TutorialServiceServer