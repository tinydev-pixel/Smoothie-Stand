local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeTeleport = require(ReplicatedStorage.Core.Utils.SafeTeleport)
local Info = require(ReplicatedStorage.Game.Assets.Info)
local Signals = require(ReplicatedStorage.Game.Signals)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Data = require(ReplicatedStorage.Game.Data).server

local Plots = workspace.Map.Plots
local Gardens = ReplicatedStorage.Assets.Gardens

local PlotServer = {}

local function moveToDifferentServer(plr: Player)
    SafeTeleport(Info.placeId, plr)
end

local function updateGarden(plotId: number, gardenLevel: number)
    local plot = Plots:FindFirstChild(tostring(plotId))
    local gardenCont = plot and plot:FindFirstChild("Garden")
    local newGarden = Gardens:FindFirstChild(tostring(gardenLevel))
    if not (gardenCont and newGarden) then
        warn(("updateGarden failed: plot %d, level %d"):format(plotId, gardenLevel))
        return
    end

    gardenCont:ClearAllChildren()
    newGarden:Clone().Parent = gardenCont
end

local function getAvailablePlot(self: PlotServer): Instance?
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
    if profile.gardenLevel() > 1 then
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
    local plot = getAvailablePlot(self)
    if not plot then
        moveToDifferentServer(plr)
        return
    end

    local id = tonumber(plot.Name) :: number
    self.Plots[id] = plr
    self.PlotOf[plr] = id

    local profile = Data[plr] or Data.Service:waitForData(plr)
    if plr.Parent ~= Players then return end 

    local spawnPoint = plot.Main:FindFirstChildWhichIsA("SpawnLocation")
    if spawnPoint then
        plr.RespawnLocation = spawnPoint
    end

    self:connectData(plr, profile)
    plr:LoadCharacterAsync()

    Signals.plotAssigned:Fire(plr, id)
end

function PlotServer.Init(self: PlotServer)
    self.Janitor = Janitor.new()
    self.Plots = {}
    self.PlotOf = {}
    Players.CharacterAutoLoads = false

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
    if not id then return end

    local plot = Plots:FindFirstChild(id)
    local garden = plot:FindFirstChild("Garden")
    local area = garden:FindFirstChildWhichIsA("Model")
    local relative = area.CFrame:PointToObjectSpace(pos)

    return math.abs(relative.X) <= area.Size.X / 2 and math.abs(relative.Z) <= area.Size.Z / 2
end

type PlotServer = typeof(PlotServer) & {
    Plots: {[number]: Player},
    PlotOf: {[Player]: number},
    Janitor: typeof(Janitor.new()),
}

return PlotServer :: PlotServer