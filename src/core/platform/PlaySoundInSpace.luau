local Debris = game:GetService("Debris")

return function(id: number, parent: BasePart, loop: boolean?, duration: number?)
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Parent = parent

    if loop then
        sound.Looped = true
        Debris:AddItem(sound, duration)
    else
        sound.Ended:Once(function()
            sound:Destroy()
        end)
    end

    sound:Play()
end