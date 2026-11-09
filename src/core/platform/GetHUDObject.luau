local Players = game:GetService("Players")
local Player = Players.LocalPlayer

return function(name: string): Frame?
    local playerGui = Player.PlayerGui or Player:WaitForChild("PlayerGui", 5)
    if not playerGui then return end

    local main = playerGui:FindFirstChild("Main") or playerGui:WaitForChild("Main", 5)
    if not main then return end

    local hud = main:FindFirstChild("HUD") or main:WaitForChild("HUD", 5)
    if not hud then return end

    return hud:FindFirstChild(name) or hud:WaitForChild(name, 5)
end