--[[
	Draw on the frame buffer of the current default crtc

	The way to go about drawing to the current screen, without changing modes is:
		Create a card
			From that card, get the first connection that's actually connected to something
				From there, get the encoder it's using
					From there, get the crt controller associated with the encoder
						From there, get the framebuffer associated with the controller
							From there, we have the width, height, pitch, and data ptr
		
		So, that's enough to do some drawing
--]]

package.path = package.path..";../?.lua"

local ffi = require("ffi")
local bit = require("bit")
local bor, band, lshift, rshift = bit.bor, bit.band, bit.lshift, bit.rshift

--local xf86drmMode = require("xf86drmMode_ffi")
local libc = require("libc")
local utils = require("utils")

local DRMCard = require("DRMCard")


local function drawLines(fb)
	local shade = 127
	local color = band(0xFFFFFF, bor(lshift(0x00, 16), lshift(shade, 8), shade))
	for i = 1, 400 do
		utils.h_line(fb, 10+i, 10+i, i, color)
	end
end

local card, err = DRMCard();

local fb = card:getDefaultFrameBuffer();
fb.DataPtr = fb:getDataPtr();

print("fb: [bpp, depth, pitch]: ", fb.BitsPerPixel, fb.Depth, fb.Pitch)

-- Draw some stuff on our new framebuffer
drawLines(fb)


-- sleep for a little bit of time
-- just so we can see what's there
libc.sleep(3);

