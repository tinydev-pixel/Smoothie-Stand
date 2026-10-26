return function(plr: Player): Tool?
    local c = plr.Character
    if not c then return end

    local t = c:FindFirstChildWhichIsA("Tool")
    if not t then return end

    return t
end