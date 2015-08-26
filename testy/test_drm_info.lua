package.path = package.path..";../?.lua"


--local ffi = require("ffi")
--local bit = require("bit")
--local bor = bit.bor
--local band = bit.band

--local xf86drm = require("xf86drm_ffi")()
--local xf86drmMode = require("xf86drmMode_ffi")()
--local utils = require("test_utils")()
local DRM = require("DRM")



local function test_available()
	print("Available: ", DRM:available());
end

local function test_open()
	local res,err = DRM:open();

	print("DRM:open: ", res, err);
end

test_available();
test_open();
