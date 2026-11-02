--!strict
--[[
	FlashModule (ModuleScript)

	Plays a white "flash" highlight on a Model or BasePart by tweening a
	Highlight instance's transparency in and out.

	Usage:
		local Flash = require(path.to.FlashModule)

		-- Basic flash
		Flash.play(workspace.Enemy)

		-- With options
		Flash.play(workspace.Enemy.Head, {
			Color = Color3.new(1, 1, 1),
			FadeIn = 0.05,
			FadeOut = 0.25,
			Peak = 0,          -- FillTransparency at brightest point (0 = solid white)
			Repeats = 2,       -- number of flashes
			Outline = true,
		})

		-- Wait for completion
		Flash.play(part):Wait()

		-- Cancel early
		local handle = Flash.play(model)
		handle:Cancel()
		Flash.stop(model)
]]

local TweenService = game:GetService("TweenService")

export type FlashOptions = {
	Color: Color3?,
	FadeIn: number?,
	FadeOut: number?,
	Peak: number?,
	Repeats: number?,
	Outline: boolean?,
	EasingIn: Enum.EasingStyle?,
	EasingOut: Enum.EasingStyle?,
	DepthMode: Enum.HighlightDepthMode?,
}

export type FlashHandle = {
	Cancel: (self: FlashHandle) -> (),
	Wait: (self: FlashHandle) -> (),
	Completed: RBXScriptSignal,
	IsPlaying: (self: FlashHandle) -> boolean,
}

local Flash = {}

local DEFAULTS = {
	Color = Color3.new(1, 1, 1),
	FadeIn = 0.06,
	FadeOut = 0.3,
	Peak = 0,
	Repeats = 1,
	Outline = false,
	EasingIn = Enum.EasingStyle.Quad,
	EasingOut = Enum.EasingStyle.Quad,
	DepthMode = Enum.HighlightDepthMode.Occluded,
}

-- Active flashes keyed by target so a new flash replaces the old one.
local active: { [Instance]: { cancel: () -> () } } = {}

local function resolve(options: FlashOptions?)
	local o = options or {}
	local function pick(key: string)
		local v = (o :: any)[key]
		if v == nil then
			return (DEFAULTS :: any)[key]
		end
		return v
	end
	return {
		Color = pick("Color") :: Color3,
		FadeIn = math.max(pick("FadeIn") :: number, 0),
		FadeOut = math.max(pick("FadeOut") :: number, 0),
		Peak = math.clamp(pick("Peak") :: number, 0, 1),
		Repeats = math.max(math.floor(pick("Repeats") :: number), 1),
		Outline = pick("Outline") :: boolean,
		EasingIn = pick("EasingIn") :: Enum.EasingStyle,
		EasingOut = pick("EasingOut") :: Enum.EasingStyle,
		DepthMode = pick("DepthMode") :: Enum.HighlightDepthMode,
	}
end

local function isValidTarget(target: any): boolean
	return typeof(target) == "Instance" and (target:IsA("Model") or target:IsA("BasePart"))
end

--- Stops and cleans up any flash currently playing on `target`.
function Flash.stop(target: Instance)
	local entry = active[target]
	if entry then
		entry.cancel()
	end
end

--- Plays a flash on a Model or BasePart. Returns a handle.
function Flash.play(target: Instance, options: FlashOptions?): FlashHandle
	assert(isValidTarget(target), "Flash.play expects a Model or BasePart")

	-- Replace any existing flash on this target.
	Flash.stop(target)

	local opts = resolve(options)
	local finished = Instance.new("BindableEvent")
	local playing = true
	local currentTween: Tween? = nil

	local highlight = Instance.new("Highlight")
	highlight.Name = "FlashHighlight"
	highlight.Adornee = target
	highlight.FillColor = opts.Color
	highlight.OutlineColor = opts.Color
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = opts.DepthMode
	highlight.Parent = target

	local function finish()
		if not playing then
			return
		end
		playing = false
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
		if active[target] and active[target].cancel == finish then
			active[target] = nil
		end
		if highlight.Parent then
			highlight:Destroy()
		end
		finished:Fire()
		finished:Destroy()
	end

	active[target] = { cancel = finish }

	-- If the target is removed mid-flash, clean up.
	local ancestryConn = target.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			finish()
		end
	end)

	local function tweenTo(props: { [string]: any }, time: number, style: Enum.EasingStyle, dir: Enum.EasingDirection)
		if not playing then
			return
		end
		if time <= 0 then
			for k, v in props do
				(highlight :: any)[k] = v
			end
			return
		end
		local tween = TweenService:Create(highlight, TweenInfo.new(time, style, dir), props)
		currentTween = tween
		tween:Play()
		tween.Completed:Wait()
	end

	task.spawn(function()
		for _ = 1, opts.Repeats do
			if not playing then
				break
			end
			-- Flash in: snap quickly to white.
			tweenTo({
				FillTransparency = opts.Peak,
				OutlineTransparency = opts.Outline and opts.Peak or 1,
			}, opts.FadeIn, opts.EasingIn, Enum.EasingDirection.Out)

			-- Flash out: fade away.
			tweenTo({
				FillTransparency = 1,
				OutlineTransparency = 1,
			}, opts.FadeOut, opts.EasingOut, Enum.EasingDirection.In)
		end
		ancestryConn:Disconnect()
		finish()
	end)

	local handle = {} :: any
	handle.Completed = finished.Event
	function handle:Cancel()
		ancestryConn:Disconnect()
		finish()
	end
	function handle:Wait()
		if playing then
			finished.Event:Wait()
		end
	end
	function handle:IsPlaying()
		return playing
	end

	return handle :: FlashHandle
end

return Flash