local ffi = require("ffi")
local xf86drmMode = require("xf86drmMode_ffi")
local lookupDrmEnum = xf86drmMode.drm_mode.lookupDrmEnum;

--[[
typedef struct _drmModeEncoder {
  uint32_t encoder_id;
  uint32_t encoder_type;
  uint32_t crtc_id;
  uint32_t possible_crtcs;
  uint32_t possible_clones;
} drmModeEncoder, *drmModeEncoderPtr;
--]]

local DRMEncoder = {}
setmetatable(DRMEncoder, {
	__call = function(self, ...)
		return self:new(...);
	end,
})

local DRMEncoder_mt = {
	__index = DRMEncoder;

	__tostring = function(self)
		return self:toString();
	end,
}

function DRMEncoder.init(self, info)
	local obj = {
		Handle = info;

		EncoderId = info.encoder_id;
		EncoderType = info.encoder_type;
		EncoderTypeName = lookupDrmEnum("DRM_MODE_ENCODER", info.encoder_type);
		CRTCId = info.crtc_id;
		PossibleCRTCs = info.possible_crtcs;
		PossibleClones = info.possible_clones;
	}
	setmetatable(obj, DRMEncoder_mt);

	return obj;
end

function DRMEncoder.new(self, fd, encoder_id)
	local enc = xf86drmMode.drmModeGetEncoder(fd, encoder_id);
	if enc == nil then
		return false, "could not get encoder"
	end

	ffi.gc(enc, xf86drmMode.drmModeFreeEncoder);

	return self:init(enc);
end

function DRMEncoder.toString(self)
	return string.format([[
             Id: %d
           Type: %d
           Name: %s
         CRTCId: %d
 Possible CRTCs: %d
Possible Clones: %d
]],
	self.EncoderId,
	self.EncoderType,
	self.EncoderTypeName,
	self.CRTCId,
	self.PossibleCRTCs,
	self.PossibleClones
);
end

return DRMEncoder;
