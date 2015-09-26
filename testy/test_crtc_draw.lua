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

local xf86drmMode = require("xf86drmMode_ffi")
local libc = require("libc")

local DRMCard = require("DRMCard")


local function draw(width, height, pitch, dataPtr)
	-- draw something
	bytePtr = ffi.cast("uint8_t *", dataPtr)

	for i = 0, height-1 do
		for j = 0, width-1 do
			local color = ((i * j) / (height * width)) * 0xFF;
			dataPtr[j] = band(0xFFFFFF, bor(lshift(0x00, 16), lshift(color, 8), color));
		end
		bytePtr = bytePtr + pitch;
		dataPtr = ffi.cast("uint32_t *", bytePtr)
	end
end


local card, err = DRMCard();

local fb = card:getDefaultFrameBuffer();
local dataPtr = fb:getDataPtr();


-- Draw some stuff on our new framebuffer
draw(fb.Width, fb.Height, fb.Pitch, dataPtr)


-- sleep for a little bit of time
-- just so we can see what's there
libc.sleep(3);

