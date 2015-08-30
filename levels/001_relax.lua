local level = {
	name = "relax",

	grid = {
		w = 7,
		h = 7
	},

	players = {
		[1] = {
			x = 0,
			y = 6,

			direction = "up"
		},

		[2] = {
			x = 3,
			y = 6,

			direction = "up"
		},

		[3] = {
			x = 6,
			y = 6,

			direction = "up"
		}
	},

	obstacles = {}
}

---

return level
