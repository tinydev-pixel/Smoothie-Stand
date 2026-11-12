local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetFrame = require(ReplicatedStorage.Source.Core.Platform.GetFrame)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local db = false
local cd = 0.5

local CodesServiceClient = {}

function CodesServiceClient.Init(self: CodesServiceClient)
    self.net = Networker.client.new("Codes", self)

    task.spawn(function()
        local frame = GetFrame("Codes")
        local textbox = frame and (frame:FindFirstChild("TextBox") or frame:WaitForChild("TextBox", 5)) :: TextBox
        local claimBtn = frame and (frame:FindFirstChild("Claim") or frame:WaitForChild("Claim", 5)) :: GuiButton
        if not textbox or not claimBtn then return end

        claimBtn.Activated:Connect(function(a0: InputObject, a1: number)
            local t = textbox.Text 
            if t == "" then return end

            if db then return end
            db = true
            task.delay(cd, function()
                db = false
            end)

            self.net:fire("claimCode", t)
        end)
    end)
end

type CodesServiceClient = typeof(CodesServiceClient) & {
    net: typeof(Networker.client)
}

return CodesServiceClient