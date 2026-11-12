return {
    RestockTime = 300,

    Order = {
        "Carrot",
        "Apple"
    },

    Data = {
        ["Carrot"] = {
            Cost = 2,
            Chance = 100,
            Stock = {
                Min = 3,
                Max = 6
            }
        },
        ["Apple"] = {
            Cost = 35,
            Chance = 25,
            Stock = {
                Min = 1,
                Max = 3
            }
        }
    }
}