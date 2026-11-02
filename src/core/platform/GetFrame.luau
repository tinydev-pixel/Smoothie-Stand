local Players = game:GetService("Players")
local Player = Players.LocalPlayer

return function(name: string): Frame?
    local playerGui = Player.PlayerGui or Player:WaitForChild("PlayerGui", 5)
    if not playerGui then return end

    local main = playerGui:FindFirstChild("Main") or playerGui:WaitForChild("Main", 5)
    if not main then return end

    local frames = main:FindFirstChild("Frames") or main:WaitForChild("Frames", 5)
    if not frames then return end

    return frames:FindFirstChild(name) or frames:WaitForChild(name, 5)
end