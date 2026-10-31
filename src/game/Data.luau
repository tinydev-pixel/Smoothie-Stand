local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent.Definitions)
local Dataservice = require(ReplicatedStorage.Source.Packages.Dataservice)

local template = {
	gardenLevel = 1,
	inventory = {
		seeds = {"Basic"} :: {string},
		crops = {} :: {}
	},
	plants = {} :: {Definitions.Plant}
} 

return Dataservice({
	template = template,
	profileStoreIndex = "Default",
	profileStoreDataPrefix = "PLAYER_",
	useMock = true,
})