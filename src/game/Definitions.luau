export type UpgradeNode = {
	Cost: {
		Currency: "Research" | "Cash",
		Amount: number,
	}?,

	ParentGroup: string?,
	Position: Vector2,
	IsGroup: boolean?,
	Icon: string?,
	Requirements: {string},
	StatBoosts: {string}?,
}

export type Plant = {
	Name: string,
	PlantTime: number,
	Weight: number,
	Pos: {number},
	Crops: {Crop}?,
	Space: string?
}

export type Crop = {
	Name: string,
	SpawnTime: number,
	Weight: number,
	Slot: number,
	CFrame: {number}
}

export type PlantSnapshot = {
	Id: number,
	OwnerId: number,
	Name: string,
	PlantTime: number,
	Weight: number,
	CFrame: {number},
	Crops: {Crop}
}

export type InventoryCrop = {
	Name: string,
	Weight: number
}

return {}