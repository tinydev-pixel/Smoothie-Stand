local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeTeleport = require(ReplicatedStorage.Source.Core.Utils.SafeTeleport)
local Info = require(ReplicatedStorage.Source.Game.Assets.Info)
local Signals = require(ReplicatedStorage.Source.Game.Signals)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Data = require(ReplicatedStorage.Source.Game.Data).server

local Plots = workspace.Plots
local Gardens = ReplicatedStorage.Assets.Gardens

local PlotServer = {}

local function moveToDifferentServer(plr: Player)
    SafeTeleport(Info.placeId, plr)
end

local function getGardenFolder(plotId: number): Folder?
    local plot = Plots:FindFirstChild(tostring(plotId))
    local main = plot and plot:FindFirstChild("Main")
    return main and main:FindFirstChild("Garden")
end

local function updateGarden(plotId: number, gardenLevel: number)
    local gardenCont = getGardenFolder(plotId)
    local newGarden = Gardens:FindFirstChild(tostring(gardenLevel))
    if not (gardenCont and newGarden) then
        warn(("updateGarden failed: plot %d, level %d"):format(plotId, gardenLevel))
        return
    end

    gardenCont:ClearAllChildren()
    newGarden:Clone().Parent = gardenCont
end

local function getAvailablePlot(self: PlotServer): Folder?
    local best: Instance? = nil
    local bestId = math.huge

    for _, plot in Plots:GetChildren() do
        local id = tonumber(plot.Name)

        if id and not self.Plots[id] and id < bestId then
            best, bestId = plot, id
        end
    end

    return best
end

function PlotServer.connectData(self: PlotServer, plr: Player, profile)
    local id = self.PlotOf[plr]
    if id and profile.gardenLevel() > 1 then
        updateGarden(id, profile.gardenLevel())
    end

    self.Janitor:Add(
        profile.gardenLevel.Changed(function(level: number)
            local currentId = self.PlotOf[plr]
            if currentId then
                updateGarden(currentId, level)
            end
        end), true, plr.UserId
    )
end

function PlotServer.onPlrRemoving(self: PlotServer, plr: Player)
    self.Janitor:Remove(plr.UserId)

    local id = self.PlotOf[plr]
    if not id then return end

    self.PlotOf[plr] = nil
    self.Plots[id] = nil
    updateGarden(id, 1)
end

function PlotServer.onPlrAdded(self: PlotServer, plr: Player)
    if self.PlotOf[plr] then return end

    local plot = getAvailablePlot(self)
    if not plot then
        moveToDifferentServer(plr)
        return
    end

    local id = tonumber(plot.Name) :: number
    self.Plots[id] = plr
    self.PlotOf[plr] = id

    local profile = Data[plr] or Data.Service:waitForData(plr)
    if not profile or not plr:IsDescendantOf(Players) then return end

    local main = plot:FindFirstChild("Main")
    local spawnPoint = main and main:FindFirstChildWhichIsA("SpawnLocation")
    if not spawnPoint then
        warn("Plot " .. plot.Name .. " is missing a spawn location!")
        return
    end

    plr.RespawnLocation = spawnPoint
    if plr.Character then
        plr.Character:PivotTo(spawnPoint.CFrame)
    end

    self:connectData(plr, profile)

    Signals.plotAssigned:Fire(plr, id)
end

function PlotServer.Init(self: PlotServer)
    self.Janitor = Janitor.new()
    self.Plots = {}
    self.PlotOf = {}

    Players.PlayerAdded:Connect(function(plr)
        task.spawn(self.onPlrAdded, self, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        task.spawn(self.onPlrRemoving, self, plr)
    end)

    for _, plr in Players:GetPlayers() do
        task.spawn(self.onPlrAdded, self, plr)
    end
end

function PlotServer.canPlant(self: PlotServer, plr: Player, pos: Vector3): boolean
    local id = self.PlotOf[plr]
    if not id then return false end

    local garden = getGardenFolder(id)
    local model = garden and garden:FindFirstChildWhichIsA("Model")
    local area = model and model:FindFirstChild("Dirt")
    if not area then return false end

    local cframe, size = area:GetBoundingBox()
    local relative = cframe:PointToObjectSpace(pos)

    return math.abs(relative.X) <= size.X / 2 and math.abs(relative.Z) <= size.Z / 2
end

type PlotServer = typeof(PlotServer) & {
    Plots: {[number]: Player},
    PlotOf: {[Player]: number},
    Janitor: typeof(Janitor.new()),
}

return PlotServer :: PlotServer