--!strict
--[[
	FallingImages (ModuleScript, client-side)

	Screen effect: many copies of one image (or a random mix of several images)
	drop from the top of the screen to the bottom, spinning as they fall
	(like the egg shower in My Chicken Farm).

	Place in ReplicatedStorage (or StarterPlayerScripts) and require it from a LocalScript.

	USAGE
		local FallingImages = require(game.ReplicatedStorage.FallingImages)

		-- OPTIONAL but recommended: preload once (e.g. when the game loads) so the
		-- very first Play() shows the images instantly instead of waiting on a download.
		-- Accepts a single id or a table of ids.
		FallingImages.Preload(1234567890)
		FallingImages.Preload({ 1234567890, 9876543210 })

		-- simplest: just an image id
		FallingImages.Play(1234567890)

		-- multiple ids: each falling image randomly picks one of them
		FallingImages.Play({ 1234567890, 9876543210, "rbxassetid://5555555555" })

		-- with options
		local effect = FallingImages.Play({ 1234567890, 9876543210 }, {
			Count = 40,            -- how many images to drop
			SpawnWindow = 2.5,     -- seconds over which drops are staggered
			FallTime = {2, 4},     -- min/max seconds for one image to fall
			Size = {40, 90},       -- min/max size in pixels
			Spins = {-2, 2},       -- min/max full rotations during the fall (negative = counter-clockwise)
			Drift = 0.08,          -- max sideways drift (fraction of screen width)
			Easing = Enum.EasingStyle.Linear,      -- Linear = constant speed, starts moving instantly
			Direction = Enum.EasingDirection.In,
			Transparency = 0,
			DisplayOrder = 100,
			OnComplete = function() print("done") end,
		})

		effect:Stop()  -- cancel early and clean up (optional)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local FallingImages = {}

export type ImageId = number | string
export type ImageIds = ImageId | { ImageId }

export type Options = {
	Count: number?,
	SpawnWindow: number?,
	FallTime: { number }?,
	Size: { number }?,
	Spins: { number }?,
	Drift: number?,
	Easing: Enum.EasingStyle?,
	Direction: Enum.EasingDirection?,
	Transparency: number?,
	DisplayOrder: number?,
	OnComplete: (() -> ())?,
}

export type Effect = {
	Stop: (self: Effect) -> (),
	IsPlaying: (self: Effect) -> boolean,
}

local DEFAULTS = {
	Count = 20,
	SpawnWindow = 1,
	FallTime = { 1, 2 },
	Size = { 40, 90 },
	Spins = { -2, 2 },
	Drift = 0.06,
	-- Linear so images are visibly moving the instant they spawn.
	-- (Quad/In starts very slowly, which looks like a delay on short fall times.)
	Easing = Enum.EasingStyle.Linear,
	Direction = Enum.EasingDirection.In,
	Transparency = 0,
	DisplayOrder = 100,
}

-- Accepts 123456, "123456", or "rbxassetid://123456"
local function normalizeImageId(imageId: ImageId): string
	if type(imageId) == "number" then
		return "rbxassetid://" .. tostring(math.floor(imageId))
	end
	if string.find(imageId, "rbxassetid://", 1, true) or string.find(imageId, "http", 1, true) then
		return imageId
	end
	return "rbxassetid://" .. imageId
end

-- Accepts a single id or a table of ids; always returns a non-empty list of normalized strings.
local function normalizeImageIds(imageIds: ImageIds): { string }
	local list: { string } = {}
	if type(imageIds) == "table" then
		for _, id in imageIds do
			table.insert(list, normalizeImageId(id))
		end
	else
		table.insert(list, normalizeImageId(imageIds))
	end
	assert(#list > 0, "FallingImages: no image ids were provided")
	return list
end

local function range(rng: Random, pair: { number }): number
	local lo, hi = pair[1], pair[2] or pair[1]
	return rng:NextNumber(math.min(lo, hi), math.max(lo, hi))
end

-- Downloads the image(s) ahead of time so the first Play() has no loading delay.
-- Call this once early (e.g. at game start). Safe to call multiple times.
-- Accepts a single id or a table of ids.
function FallingImages.Preload(imageIds: ImageIds)
	local holders: { Instance } = {}
	for _, image in normalizeImageIds(imageIds) do
		local holder = Instance.new("ImageLabel")
		holder.Image = image
		table.insert(holders, holder)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(holders)
		end)
		for _, holder in holders do
			holder:Destroy()
		end
	end)
end

function FallingImages.Play(imageIds: ImageIds, options: Options?): Effect
	local opts = options or {}
	local count = opts.Count or DEFAULTS.Count
	local spawnWindow = opts.SpawnWindow or DEFAULTS.SpawnWindow
	local fallTime = opts.FallTime or DEFAULTS.FallTime
	local sizeRange = opts.Size or DEFAULTS.Size
	local spins = opts.Spins or DEFAULTS.Spins
	local drift = opts.Drift or DEFAULTS.Drift
	local easing = opts.Easing or DEFAULTS.Easing
	local direction = opts.Direction or DEFAULTS.Direction
	local transparency = opts.Transparency or DEFAULTS.Transparency

	local images = normalizeImageIds(imageIds)
	local rng = Random.new()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "FallingImages"
	gui.IgnoreGuiInset = true -- let images start above the top bar and cover the full screen
	gui.ResetOnSpawn = false
	gui.DisplayOrder = opts.DisplayOrder or DEFAULTS.DisplayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local playing = true
	local remaining = count
	local tweens: { Tween } = {}

	local effect = {} :: Effect

	local function finish()
		if not playing then
			return
		end
		playing = false
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
		gui:Destroy()
		if opts.OnComplete then
			task.spawn(opts.OnComplete)
		end
	end

	function effect:Stop()
		finish()
	end

	function effect:IsPlaying()
		return playing
	end

	local function drop()
		if not playing then
			return
		end

		local size = range(rng, sizeRange)
		local startX = rng:NextNumber(0, 1)
		local endX = math.clamp(startX + rng:NextNumber(-drift, drift), 0, 1)
		local duration = range(rng, fallTime)
		local startRotation = rng:NextNumber(0, 360)
		local totalSpin = range(rng, spins) * 360

		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		-- each falling image randomly picks one of the provided ids
		label.Image = images[rng:NextInteger(1, #images)]
		label.ImageTransparency = transparency
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(size, size)
		-- start just above the top edge, so it is entering the screen immediately
		label.Position = UDim2.new(startX, 0, 0, -size * 0.5)
		label.Rotation = startRotation
		label.ZIndex = rng:NextInteger(1, 10)
		label.Parent = gui

		local tween = TweenService:Create(
			label,
			TweenInfo.new(duration, easing, direction),
			{
				-- end just below the bottom edge
				Position = UDim2.new(endX, 0, 1, size),
				Rotation = startRotation + totalSpin,
			}
		)
		table.insert(tweens, tween)

		tween.Completed:Once(function()
			local index = table.find(tweens, tween)
			if index then
				table.remove(tweens, index)
			end
			label:Destroy()
			remaining -= 1
			if remaining <= 0 then
				finish()
			end
		end)

		tween:Play()
	end

	-- The first image drops RIGHT NOW (same frame as the call, no delay).
	-- The rest are staggered randomly across the spawn window.
	if count >= 1 then
		drop()
	end
	for _ = 2, count do
		task.delay(rng:NextNumber(0, spawnWindow), drop)
	end

	return effect
end

return FallingImages