local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local Loom = require(ReplicatedStorage.Source.Core.Utils.Loom)

local Player = Players.LocalPlayer

local FramesManager = {}

function FramesManager.connFrames(self: FramesManager, frames: Frame)
    local function onChildAdded(inst: Instance)
        if inst:IsA("Frame") then
            local title = inst:FindFirstChild("Title") or inst:WaitForChild("Title", 5)
            local closeBtn = title and (title:FindFirstChild("Close") or title:WaitForChild("Close", 5))
            if closeBtn then
                closeBtn.Activated:Connect(function()
                    Loom.Close(inst)
                end)
            end
        end
    end

    frames.ChildAdded:Connect(function(inst: Instance)
        onChildAdded(inst)
    end)

    for _, inst in frames:GetChildren() do
        task.spawn(onChildAdded, inst)
    end
end

function FramesManager.connHUD(self: FramesManager, hud: Frame)
    local function onDescAdded(inst: Instance)
        if inst:IsA("GuiButton") then
            local frame = GetFrame(inst.Name)
            if not frame then return end

            inst.Activated:Connect(function(a0: InputObject, a1: number)
                if Loom.GetCurrentFrame() == frame then
                    Loom.Close(frame)
                else 
                    Loom.Open(frame)
                end
            end)
        end
    end

    hud.DescendantAdded:Connect(function(inst: Instance)
        onDescAdded(inst)
    end)

    for _, inst in hud:GetDescendants() do
        task.spawn(onDescAdded, inst)
    end
end

function FramesManager.Init(self: FramesManager)
    task.spawn(function()
        local gui = Player.PlayerGui or Player:WaitForChild("PlayerGui", 5)
        local main = gui and (gui:FindFirstChild("Main") or gui:WaitForChild("Main", 5))
        local frames = main and (main:FindFirstChild("Frames") or main:WaitForChild("Frames", 5))
        local hud = main and (main:FindFirstChild("HUD") or main:WaitForChild("HUD", 5))
        if not hud or not frames then return end

        task.spawn(self.connFrames, self, frames)
        task.spawn(self.connHUD, self, hud)
    end)
end

type FramesManager = typeof(FramesManager)

return FramesManager :: FramesManager