local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent.Definitions)
local Dataservice = require(ReplicatedStorage.Source.Packages.Dataservice)

local template = {
	cash = 0,
	gardenLevel = 1,
	rebirths = 0,
	inventory = {
		seeds = {"Basic"} :: {string},
		crops = {
			{
				Name = "Basic",
				Weight = 5
			},
			{
				Name = "Basic",
				Weight = 3
			}
		} :: {Definitions.InventoryCrop}
	},
	plants = {} :: {Definitions.Plant},
	storage = {
		corn = 0,
		cash = 0
	},
	upgrades = {
		drainRate = 1
	},
	lastLogin = 0,
	groupRewards = 0
} 

return Dataservice({
	template = template,
	profileStoreIndex = "Default",
	profileStoreDataPrefix = "PLAYER_",
	useMock = true,
})