
local GearServiceUtils = {}

GearServiceUtils.List = {
    "Shovel"
}

function GearServiceUtils.isGear(name: string?): boolean
    if not name or typeof(name) ~= "string" then return end
    return table.find(GearServiceUtils.List, name)
end 

type GearServiceUtils = typeof(GearServiceUtils)

return GearServiceUtils :: GearServiceUtils