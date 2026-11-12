local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Info = require(ReplicatedStorage.Source.Game.Assets.Info)

return {
    Init = function()
        task.spawn(function()
            local map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 5)
            local plaza = map and (map:FindFirstChild("Plaza") or map:WaitForChild("Plaza", 5))
            local updateArea = plaza and (plaza:FindFirstChild("Updates") or plaza:WaitForChild("Updates", 5))
            local part = updateArea and (updateArea:FindFirstChild("Screen") or updateArea:WaitForChild("Screen", 5))
            if part then
                local prompt = Instance.new("ProximityPrompt")
                prompt.ObjectText = "Next Update!"
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = 20
                prompt.Parent = part

                prompt.Triggered:Connect(function(a0: Player)
                    SocialService:PromptRsvpToEventAsync(Info.nextUpdateId)
                end)
            end
       end)
    end
}
