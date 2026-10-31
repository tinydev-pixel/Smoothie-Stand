local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Source.Packages.Signal)

return {
    plotAssigned = Signal.new()
}