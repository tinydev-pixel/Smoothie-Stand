local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FADE_IN_TIME = 0.1
local FADE_OUT_TIME = 0.9
local PEAK_TRANSPARENCY = 0

local Flashbang = {}

local activeGui: ScreenGui? = nil

function Flashbang.new(peakTransparency: number?, fadeOutTime: number?)
    local plr = Players.LocalPlayer
    local playerGui = plr and plr:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

    if activeGui then
        activeGui:Destroy()
        activeGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Flashbang"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.Parent = playerGui
    activeGui = gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 1
    frame.Active = false -- don't block clicks
    frame.Parent = gui

    local fadeIn = TweenService:Create(
        frame,
        TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = peakTransparency or PEAK_TRANSPARENCY}
    )
    local fadeOut = TweenService:Create(
        frame,
        TweenInfo.new(fadeOutTime or FADE_OUT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    )

    fadeIn.Completed:Once(function()
        fadeOut:Play()
    end)

    fadeOut.Completed:Once(function()
        gui:Destroy()
        if activeGui == gui then
            activeGui = nil
        end
    end)

    fadeIn:Play()
end

type Flashbang = typeof(Flashbang)

return Flashbang :: Flashbang