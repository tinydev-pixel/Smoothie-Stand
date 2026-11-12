local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetHUDObject = require(ReplicatedStorage.Source.Core.Platform.GetHUDObject)

local Player = Players.LocalPlayer

local db = false
local cd = 0.5

return {
    Init = function()
        task.spawn(function()
            local leftCont = GetHUDObject("Left")
            local btnsCont = leftCont and (leftCont:FindFirstChild("Buttons2") or leftCont:WaitForChild("Buttons2", 5))
            local inviteBtn = btnsCont and (btnsCont:FindFirstChild("Invite") or btnsCont:WaitForChild("Invite", 5))
            if not inviteBtn then return end

            inviteBtn.Activated:Connect(function()
                if db then return end
                db = true
                task.delay(cd, function()
                    db = false
                end)

                local success, canInvite = pcall(function()
                    return SocialService:CanSendGameInviteAsync(Player)
                end)

                if success and canInvite then
                    SocialService:PromptGameInvite(Player)
                end
            end)
        end)
    end
}