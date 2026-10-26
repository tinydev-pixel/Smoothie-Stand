--[[
	Notifications:
		Entry point for the notification package. Requiring this from anywhere - client or server -
		returns the correct interface for that context automatically, sharing one auto-created
		RemoteEvent underneath. Mirrors the require-once, context-aware pattern used by Networker.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAME = "NotificationsRemote"
local IsServer = RunService:IsServer()

local function getRemote(): RemoteEvent
	if IsServer then
		local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME) :: RemoteEvent?

		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = REMOTE_NAME
			remote.Parent = ReplicatedStorage
		end

		return remote :: RemoteEvent
	end

	return ReplicatedStorage:WaitForChild(REMOTE_NAME) :: RemoteEvent
end

local remote = getRemote()

if IsServer then
	return require(script.NotificationsServer)(remote)
else
	return require(script.NotificationsClient)(remote)
end