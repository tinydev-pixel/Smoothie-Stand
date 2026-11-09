--[[
	Notifications (Client):
		Owns the actual UI lifecycle. Show() can be called locally, or triggered remotely by the
		server. No queue - each call creates and displays immediately, stacking alongside whatever
		else is currently visible.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Janitor = require(ReplicatedStorage.Source.Packages.Janitor)
local SoundIds = require(ReplicatedStorage.Source.Game.Assets.SoundIds)
local Audio = require(ReplicatedStorage.Source.Packages.Audio).new()

local NotificationTemplate = ReplicatedStorage.Assets.UI.Notification

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Main = PlayerGui:WaitForChild("Main")
local Frames = Main:WaitForChild("Frames")
local NotificationFrame = Frames:WaitForChild("Notifications")

local DEFAULT_DURATION = 3

local SHOW_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SHRINK_FACTOR = 0.01 -- how "small" the notification starts/ends at, relative to normal size

export type NotificationOptions = {
	message: string,
	duration: number?,
	color: Color3?,
}

export type NotificationHandle = {
	Cancel: () -> (),
}

-- Remote payload is either a normal Show() request, or a clear-all signal from the server.
export type NotificationRemotePayload = NotificationOptions | { clear: true }

-- Scales both the Scale and Offset components of a UDim2 by a factor, so the shrink/grow
-- tween works regardless of whether the template's size uses scale, offset, or both.
local function scaledSize(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		size.X.Offset * factor,
		size.Y.Scale * factor,
		size.Y.Offset * factor
	)
end

return function(remote: RemoteEvent)
	local Notifications = {}

	-- Tracks every currently-active notification's destroy function so ClearAll can blow them
	-- all away at once. Keyed by the destroy function itself for O(1) removal on self-cleanup.
	local active: { [() -> ()]: true } = {}

	function Notifications.Show(options: NotificationOptions): NotificationHandle
		local duration = options.duration or DEFAULT_DURATION

		local clone = NotificationTemplate:Clone()
		clone.Text = options.message

		if options.color then
			clone.TextColor3 = options.color
		end

		local normalSize = clone.Size
		local smallSize = scaledSize(normalSize, SHRINK_FACTOR)

		clone.Size = smallSize
		clone.Visible = true
		clone.Parent = NotificationFrame

		local janitor = Janitor.new()
		janitor:Add(clone)

		local destroyed = false
		local delayThread: thread
		local destroy: () -> ()

		destroy = function()
			if destroyed then
				return
			end
			destroyed = true

			active[destroy] = nil

			-- Guard against cancelling the thread we're currently executing inside of, which
			-- happens when destroy() is triggered by the timer expiring naturally rather than
			-- by an external Cancel() call.
			if coroutine.running() ~= delayThread and coroutine.status(delayThread) ~= "dead" then
				task.cancel(delayThread)
			end

			local hideTween = TweenService:Create(clone, HIDE_TWEEN_INFO, { Size = smallSize })

			hideTween.Completed:Connect(function()
				janitor:Cleanup()
			end)

			hideTween:Play()
		end

		active[destroy] = true

		Audio:PlaySFX(SoundIds.Notification)

		local showTween = TweenService:Create(clone, SHOW_TWEEN_INFO, { Size = normalSize })
		showTween:Play()

		delayThread = task.delay(duration, destroy)

		return {
			Cancel = destroy,
		}
	end

	function Notifications.ClearAll()
		-- Snapshot first since destroy() mutates `active` as it runs (removes itself).
		local destroyFns = {}
		for destroy in active do
			table.insert(destroyFns, destroy)
		end

		for _, destroy in destroyFns do
			destroy()
		end
	end

	remote.OnClientEvent:Connect(function(payload: NotificationRemotePayload)
		if (payload :: { clear: true }).clear then
			Notifications.ClearAll()
			return
		end

		Notifications.Show(payload :: NotificationOptions)
	end)

	return Notifications
end