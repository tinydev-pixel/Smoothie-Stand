local t: {[string]: ColorSequence} = {
    ["Common"] = ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(140, 140, 140)),
    ["Uncommon"] = ColorSequence.new(Color3.fromRGB(120, 255, 120), Color3.fromRGB(40, 170, 60)),
    ["Rare"] = ColorSequence.new(Color3.fromRGB(100, 190, 255), Color3.fromRGB(40, 100, 230)),
    ["Epic"] = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(120, 40, 200)),
    ["Legendary"] = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 140, 20)),
    ["Mythical"] = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 80, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 160, 255)),
    }),
}

return function(rarity: string?): ColorSequence
    return t[rarity or "Common"] or t.Common
end