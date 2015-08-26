local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("xf86drm_ffi")()
local xf86drmMode = require("xf86drmMode_ffi")()
local utils = require("test_utils")()


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



--[[
typedef struct _drmModeConnector {
  uint32_t connector_id;
  uint32_t encoder_id; /**< Encoder currently connected to */
  uint32_t connector_type;
  uint32_t connector_type_id;
  drmModeConnection connection;
  uint32_t mmWidth, mmHeight; /**< HxW in millimeters */
  drmModeSubPixel subpixel;

  int count_modes;
  drmModeModeInfoPtr modes;

  int count_props;
  uint32_t *props; /**< List of property ids */
  uint64_t *prop_values; /**< List of property values */

  int count_encoders;
  uint32_t *encoders; /**< List of encoder ids */
} drmModeConnector, *drmModeConnectorPtr;
--]]
local DRMCardConnector = {}
setmetatable(DRMCardConnector, {
	__call = function(self, ...)
		return self:new(...)
	end,
})

local DRMCardConnector_mt = {
	__index = DRMCardConnector;

	__tostring = function(self)
		return string.format([[
        ID: %d
Encoder ID: %d
      Type: %d
   Type ID: %d
 Size (mm): %dx%d

     Modes: %d
     Props: %d
  Encoders: %d
]],
	self.Id,
	self.EncoderId,
	self.Type,
	self.TypeId,
	self.MMWidth,
	self.MMHeight,
	self.ModeCount,
	self.PropsCount,
	self.EncoderCount)
	end;
}

function DRMCardConnector.init(self, conn)
	local obj = {
		Id = conn.connector_id;
		EncoderId = conn.encoder_id;
		Type = conn.connector_type;
		TypeId = conn.connector_type_id;
		MMWidth = conn.mmWidth;
		MMHeight = conn.mmHeight;

		Modes = {};
		Props = {};
		Encoders = {};

		ModeCount = conn.count_modes;
		PropsCount = conn.count_props;
		EncoderCount = conn.count_encoders;
	}

	local idx = 0;
	while (idx < tonumber(conn.count_modes) ) do
		local mode = DRMCardMode(conn.modes[idx])
		print("---- mode ----")
		print(mode);

		table.insert(obj.Modes, mode);

		idx = idx + 1;
	end

	setmetatable(obj, DRMCardConnector_mt);

	return obj;
end

function DRMCardConnector.new(self, fd, connector_id)
	local conn = drmModeGetConnector(fd, connector_id);
	if conn == nil then
		return false, strerror();
	end
	ffi.gc(conn, drmModeFreeConnector);

	return self:init(conn);
end








local function openDRMCard(nodename)
	nodename = nodename or "/dev/dri/card0";
	local flags = bor(O_RDWR, O_CLOEXEC);
	local fd = open(nodename, flags)
	if fd < 0 then 
		return false, strerror(ffi.errno());
	end

	return fd;
end


local DRMCard = {}
setmetatable(DRMCard, {
	__call = function(self, ...)
		return self:new(...)
	end,
})

local DRMCard_mt = {
	__index = DRMCard;
}

function DRMCard.init(self, fd)
	local obj = {
		Handle = fd;
		Connectors = {};
	}
	setmetatable(obj, DRMCard_mt)

	obj:prepare();

	return obj;
end

function DRMCard.new(self, cardname)
	local fd, err = openDRMCard(cardname);

	if not fd then
		return false, err;
	end

	return self:init(fd);
end

function DRMCard.getBusId(self)
	local id = drmGetBusid(self.Handle);
	if id == nil then
		return "UNKNOWN"
	end

	return ffi.string(id);
end

function DRMCard.getVersion(self)
	local ver =  drmGetVersion(self.Handle); -- drmVersionPtr
	ffi.gc(ver, drmFreeVersion);

	return ver;
end

function DRMCard.getLibVersion(self)
	local ver =  drmGetLibVersion(self.Handle); -- drmVersionPtr
	ffi.gc(ver, drmFreeVersion);

	return ver;
end

--[[
typedef struct _drmStats {
    unsigned long count;	     /**< Number of data */
    struct {
	unsigned long value;	     /**< Value from kernel */
	const char    *long_format;  /**< Suggested format for long_name */
	const char    *long_name;    /**< Long name for value */
	const char    *rate_format;  /**< Suggested format for rate_name */
	const char    *rate_name;    /**< Short name for value per second */
	int           isvalue;       /**< True if value (vs. counter) */
	const char    *mult_names;   /**< Multiplier names (e.g., "KGM") */
	int           mult;          /**< Multiplier value (e.g., 1024) */
	int           verbose;       /**< Suggest only in verbose output */
    } data[15];
} drmStatsT;
--]]



function DRMCard.getStats(self)
	local stats = ffi.new("drmStatsT");
	local res = drmGetStats(self.Handle, stats);
	if res ~= 0 then
		return false;
	end

--print("DRMCard:getStats, count: ", tonumber(stats.count));

	local tbl = {}
	local counter = tonumber(stats.count)
	while counter > 0 do
		local idx = counter - 1;
		local entry = {
			Value = stats.data[idx].value;

			LongFormat = stringvalue(stats.data[idx].long_format);
			LongName = stringvalue(stats.data[idx].long_format);
			RateFormat = stringvalue(stats.data[idx].long_format);
			RateName = stringvalue(stats.data[idx].long_format);
			MultiplierName = stringvalue(stats.data[idx].long_format);
			MultiplierValue = stats.data[idx].mult;
			IsValue = stats.data[idx].isvalue;
			Verbose = stats.data[idx].verbose;
		}

		table.insert(tbl, entry);

		counter = counter - 1;
	end

	return tbl
end

function DRMCard.hasDumbBuffer(self)
	local has_dumb_p = ffi.new("uint64_t[1]");
	local res = drmGetCap(self.Handle, DRM_CAP_DUMB_BUFFER, has_dumb_p)

	if res ~= 0 then
		return false, "EOPNOTSUPP"
	end

	return has_dumb_p[0] ~= 0;
end

function DRMCard.getConnector(self, id)
	return DRMCardConnector(self.Handle, id)
end

--[[
typedef struct _drmModeRes {

  int count_fbs;
  uint32_t *fbs;

  int count_crtcs;
  uint32_t *crtcs;

  int count_connectors;
  uint32_t *connectors;

  int count_encoders;
  uint32_t *encoders;

  uint32_t min_width, max_width;
  uint32_t min_height, max_height;
} drmModeRes, *drmModeResPtr;
--]]
function DRMCard.prepare(self)

--	struct modeset_dev *dev;

	-- retrieve resources */
	local res = drmModeGetResources(self.Handle);
	if (res == nil) then
		return false, strerror();
	end
	
	ffi.gc(res, drmModeFreeResources)

	self.Resources = {}
	print("Connectors: ", res.count_connectors);
	print("CRTCs: ", res.count_crtcs);
	print("FBs: ", res.count_fbs);
	print("Encoders: ", res.count_encoders);
	print("Min Size: ", res.min_width, res.min_height);
	print("Max Size: ", res.max_width, res.max_height);




	-- iterate all the connectors
	local count = res.count_connectors;
	while (count > 0 ) do
		local idx = count-1;

		local conn, err = self:getConnector(res.connectors[idx])
		if conn ~= nil then
			table.insert(self.Connectors, conn);
			print("== Connector ==")
			print(conn)
		end

		count = count - 1;
	end

--[[
	-- iterate all connectors 
	for (i = 0; i < res.count_connectors; ++i) {
		-- create a device structure */
		dev = malloc(sizeof(*dev));
		memset(dev, 0, sizeof(*dev));
		dev.conn = conn.connector_id;

		-- call helper function to prepare this connector */
		ret = modeset_setup_dev(fd, res, conn, dev);
		if (ret) then
			if (ret != -ENOENT) {
				errno = -ret;
				fprintf(stderr, "cannot setup device for connector %u:%u (%d): %m\n",
					i, res.connectors[i], errno);
			}
			free(dev);
			continue;
		end

		-- free connector data and link device into global list */
		dev.next = modeset_list;
		modeset_list = dev;
	}
--]]

	return true;
end

return DRMCard
