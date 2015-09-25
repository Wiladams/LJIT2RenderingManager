local ffi = require("ffi")
local xf86drmMode = require("xf86drmMode_ffi")
local xf86drm = require("xf86drm_ffi")
local drm = require("drm")



local DRMFrameBuffer = {}
setmetatable(DRMFrameBuffer, {
	__call = function(self, ...)
		return self:new(...);
	end,
})
local DRMFrameBuffer_mt = {
	__index = DRMFrameBuffer;
	__tostring = function(self)
		return self:toString();
	end;
}

--[[
typedef struct _drmModeFB {
  uint32_t fb_id;
  uint32_t width, height;
  uint32_t pitch;
  uint32_t bpp;
  uint32_t depth;
  /* driver specific handle */
  uint32_t handle;
} drmModeFB, *drmModeFBPtr;
--]]


function DRMFrameBuffer.init(self, fd, rawInfo)
	local obj = {
		RawInfo = rawInfo;

		Id = rawInfo.fb_id;
		Width = rawInfo.width;
		Height = rawInfo.height;
		Pitch = rawInfo.pitch;
		BitsPerPixel = rawInfo.bpp;
		Depth = rawInfo.depth;

		DriverHandle = rawInfo.handle;
	}	
	setmetatable(obj, DRMFrameBuffer_mt)

	return obj;
end

function DRMFrameBuffer.new(self, fd, bufferId)
	local rawInfo =  xf86drmMode.drmModeGetFB(fd, bufferId);
	if rawInfo == nil then return nil, "could not get FB" end

	ffi.gc(rawInfo, xf86drmMode.drmModeFreeFB);

	return self:init(fd, rawInfo);
end

--[[
/* create a dumb scanout buffer */
struct drm_mode_create_dumb {
	uint32_t height;
	uint32_t width;
	uint32_t bpp;
	uint32_t flags;
	/* handle, pitch, size will be returned */
	uint32_t handle;
	uint32_t pitch;
	uint64_t size;
};
--]]
function DRMFrameBuffer.newScanoutBuffer(self, card, width, height, bpp)
	local fd = card.Handle;
	local creq = ffi.new("struct drm_mode_create_dumb");
	local mreq = ffi.new("struct drm_mode_map_dumb");

	creq.width = width;
	creq.height = height;
	creq.bpp = bpp;

	if (xf86drm.drmIoctl(fd, drm.DRM_IOCTL_MODE_CREATE_DUMB, creq) < 0) then
		return nil, "drmIoctl DRM_IOCTL_MODE_CREATE_DUMB failed";
	end

	-- upon return, the handle, pitch and size fields of the struct will
	-- be filled in.

end

function DRMFrameBuffer.toString(self)
	return string.format([[
           Id: %d 
         Size: %d X %d 
        Pitch: %d 
 BitsPerPixel: %d 
        Depth: %d 
Driver Handle: %#x
]],
	self.Id,
	self.Width, self.Height,
	self.Pitch,
	self.BitsPerPixel,
	self.Depth,
	self.DriverHandle);
end


return DRMFrameBuffer
