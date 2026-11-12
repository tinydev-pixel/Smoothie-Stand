local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loom = require(ReplicatedStorage.Source.Core.Utils.Loom)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)

local Player = Players.LocalPlayer

local ButtonUX = {}

function ButtonUX.onDescAdded(self: ButtonUX, inst: Instance)
    if not inst:IsA("GuiButton") then return end
    Loom.Hover(inst)
end

function ButtonUX.Init(self: ButtonUX)
    Loom.SetClickSound(SoundIds.Click)

    task.spawn(function()
        local gui = Player.PlayerGui
        if not gui then repeat task.wait() until gui == Player.PlayerGui end

        gui.DescendantAdded:Connect(function(inst: Instance)
            self:onDescAdded(inst)
        end)

        for _, inst in gui:GetDescendants() do
            task.spawn(self.onDescAdded, self, inst)
        end
    end)
end

type ButtonUX = typeof(ButtonUX)

return ButtonUX :: ButtonUX