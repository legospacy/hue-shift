--- Require ---
local Class = require("lib.hump.class")
local util = require("lib.self.util")

local beat = require("util.beat")
--- ==== ---


--- Localised functions ---
local sin = math.sin
--- ==== ---


--- Local functions ---
-- Taken from http://www.love2d.org/wiki/Chromatic_Paths
local a,b,c,d,e,f = 0.1,0.1,0.1,0.1,0.1,0.8
local function get_pixel_color(x,y, time)
	return
		sin(time + x*a)*127+128,
		sin(time*b + y*c)*127+128,
		sin(x*d+y*e-time*f)*127+128,
		255
end

local function make_image(time)
	local imagedata = love.image.newImageData(self.img_w, self.img_h)

	imagedata:mapPixel(function(x,y, r,g,b,a)
		return get_pixel_color(x,y, time)
	end)

	return love.graphics.newImage(imagedata)
end
--- ==== ---


return Class{
	init = function(self, inittimer, img_w, img_h)
		self.timer = inittimer or 0

		self.img_w = img_w or 6
		self.img_h = img_h or 6
	end,

	update = function(dt)
		self.timer = self.timer + dt
	end,

	drawbg = function(screenw, screenh)
		love.graphics.push()
		love.graphics.scale(screenw / self.img_w, screenh / self.img_h)
		love.graphics.draw(make_image(self.timer))
		love.graphics.pop()
	end,

	---

	colors = {
		player = {
			[1] = {255, 0, 0},
			[2] = {0, 255, 0},
			[3] = {0, 0, 255}
		},

		obstacle = {100, 100, 100},

		grid = {
			background = {255, 255, 255, 0.7 * 255},
			lines = {255, 255, 255, 255}
		}
	}


}