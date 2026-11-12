local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Notifications = require(ReplicatedStorage.Source.Core.Utils.Notifications)
local Codes = require(ReplicatedStorage.Source.Game.Configurations.Codes)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Source.Packages.Networker)

local seedTools = ReplicatedStorage.Assets.Seeds.Tools

local CodesServiceServer = {}

function CodesServiceServer.reward(self: CodesServiceServer, plr: Player, reward: {Type: string, Amount: number})
    local msgToShow = reward.Type

    if reward.Type == "Cash" then
        Data[plr].cash(function(cash)
            return cash + reward.Amount
        end)

        msgToShow = '<font color="#00FF00">Cash</font>'
    elseif string.find(reward.Type, "Seed") then
        local seedName = reward.Type:gsub(" Seed", "")
        
        Data[plr].inventory.seeds.Insert(seedName)

        local backpack = plr.Backpack
        local tool = seedTools:FindFirstChild(reward.Type)
        local clone = tool and tool:Clone()
        if backpack and clone then 
            clone.Parent = plr.Backpack
        end

        msgToShow = '<font color="#0000FF">' .. reward.Type .. '</font>'
    end

    Notifications.Show(plr, {message = "Recieved x" .. reward.Amount .. " " .. msgToShow .. "!"})
end

function CodesServiceServer.claimCode(self: CodesServiceServer, plr: Player, code: string)
    if typeof(code) ~= "string" then return end

    local alt = string.lower(code)

    if Codes.Inactive[code] or Codes.Inactive[alt] then 
        Notifications.Show(plr, {message = "Code has expired!", color = Color3.new(1, 0, 0)})
        return
    elseif not Codes.Active[code] and not Codes.Active[alt] then
        Notifications.Show(plr, {message = "Code is invalid!", color = Color3.new(1, 0, 0)})
        return
    end

    local rewards = Codes.Active[code] or Codes.Active[alt]
    for _, reward in rewards do
        task.spawn(self.reward, self, plr, reward)
    end
end

function CodesServiceServer.Init(self: CodesServiceServer)
    Networker.server.new("Codes", self, {self.claimCode})
end

type CodesServiceServer = typeof(CodesServiceServer)

return CodesServiceServer