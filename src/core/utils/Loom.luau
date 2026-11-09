--!strict
--[[
	Loom
	Client-side utility for managing UI frames so that only one is open
	at a time, with an automatic background blur and a reusable hover
	and press animation helper.

	Meant to be required from LocalScripts (put it somewhere shared like
	ReplicatedStorage.Modules or StarterPlayerScripts).

	Usage:
		local Loom = require(path.to.Loom)

		Loom.Open(myFrame)
		Loom.Close(myFrame)
		Loom.Toggle(myFrame)

		Loom.Hover(myButton, {
			HoverScale = 1.05,
			IdleScale = 1,
			PressScale = 0.9,
		})
]]

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

export type HoverOptions = {
	HoverScale: number?,
	IdleScale: number?,
	PressScale: number?,
	HoverColor: Color3?,
	IdleColor: Color3?,
	PressColor: Color3?,
	TweenInfo: TweenInfo?,
}

local Loom = {}

--// Config
local BLUR_SIZE = 24
local BLUR_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FRAME_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--// Blur setup (single shared blur instance, reused if one already exists)
local function getOrCreateBlur(): BlurEffect
	local existing = Lighting:FindFirstChild("UIBlur")
	if existing and existing:IsA("BlurEffect") then
		return existing
	end

	local created = Instance.new("BlurEffect")
	created.Name = "UIBlur"
	created.Size = 0
	created.Parent = Lighting
	return created
end

local blur: BlurEffect = getOrCreateBlur()

--// Internal state
local currentFrame: GuiObject? = nil
local frameScales: {[GuiObject]: UIScale} = {}
local activeTweens: {[Instance]: Tween} = {}

local function cancelTween(instance: Instance)
	local tween = activeTweens[instance]
	if tween then
		tween:Cancel()
		activeTweens[instance] = nil
	end
end

local function playTween(instance: Instance, info: TweenInfo, goal: {[string]: any}): Tween
	cancelTween(instance)
	local tween = TweenService:Create(instance, info, goal)
	activeTweens[instance] = tween
	tween:Play()
	return tween
end

local function getScale(frame: GuiObject): UIScale
	local cached = frameScales[frame]
	if cached then
		return cached
	end

	local scale: UIScale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	frameScales[frame] = scale
	return scale
end

local function updateBlur()
	local shouldShow = currentFrame ~= nil
	playTween(blur, BLUR_TWEEN_INFO, {Size = if shouldShow then BLUR_SIZE else 0})
end

local function animateClose(frame: GuiObject)
	local scale = getScale(frame)
	local tween = playTween(scale, FRAME_TWEEN_INFO, {Scale = 0})
	tween.Completed:Once(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Completed then
			frame.Visible = false
		end
	end)
end

local function animateOpen(frame: GuiObject)
	frame.Visible = true
	local scale = getScale(frame)
	scale.Scale = 0
	playTween(scale, FRAME_TWEEN_INFO, {Scale = 1})
end

local function isPressInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

--[[
	Plays the same open-style scale tween as Loom.Open, but completely
	independent of the single-frame tracking and blur — nothing here
	affects or is affected by whatever else is open. Just pass the
	object.

	Example:
		Loom.Animate(myToast)
]]
function Loom.Animate(frame: GuiObject)
	animateOpen(frame)
end

function Loom.Release(frame: GuiObject)
	local scale = frameScales[frame]
	if scale then
		cancelTween(scale)
		frameScales[frame] = nil
	end
end

--[[
	Opens the given frame. If another frame is currently open, it is
	closed first so only one is ever visible at a time. Shows the
	shared blur while any frame is open.
]]
function Loom.Open(frame: GuiObject)
	if currentFrame == frame then
		return
	end

	if currentFrame then
		animateClose(currentFrame)
	end

	currentFrame = frame
	animateOpen(frame)
	updateBlur()
end

--[[
	Closes the given frame, but only if it is the one currently open.
	Removes the blur once nothing is open.
]]
function Loom.Close(frame: GuiObject)
	if currentFrame ~= frame then
		return
	end

	animateClose(frame)
	currentFrame = nil
	updateBlur()
end

--[[
	Closes whatever frame is open, regardless of which one it is.
]]
function Loom.CloseAll()
	if currentFrame then
		animateClose(currentFrame)
		currentFrame = nil
		updateBlur()
	end
end

--[[
	Opens the frame if it's closed, closes it if it's open.
]]
function Loom.Toggle(frame: GuiObject)
	if currentFrame == frame then
		Loom.Close(frame)
	else
		Loom.Open(frame)
	end
end

function Loom.GetCurrentFrame(): GuiObject?
	return currentFrame
end

--[[
	Sets up hover and press animations on any GuiObject (buttons, frames, etc).
	Call once per element, e.g. right after you create/parent it.

	Pressing (mouse click or touch, held or tapped) shrinks the element,
	and releasing tweens it back to the hover state if the cursor is
	still over it, or to the idle state if not.

	options (all optional):
		HoverScale  number    -- UIScale to tween to on hover (default 1.1)
		IdleScale   number    -- UIScale to return to (default 1)
		PressScale  number    -- UIScale to tween to while pressed (default 0.9)
		HoverColor  Color3    -- BackgroundColor3 to tween to on hover
		IdleColor   Color3    -- BackgroundColor3 to return to (defaults to current)
		PressColor  Color3    -- BackgroundColor3 to tween to while pressed (defaults to HoverColor)
		TweenInfo   TweenInfo -- overrides the default hover/press tween speed/style
]]
function Loom.Hover(element: GuiObject, options: HoverOptions?)
	local resolvedOptions: HoverOptions = options or {}
	local idleScale: number = resolvedOptions.IdleScale or 1
	local hoverScale: number = resolvedOptions.HoverScale or 1.1
	local pressScale: number = resolvedOptions.PressScale or 0.9
	local idleColor: Color3 = resolvedOptions.IdleColor or element.BackgroundColor3
	local hoverColor: Color3? = resolvedOptions.HoverColor
	local pressColor: Color3? = resolvedOptions.PressColor or hoverColor
	local info: TweenInfo = resolvedOptions.TweenInfo or HOVER_TWEEN_INFO

	local uiScale: UIScale = element:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Scale = idleScale
	uiScale.Parent = element

	local hovering = false
	local pressed = false

	local function refresh()
		local targetScale = idleScale
		local targetColor = idleColor

		if hovering and pressed then
			targetScale = pressScale
			targetColor = pressColor or idleColor
		elseif hovering then
			targetScale = hoverScale
			targetColor = hoverColor or idleColor
		end

		playTween(uiScale, info, {Scale = targetScale})
		if hoverColor then
			playTween(element, info, {BackgroundColor3 = targetColor})
		end
	end

	local connections: {RBXScriptConnection} = {}

	table.insert(connections, element.MouseEnter:Connect(function()
		hovering = true
		refresh()
	end))

	table.insert(connections, element.MouseLeave:Connect(function()
		hovering = false
		refresh()
	end))

	table.insert(connections, element.InputBegan:Connect(function(input: InputObject)
		if not isPressInput(input) then
			return
		end

		hovering = true
		pressed = true
		refresh()
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
		if not pressed or not isPressInput(input) then
			return
		end

		pressed = false
		if input.UserInputType == Enum.UserInputType.Touch then
			hovering = false
		end
		refresh()
	end))

	element.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		cancelTween(uiScale)
		cancelTween(element)
	end)
end

return Loom