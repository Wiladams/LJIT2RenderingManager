
--[[
	Origin
	This code was originally inspired by the very simple mode setting example here:
		https://gist.github.com/uobikiemukot/c2be4d7515e977fd9e85

	It was substantially rewritten and simplified further to match the object model
	available in LJIT2RenderingManager.

	This test will attempt to draw something on the current framebuffer of the default 
	card.  It does not change modes, or create a new frame buffer.  It just draws on whatever
	is already setup.
]]

package.path = package.path..";../?.lua"

local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("xf86drm_ffi")()
local xf86drmMode = require("xf86drmMode_ffi")()
local utils = require("test_utils")()

local DRMCard = require("DRMCard")


local config = {
	DEPTH = 24,
	BPP = 32,
}

--[[
struct drm_dev_t {
	uint32_t *buf;
	uint32_t conn_id, enc_id, crtc_id, fb_id;
	uint32_t width, height;
	uint32_t pitch, size, handle;
	drmModeModeInfo mode;
	drmModeCrtc *saved_crtc;
	struct drm_dev_t *next;
};
--]]

local function fatal(str)

	io.stderr:write(string.format("%s\n", str));
	error(string.format("%s\n", str));
end

local function emmap(addr, len, prot, flag, fd, offset)

	local fp = ffi.cast("uint32_t *", mmap(addr, len, prot, flag, fd, offset));

	if (fp == MAP_FAILED) then
		error("mmap");
	end

	return fp;
end


local function drm_find_dev(card)
	-- get first connector
	local conn = nil;
	for _, connection in card:connections() do
		conn = connection;
		break;
	end
	if not conn then
		error("No connections found")
	end

	local firstMode = conn.Modes[1];

	local dev = {
		conn_id = conn.Id;
		enc_id = conn.EncoderId;
		mode = firstMode;
		width = firstMode.Width;
		height = firstMode.Height;

		crtc_id = conn.Encoder.CrtcId
	}

	return dev;
end


local function setup_fb(card, dev)

	local fd = card.Handle;
	local creq = ffi.new("struct drm_mode_create_dumb");
	local mreq = ffi.new("struct drm_mode_map_dumb");


	--memset(&creq, 0, sizeof(struct drm_mode_create_dumb));
	creq.width = dev.width;
	creq.height = dev.height;
	creq.bpp = config.BPP;

	if (drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, creq) < 0) then
		fatal("drmIoctl DRM_IOCTL_MODE_CREATE_DUMB failed");
	end

print("setup_fb: 1.0")

	dev.pitch = creq.pitch;
	dev.size = creq.size;
	dev.handle = creq.handle;

	local buf_idp = ffi.new("uint32_t[1]");
	if (drmModeAddFB(fd, dev.width, dev.height,
		config.DEPTH, config.BPP, dev.pitch, dev.handle, buf_idp) ~= 0) then
		fatal("drmModeAddFB failed");
	end
	dev.fb_id = buf_idp[0];

print("setup_fb: 2.0")

	mreq.handle = dev.handle;

	if (drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, mreq) ~= 0) then
		fatal("drmIoctl DRM_IOCTL_MODE_MAP_DUMB failed");
	end

print("setup_fb: 3.0")

	dev.buf = ffi.cast("uint32_t *", emmap(nil, dev.size, bor(PROT_READ, PROT_WRITE), MAP_SHARED, fd, mreq.offset));

	dev.saved_crtc = xf86drmMode.drmModeGetCrtc(fd, dev.crtc_id); -- must store crtc data

print("setup_fb: 4.0")

	--if (xf86drmMode.drmModeSetCrtc(fd, dev.crtc_id, dev.fb_id, 0, 0, &dev->conn_id, 1, &dev->mode) ~= 0) then
	if (xf86drmMode.drmModeSetCrtc(fd, dev.crtc_id, dev.fb_id, 0, 0, ffi.cast("unsigned int *",dev.conn_id), 1, dev.mode.ModeInfo) ~= 0) then
		fatal("drmModeSetCrtc() failed");
	end
print("setup_fb: 5.0")
end

local function drm_destroy(card, dev_head)
--[[
	struct drm_dev_t *devp, *devp_tmp;
	struct drm_mode_destroy_dumb dreq;

	for (devp = dev_head; devp != NULL;) {
		if (devp->saved_crtc)
			drmModeSetCrtc(fd, devp->saved_crtc->crtc_id, devp->saved_crtc->buffer_id,
				devp->saved_crtc->x, devp->saved_crtc->y, &devp->conn_id, 1, &devp->saved_crtc->mode);
		drmModeFreeCrtc(devp->saved_crtc);

		munmap(devp->buf, devp->size);

		drmModeRmFB(fd, devp->fb_id);

		memset(&dreq, 0, sizeof(dreq));
		dreq.handle = devp->handle;
		drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);

		devp_tmp = devp;
		devp = devp->next;
		free(devp_tmp);
	}

	close(fd);
--]]
end

local function draw(fbuff)
	-- draw something */
	for i = 0, dev.height-1 do
		for j = 0, dev.width-1 do
			local color = ((i * j) / (dev.height * dev.width)) * 0xFF;
			dev.buf[i * dev.width + j] = band(0xFFFFFF, bor(lshift(0x00, 16), lshift(color, 8), color));
		end
	end
end

local function main()

	-- First, get a hold of a card
	local card, err = DRMCard();

	if not card or not card:hasDumbBuffer() then 
		print("Error creating card: ", err)
		return false;
	end

	-- Get a handle on the frame buffer
	local dev = drm_find_dev(card);

	setup_fb(card, dev);

	draw(card)
	--sleep(3);

	--drm_destroy(card, dev);

	return true;
end

main()
