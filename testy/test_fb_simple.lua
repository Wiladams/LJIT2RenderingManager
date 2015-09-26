package.path = package.path..";../?.lua"

local bit = require("bit")
local bor, band, lshift, rshift = bit.bor, bit.band, bit.lshift, bit.rshift

local xf86drmMode = require("xf86drmMode_ffi")
local libc = require("libc")

local DRMFrameBuffer = require("DRMFrameBuffer")
local DRMCard = require("DRMCard")


local function draw(fb)
	-- draw something */
	for i = 0, fb.Height-1 do
		for j = 0, fb.Width-1 do
			local color = ((i * j) / (fb.Height * fb.Width)) * 0xFF;
			fb.DataPtr[i * fb.Width + j] = band(0xFFFFFF, bor(lshift(0x00, 16), lshift(color, 8), color));
		end
	end
end


local width = 1440
local height = 900
local bpp = 32
local card, err = DRMCard();

local fb = DRMFrameBuffer:newScanoutBuffer(card, width, height, bpp)

print("==== FRAME BUFFER PRINT ====")
print(fb)

-- Save the current mode of the card and connector we are interested in
--local savedCrtc = xf86drmMode.drmModeGetCrtc(card.Handle, dev.crtc_id); -- must store crtc data

-- switch modes to a mode using our new framebuffer
--local res = xf86drmMode.drmModeSetCrtc(card.Handle, dev.crtc_id, fb.Id, 0, 0, ffi.cast("unsigned int *",dev.conn_id), 1, dev.mode.ModeInfo)
--if res ~= 0 then
--		fatal("drmModeSetCrtc() failed");
--end

-- Draw some stuff on our new framebuffer
draw(fb)


-- sleep for a little bit of time
libc.sleep(3);

-- restore saved crtc mode