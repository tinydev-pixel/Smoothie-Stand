local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent.Definitions)
local Dataservice = require(ReplicatedStorage.Source.Packages.Dataservice)

local template = {
	cash = 0,
	gardenLevel = 1,
	rebirths = 0,
	inventory = {
		seeds = {"Carrot", "Carrot"} :: {string},
		fruits = {} :: {string}
	},
	plants = {} :: {Definitions.Plant},
	storage = {
		fruits = 0,
		cash = 0
	},
	upgrades = {
		drainRate = 1
	},
	lastLogin = 0,
	groupRewards = 0,
	index = {} :: {string},
	tutorial = {
		completed = false,
		step = 1
	}
} 

return Dataservice({
	template = template,
	profileStoreIndex = "Default",
	profileStoreDataPrefix = "PLAYER_",
	useMock = true,
})