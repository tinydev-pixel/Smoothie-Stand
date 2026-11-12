local Debris = game:GetService("Debris")

return function(id: number, parent: BasePart, loop: boolean?, duration: number?, volume: number?): Sound
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Parent = parent

    if volume then
        sound.Volume = volume
    end

    if loop then
        sound.Looped = true

        if duration then
            Debris:AddItem(sound, duration)
        end
    else
        sound.Ended:Once(function()
            sound:Destroy()
        end)
    end

    sound:Play()

    return sound
end