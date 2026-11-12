local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SafeTeleport = require(ReplicatedStorage.Source.Core.Utils.SafeTeleport)
local Info = require(ReplicatedStorage.Source.Game.Assets.Info)
local Signals = require(ReplicatedStorage.Source.Game.Signals)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Data = require(ReplicatedStorage.Source.Game.Data).server

local Plots = workspace.Map.Plots
local Gardens = ReplicatedStorage.Assets.Gardens
local SPAWN_HEIGHT_OFFSET = 3

local PlotServer = {}

local function moveToDifferentServer(plr: Player)
    SafeTeleport(Info.placeId, plr)
end

local function getGardenFolder(plotId: number): Instance?
    local plot = Plots:FindFirstChild(tostring(plotId))
    local main = plot and plot:FindFirstChild("Main")
    return main and main:FindFirstChild("Garden")
end

local function getGardenArea(plotId: number): (CFrame?, Vector3?)
    local garden = getGardenFolder(plotId)
    local model = garden and garden:FindFirstChildWhichIsA("Model")
    local area = model and model:FindFirstChild("Dirt")
    if not area then return nil, nil end

    if area:IsA("BasePart") then
        return area.CFrame, area.Size
    elseif area:IsA("Model") then
        return area:GetBoundingBox()
    end

    return nil, nil
end

local function getSpawnPart(plot: Instance?): SpawnLocation?
    local main = plot and plot:FindFirstChild("Main")
    return main and main:FindFirstChildWhichIsA("SpawnLocation")
end

local function getPlotCFrame(plotId: number): CFrame?
    local anchor = getSpawnPart(Plots:FindFirstChild(tostring(plotId)))
    return anchor and anchor.CFrame
end

local function getSpawnCFrame(spawnPart: SpawnLocation): CFrame
    return spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y / 2 + SPAWN_HEIGHT_OFFSET, 0)
end

local function updateGarden(plotId: number, gardenLevel: number)
    local gardenCont = getGardenFolder(plotId)
    local gardenSet = Gardens:FindFirstChild(tostring(plotId))
    local newGarden = gardenSet and gardenSet:FindFirstChild(tostring(gardenLevel))
    if not (gardenCont and newGarden) then
        warn(("updateGarden failed: plot %d, level %d"):format(plotId, gardenLevel))
        return
    end

    gardenCont:ClearAllChildren()
    newGarden:Clone().Parent = gardenCont
end

local function updatePlotSign(plotId: number, plr: Player, plrLeaving: boolean?)
    local plot = Plots:FindFirstChild(tostring(plotId))
    local main = plot and plot:FindFirstChild("Main")
    local stand = main and main:FindFirstChild('Stand')
    local part = stand and (stand:FindFirstChild("Primary") or stand.PrimaryPart)
    local gui = part and part:FindFirstChildWhichIsA("SurfaceGui")
    local plrImage = gui and gui:FindFirstChild("PlayerImage")
    local plrName = gui and gui:FindFirstChild("PlayerName")
    if plrImage and plrName then 
        plrName.Text = plrLeaving and "" or plr.Name
        
        if plrLeaving then 
            plrImage.Image = ""
        else
            local s, r = pcall(function(...)
                return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
            end)

            if s and r then
                plrImage.Image = r
            end
        end
    end
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
    task.spawn(updatePlotSign, id, plr, true)
    updatePlotSign(id, plr, true)
end

function PlotServer.onPlrAdded(self: PlotServer, plr: Player)
    if self.PlotOf[plr] then return end

    local plot = getAvailablePlot(self)
    local id = plot and tonumber(plot.Name)
    if not plot or not id then
        moveToDifferentServer(plr)
        return
    end

    self.Plots[id] = plr
    self.PlotOf[plr] = id

    local profile = Data[plr] or Data.Service:waitForData(plr)
    if not profile or not plr:IsDescendantOf(Players) then return end

    local spawnPoint = getSpawnPart(plot)
    if not spawnPoint then
        warn("Plot " .. plot.Name .. " is missing a spawn location!")
        return
    end

    plr.RespawnLocation = spawnPoint
    if plr.Character then
        plr.Character:PivotTo(getSpawnCFrame(spawnPoint))
    end

    task.spawn(updatePlotSign, id, plr)
    self:connectData(plr, profile)

    Signals.plotAssigned:Fire(plr, id)
end

function PlotServer.getPlotCFrame(self: PlotServer, plr: Player): CFrame?
    local id = self.PlotOf[plr]
    return id and getPlotCFrame(id)
end

function PlotServer.getGardenPosition(self: PlotServer, plr: Player): Vector3?
    local id = self.PlotOf[plr]
    if not id then return nil end

    local cframe = getGardenArea(id)
    return cframe and cframe.Position
end

function PlotServer.getSpawnCFrame(self: PlotServer, plr: Player): CFrame?
    local id = self.PlotOf[plr]
    local spawnPart = id and getSpawnPart(Plots:FindFirstChild(tostring(id)))
    return spawnPart and getSpawnCFrame(spawnPart)
end

function PlotServer.waitForPlotCFrame(self: PlotServer, plr: Player, timeout: number?): CFrame?
    local deadline = os.clock() + (timeout or 15)

    while plr.Parent == Players and os.clock() < deadline do
        local cframe = self:getPlotCFrame(plr)
        if cframe then
            return cframe
        end

        task.wait(0.1)
    end

    return nil
end

function PlotServer.getNearestPlotCFrame(self: PlotServer, pos: Vector3): CFrame?
    local best: CFrame? = nil
    local bestDist = math.huge

    for _, plot in Plots:GetChildren() do
        local id = tonumber(plot.Name)
        local cframe = id and getPlotCFrame(id)

        if cframe then
            local dist = (cframe.Position - pos).Magnitude

            if dist < bestDist then
                best, bestDist = cframe, dist
            end
        end
    end

    return best
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

    local cframe, size = getGardenArea(id)
    if not cframe or not size then return false end

    local relative = cframe:PointToObjectSpace(pos)

    return math.abs(relative.X) <= size.X / 2 and math.abs(relative.Z) <= size.Z / 2
end

type PlotServer = typeof(PlotServer) & {
    Plots: {[number]: Player},
    PlotOf: {[Player]: number},
    Janitor: typeof(Janitor.new()),
}

return PlotServer :: PlotServer