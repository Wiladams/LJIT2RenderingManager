local ffi = require("ffi")

--[[
typedef struct _drmModeModeInfo {
  uint32_t clock;
  uint16_t hdisplay, hsync_start, hsync_end, htotal, hskew;
  uint16_t vdisplay, vsync_start, vsync_end, vtotal, vscan;

  uint32_t vrefresh;

  uint32_t flags;
  uint32_t type;
  char name[DRM_DISPLAY_MODE_LEN];
} drmModeModeInfo, *drmModeModeInfoPtr;
--]]
local DRMCardMode = {}
setmetatable(DRMCardMode, {
	__call = function(self, ...)
		return self:new(...);
	end,
})

local DRMCardMode_mt = {
	__index = DRMCardMode;
	__tostring = function(self)
		return string.format([[
   Name: %s
  Clock: %d
   Size: %dx%d
Horizontal
  Start: %d  End: %d  Total: %d  Skew: %d
Vertical
  Start: %d  End: %d  Total: %d  Scan: %d

Refresh: %d

  Flags: %d
   Type: %d
]],
	self.Name,
	self.Clock,
	self.Width,
	self.Height,
	self.HSyncStart,
	self.HSyncEnd,
	self.HTotal,
	self.HSkew,
	self.VSyncStart,
	self.VSyncEnd,
	self.VTotal,
	self.VScan,
	self.VRefresh,
	self.Flags,
	self.Type);
	end;
}



function DRMCardMode.init(self, m)
	local obj = {
		Clock = m.clock;
		
		Width = m.hdisplay;
		HSyncStart = m.hsync_start;
		HSyncEnd = m.hsync_end;
		HTotal = m.htotal;
		HSkew = m.hskew;

		Height = m.vdisplay;
		VSyncStart = m.vsync_start;
		VSyncEnd = m.vsync_end;
		VTotal = m.vtotal;
		VScan = m.vscan;
		VRefresh = m.vrefresh;

		Flags = m.flags;
		Type = m.type;

		Name = ffi.string(m.name);
	}
	setmetatable(obj, DRMCardMode_mt)

	return obj
end

function DRMCardMode.new(self, modeInfo)
	return self:init(modeInfo)
end

function DRMCardMode.toString(self)
	return string.format([[
Name: %s
Clock: %d
Size: %dx%d
Horizontal
  Start: %d  End: %d  Total: %d  Skew: %d
Vertical
  Start: %d  End: %d  Total: %d  Scan: %d

Refresh: %d

Flags: %d
Type: %d
]],
	self.Name,
	self.Clock,
	self.Width,
	self.Height,
	self.HSyncStart,
	self.HSyncEnd,
	self.HTotal,
	self.HSkew,
	self.VSyncStart,
	self.VSyncEnd,
	self.VTotal,
	self.VScan,
	self.VRefresh,
	self.Flags,
	self.Type	);
end

return DRMCardMode;
