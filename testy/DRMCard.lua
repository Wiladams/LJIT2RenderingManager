local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("xf86drm_ffi")()
local xf86drmMode = require("xf86drmMode_ffi")()
local utils = require("test_utils")()


local drmVersion_mt = {
	__tostring = function(self)
		return string.format([[
       Version: %d.%d.%d
          Name: %s
          Date: %s
   Description: %s
]],
	self.version_major,
	self.version_minor,
	self.version_patchlevel,
	ffi.string(self.name, self.name_len),
	ffi.string(self.date, self.date_len),
	ffi.string(self.desc, self.desc_len)
	)
	end,
}
ffi.metatype(ffi.typeof("drmVersion"), drmVersion_mt)


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
	}
	setmetatable(obj, DRMCard_mt)

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

local function stringvalue(str, default)
	default = default or ""

	if str == nil then
		return default;
	end

	return ffi.string(str)
end

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

return DRMCard
