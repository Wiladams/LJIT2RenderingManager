package.path = package.path..";../?.lua"

--[[
/*
 * modeset - DRM Modesetting Example
 *
 * Written 2012 by David Herrmann <dh.herrmann@googlemail.com>
 * Dedicated to the Public Domain.

	Reference: https://github.com/dvdhrm/docs/blob/master/drm-howto/modeset.c
 */
--]]

local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("xf86drm_ffi")()
local xf86drmMode = require("xf86drmMode_ffi")()
local utils = require("test_utils")()

local DRM = {}
function DRM.available(self)
	return drmAvailable() == 1;
end

function DRM.open(self, nodename)
	nodename = nodename or "/dev/dri/card0";
	local flags = bor(O_RDWR, O_CLOEXEC);
print(string.format("Flags: 0x%x", flags));
	local fd = open(nodename, flags)
	return fd;
end

local function test_available()
	print("Available: ", DRM:available());
end

local function test_open()
	local res = DRM:open();

	print("DRM:open: ", res, strerror(ffi.errno()));
end

test_available();
test_open();
