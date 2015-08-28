--- Require ---
local Class = require("lib.hump.class")
local timer = require("lib.hump.timer")

local util = require("lib.self.util")
--- ==== ---


--- Localised functions ---

--- ==== ---


--- Class definition ---
local Block = {}
--- ==== ---


--- Images ---
local img_arrow = love.graphics.newImage("graphics/arrow.png")
--- ==== ---


--- Local functions ---
local function lerp(a, b, t)
	return a + (a - b) * t
end
--- ==== ---


--- Class functions ---
function Block:init(args)
	self.grid = args.grid

	self.x = args.x or 0
	self.y = args.y or 0

	self.color = args.color
	self.alpha = 1

	self.fade_time = args.fade_time or 1
end

---

function Block:step()

end

---

function Block:update_alpha(beat_fraction)
	local left_time = 1 - self.fade_time
	local right_time = self.fade_time

	if beat_fraction <= left_time then
		self.alpha = util.math.map(beat_fraction, 0,left_time, 0,1)
	elseif beat_fraction >= right_time then
		self.alpha = util.math.map(beat_fraction, right_time,1, 1,0)
	else
		self.alpha = 1
	end
end

---

function Block:draw_block(draw_x, draw_y, tile_w, tile_h)
	love.graphics.setColor(self.color[1],
		self.color[2], self.color[3], 255 * self.alpha)

	love.graphics.rectangle("fill", draw_x,draw_y,
		tile_w,tile_h)
end

function Block:draw_symbol(draw_x, draw_y, tile_w, tile_h)

end

function Block:draw()
	local draw_x, draw_y = self.grid:get_pixel_coords(self.x, self.y)
	local tile_w, tile_h = self.grid.tile_w, self.grid.tile_h

	self:draw_block(draw_x, draw_y, tile_w, tile_h)
	self:draw_symbol(draw_x, draw_y, tile_w, tile_h)
end
--- ==== ---


return Class(Block)
