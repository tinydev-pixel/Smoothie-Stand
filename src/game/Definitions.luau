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
	Pos: {number},
	Fruits: {Fruit}?,
	Space: string?
}

export type Fruit = {
	Name: string,
	SpawnTime: number,
	Slot: number,
	CFrame: {number}
}

export type PlantSnapshot = {
	Id: number,
	OwnerId: number,
	Name: string,
	PlantTime: number,
	CFrame: {number},
	Fruits: {Fruit}
}

return {}