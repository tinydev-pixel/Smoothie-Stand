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
	Pos: {number}
}

return {}