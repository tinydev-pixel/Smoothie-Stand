local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Audio = require(ReplicatedStorage.Source.Packages.Audio)
local FormatNumber = require(ReplicatedStorage.Source.Packages.FormatNumber)
local Data = require(ReplicatedStorage.Source.Game.Data).client

local GAIN_COLOR = Color3.fromRGB(110, 255, 130)
local LOSS_COLOR = Color3.fromRGB(255, 90, 90)
local FADE_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Currency = {}

-- Flashes the label green (gain) or red (loss), then fades back to its normal color.
-- Color doesn't depend on alignment or layout, so it looks right on any label.
local function playFlash(label: TextLabel, baseColor: Color3, gained: boolean, currentTween: Tween?): Tween
    if currentTween then
        currentTween:Cancel()
    end

    label.TextColor3 = if gained then GAIN_COLOR else LOSS_COLOR

    local tween = TweenService:Create(label, FADE_INFO, {TextColor3 = baseColor})
    tween:Play()

    return tween
end

local function onDataChanged(label: TextLabel, value: number | string, prefix: string?, suffix: string?)
    label.Text = (prefix or "") .. FormatNumber.Simple.FormatCompact(value) .. (suffix or "")
end

function Currency.new(label: TextLabel, dataType: string, nestedDataType: string?, prefix: string?, suffix: string?, soundId: any?)
    if not label or not label:IsA("TextLabel") or not dataType or not Data[dataType] then return end

    local source = Data[dataType]

    if nestedDataType then
        source = source[nestedDataType]
        if not source then return end
    end

    local audio = Audio.new()
    local baseColor = label.TextColor3
    local tween: Tween? = nil
    local lastValue = source()

    -- show the current value right away, without the flash or sound
    onDataChanged(label, lastValue, prefix, suffix)

    source.Changed(function(value: number | string)
        onDataChanged(label, value, prefix, suffix)

        local bothNumbers = type(value) == "number" and type(lastValue) == "number"
        local gained = bothNumbers and value > lastValue
        local lost = bothNumbers and value < lastValue
        lastValue = value

        if gained or lost then
            tween = playFlash(label, baseColor, gained, tween)

            -- play the sound whenever the value goes up or down
            if soundId then
                audio:PlaySFX(soundId)
            end
        end
    end)
end

type Currency = typeof(Currency)

return Currency :: Currency