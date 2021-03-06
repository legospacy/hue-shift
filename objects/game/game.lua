--- Require ---
local Class = require("lib.hump.class")
local timer = require("lib.hump.timer")

local util = require("lib.self.util")

local beat = require("util.beat")
--- ==== ---


--- Localised functions ---
local floor = math.floor
--- ==== ---


--- Classes ---
local Grid = require("objects.game.grid")

local StaticBlock = require("objects.game.blocks.static")
local DynamicBlock = require("objects.game.blocks.dynamic")
local GoalBlock = require("objects.game.blocks.goal")
--- ==== ---


--- Class definition ---
local Game = {}
--- ==== ---


--- Constants ---
local BLOCK_CONTROLS = {
	[1] = {
		up = "w",
		right = "d",
		down = "s",
		left = "a"
	},
	[2] = {
		up = "t",
		right = "h",
		down = "g",
		left = "f"
	},
	[3] = {
		up = "i",
		right = "l",
		down = "k",
		left = "j"
	}
}
--- ==== ---


--- Local functions ---
local function generate_control_functions(players)
	local funcs = {}

	for id, controls in ipairs(BLOCK_CONTROLS) do
		for dir, key in pairs(controls) do
			funcs[key] = function()
				if players[id] then
					players[id]:set_direction(dir)
				end
			end
		end
	end

	return funcs
end
--- ==== ---


--- Class functions ---
function Game:init(args)
	--- Store/initialise needed variables.
	self.level = args.level
	self.music = args.music
	self.theme = args.theme
	self.n_players = args.n_players
	self.modifiers = args.modifiers or {}

	self.state = "stopped"
	self.speed = args.speed or 1
	self._speed = self.speed

	self.blink_level = 0
	self.blink_dir = 1

	--- Setup canvas for whole-grid fading.
	self.canvas = love.graphics.newCanvas()
	self.alpha = 1

	--- Setup beat counting.
	self.last_beat = 0
	self.done_first_beat = false

	self.beat_timer = timer.new()
	self.timer = timer.new()

	--- Initialise score.
	self.score = {
		[1] = 0,
		[2] = 0,
		[3] = 0
	}

	--- Setup grid.
	self.grid = Grid{
		w = self.level.grid.w,
		h = self.level.grid.h,

		color = self.theme.grid.color
	}

	--- Setup blocks.
	self:reset_level()
end

function Game:calculate_transition_duration()
	return beat.beattosec(2, self.music.bpm * self.speed)
end

function Game:reset_level()
	--- Setup blocks.
	self.blocks = {}

	-- Setup obstacle blocks.
	self.blocks.obstacles = {}

	for i, obs_data in ipairs(self.level.obstacles) do
		local Constructor
		if obs_data.type == "static" then
			Constructor = StaticBlock
		else
			Constructor = DynamicBlock
		end

		---

		self.blocks.obstacles[i] = Constructor{
			grid = self.grid,
			color = self.theme.blocks.obstacle,

			x = obs_data.x,
			y = obs_data.y,

			direction = obs_data.direction
		}
	end

	-- Setup player and goal blocks.
	self.blocks.players = {}
	self.blocks.goals = {}

	for i = 1, self.n_players do
		self.blocks.players[i] = DynamicBlock{
			grid = self.grid,
			color = self.theme.blocks.player[i],

			x = self.level.players[i].x,
			y = self.level.players[i].y,

			direction = self.level.players[i].direction
		}

		self.blocks.goals[i] = GoalBlock{
			grid = self.grid,
			color = self.theme.blocks.player[i]
		}

		self:replace_block(self.blocks.goals[i])
	end

	-- Setup player block controls.
	self.controls = generate_control_functions(self.blocks.players)
end

--- Block operations.
function Game:for_all_blocks(func)
	for i, goal in ipairs(self.blocks.goals) do
		func(goal)
	end

	for i, player in ipairs(self.blocks.players) do
		func(player)
	end

	for i, obstacle in ipairs(self.blocks.obstacles) do
		func(obstacle)
	end
end

function Game:get_blocks_at(x, y)
	local blocks = {}

	local function check(block)
		if block.x == x and block.y == y then
			blocks[#blocks + 1] = block
		end
	end

	self:for_all_blocks(check)

	return blocks
end

function Game:replace_block(block)
	while true do
		local new_x = love.math.random(self.grid.w - 1)
		local new_y = love.math.random(self.grid.h - 1)

		if #(self:get_blocks_at(new_x, new_y)) == 0 then
			block.x = new_x
			block.y = new_y

			break
		end
	end
end

function Game:check_player_player_collisions()
	for i, player1 in ipairs(self.blocks.players) do
		for j, player2 in ipairs(self.blocks.players) do
			if player1 ~= player2 then
				if player1.x == player2.x and player1.y == player2.y then
					--player1.blink = true
					--player1.blink_dir = true

					--player2.blink = true
					--player2.blink_dir = false

					player1.ghost = true
					player2.ghost = true
				else
					--player1.blink = false
					--player2.blink = false

					player1.ghost = false
					player2.ghost = false
				end
			end
		end
	end
end

function Game:check_player_goal_collisions()
	for i, player in ipairs(self.blocks.players) do
		local goal = self.blocks.goals[i]

		if player.x == goal.x and player.y == goal.y then
			self.score[i] = self.score[i] + 1

			-- Only replace goal block after player leaves it.
			self.beat_timer.add(1, function()
				self:replace_block(goal)
			end)
		end
	end
end

function Game:check_player_obstacle_collisions()
	for i, player in ipairs(self.blocks.players) do
		for i, obstacle in ipairs(self.blocks.obstacles) do

			if player.x == obstacle.x and player.y == obstacle.y then
				self:stopping()

				player.blink = true
				player.blinkdir = true

				obstacle.blink = true
				obstacle.blinkdir = false

				-- TODO: Indicate where the player died.
				-- Along with system for highlighting overlapping blocks,
				-- specially indicate this spot with a crosshair or such.
			end
		end
	end
end

--- Game parameters.
--- States.
function Game:start()
	self.state = "running"

	self.timer.cancel(self._speed_tween or 1)
	self._speed = self.speed

	self.music:rewind()
	self.music:play()
end

function Game:stopping()
	self.state = "stopping"

	local trans_dur = self:calculate_transition_duration()

	self._speed_tween = self.timer.tween(trans_dur,
		self, {_speed = 0},
		"linear", function()
			self:stop()
		end)

	self:for_all_blocks(function(block)
		block._alpha_tween = self.timer.tween(trans_dur,
			block, {alpha = 1},
			"linear")
	end)
end

function Game:stop()
	self.state = "stopped"

	self.timer.cancel(self._speed_tween)
	self._speed = 0

	self:for_all_blocks(function(block)
		self.timer.cancel(block._alpha_tween)
		block.alpha = 1
	end)

	self.blink_level = 0
	self.blink_dir = 1
end

function Game:restart()
	self.state = "resetting"

	local trans_dur = self:calculate_transition_duration()

	self._speed_tween = self.timer.tween(trans_dur,
		self, {_speed = self.speed},
		"linear", function()
			self:reset_level()
			self:start()
		end)

	self:for_all_blocks(function(block)
		block._alpha_tween = self.timer.tween(trans_dur,
			block, {alpha = 0},
			"linear")
	end)
end

--- Updating.
function Game:step()
	--- Update beat timer.
	self.beat_timer.update(1)

	--- Step blocks in their appropriate directions.
	self:for_all_blocks(function(block)
		block:step()
	end)

	--- Check collisions.
	self:check_player_obstacle_collisions()
	self:check_player_goal_collisions()
end

function Game:update(dt)
	--- Update normal timer.
	self.timer.update(dt)

	--- Update speed.
	if self.state == "running" then
		self._speed = self.speed
	end

	--- Update beat.
	local current_beat = self.music:get_beat()

	--- Step the game on a beat EXCEPT the first.
	if floor(current_beat) ~= floor(self.last_beat) then
		if current_beat >= 2 and not self.done_first_beat then
			self.done_first_beat = true
		end

		if self.done_first_beat and self.state == "running" then
			self:step()
		end

		self:check_player_player_collisions()
	end

	--- Update music pitch.
	self.music:set_pitch(self._speed)

	--- Update theme.
	self.theme:update(dt * self._speed, self.music)

	--- Update block alpha.
	local beat_int, beat_fraction = math.modf(current_beat)

	--- Update blink.
	if self.state == "stopped" then
		self.blink_level = self.blink_level
			+ dt * 1/beat.beattosec(2, self.music.bpm) * self.blink_dir
		if not util.math.range(0, self.blink_level, 1) then
			self.blink_level = util.math.clamp(0, self.blink_level, 1)
			self.blink_dir = self.blink_dir * -1
		end
	end

	self:for_all_blocks(function(block)
		if self.state == "running" then
			block:update_alpha(beat_fraction, self.music.snappy)
		end

		if block.blink then
			if self.state == "running" then
				-- Use beat timer.
				local amp = (block.blink_dir and beat_fraction or 1 - beat_fraction)
				block.alpha = amp
			elseif self.state == "stopped" then
				-- Use a timer.
				local amp = (block.blink_dir and self.blink_level or 1 - self.blink_level)
				block.alpha = amp
			end
		end
	end)

	---

	self.last_beat = current_beat
end

-- Drawing.
function Game:draw()
	love.graphics.setColor(255, 255, 255, 255)

	--- Draw background.
	self.theme:draw_bg(love.graphics.getDimensions())

	--- Draw game.
	love.graphics.setCanvas(self.canvas)
	love.graphics.clear()

	-- Draw grid.
	self.grid:draw()

	-- Draw blocks.
	self:for_all_blocks(function(block)
		block:draw()
	end)

	love.graphics.setCanvas()

	--- Draw the canvas with the game's alpha.
	love.graphics.setColor(255, 255, 255, 255 * self.alpha)
	love.graphics.draw(self.canvas)
end

function Game:keypressed(k)
	if self.controls[k] and self.state == "running" then
		self.controls[k]()

	elseif k == "escape" then
		if self.state == "running" then
			self:stopping()
		elseif self.state == "stopping" then
			self:stop() -- Stop game immediately because player is mashing escape.
		end
	elseif k == "space" then
		if self.state == "stopping" then
			self:stop() -- Stop game immediately because player is mashing space.
		elseif self.state == "stopped" then
			self:restart()
		elseif self.state == "resetting" then
			self:reset_level()
			self:start() -- Start game immediately because player is mashing space.
		end
	end
end
--- ==== ---


return Class(Game)
