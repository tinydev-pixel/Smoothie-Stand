return function(plr: Player): Part?
    local c = plr.Character or plr.CharacterAdded:Wait(5)
    local r = c and (c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 5))
    return r
end