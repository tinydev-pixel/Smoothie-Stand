local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Flash = require(ReplicatedStorage.Source.Core.Platform.Flash)
local PlaySoundInSpace = require(ReplicatedStorage.Source.Core.Platform.PlaySoundInSpace)
local Info = require(ReplicatedStorage.Source.Game.Assets.Info)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)
local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local Networker = require(ReplicatedStorage.Source.Packages.Networker)
local Spring = require(ReplicatedStorage.Source.Packages.Spring)

local cooldown = 0.5

local ButtonClient = {}
ButtonClient.__index = ButtonClient

function ButtonClient.onTouched(self: ButtonClient)
    Flash.play(self.btn)
    PlaySoundInSpace(SoundIds.Button, self.btn)

    local spring = Spring.new(self.startPos)
    spring.Damping = 0.8
    spring.Frequency = 2
    spring.Target = self.endpos

    local startTime = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt: number)
        spring:Update(dt)
        self.btn.Position = spring.Position

        local finished = (spring.Position - self.endpos).Magnitude < 0.1 
        if finished or os.clock() - startTime > 5 then
            conn:Disconnect()
            
            local startTime2 = os.clock()
            local spring2 = Spring.new(self.endpos)
            spring2.Damping = 0.6
            spring2.Frequency = 2
            spring2.Target = self.startPos

            local conn2
            conn2 = RunService.Heartbeat:Connect(function(dt: number)
                spring2:Update(dt)
                self.btn.Position = spring2.Position

                local finished2 = (spring2.Position - self.startPos).Magnitude < 0.1 
                if finished2 or os.clock() - startTime2 > 5 then
                    conn2:Disconnect()
                end
            end)
        end
    end)
end

function ButtonClient.destroy(self: ButtonClient)
    self.janitor:Cleanup()
end

function ButtonClient.new(btn: Model, net: typeof(Networker.client), btnType: string)
    local self = setmetatable({}, ButtonClient) :: ButtonClient

    self.debounce = false
    self.btnType = btnType
    self.btn = btn.PrimaryPart or btn:WaitForChild("Primary", 5)
    self.startPos = self.btn.Position
    self.endpos = self.startPos - Vector3.new(0, 0.35, 0)
    self.net = net
    self.janitor = Janitor.new()

    self.janitor:Add(
        self.btn.Touched:Connect(function(part: BasePart)
            if self.debounce then return end
            self.debounce = true
            task.delay(cooldown, function()
                self.debounce = false
            end)

            if btnType == "GroupRewards" then
                if not Players.LocalPlayer:IsInGroupAsync(Info.groupId) then
                    GroupService:PromptJoinAsync(Info.groupId) 
                    return
                end
            end

            self.net:fire("btnActivated", self.btnType)
            self:onTouched()
        end), "Disconnect"
    )

    return self
end

type ButtonClient = typeof(ButtonClient) & {
    btn: Part, 
    net: typeof(Networker.client),
    btnType: string,
    janitor: typeof(Janitor.new()),
    debounce: boolean,
    startPos: Vector3,
    endpos: Vector3
}

return ButtonClient :: ButtonClient