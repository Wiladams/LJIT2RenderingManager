--DRMEncoder.lua

local DRMEncoder = {}
setmetatable(DRMEncoder, {
	__call = function(self, ...)
		return self:new(...);
	end,
})

local DRMEncoder_mt = {
	__index = DRMEncoder;
}

--[[
ffi.cdef[[
typedef struct _drmModeEncoder {
  uint32_t encoder_id;
  uint32_t encoder_type;
  uint32_t crtc_id;
  uint32_t possible_crtcs;
  uint32_t possible_clones;
} drmModeEncoder, *drmModeEncoderPtr;
]]
--]]
function DRMEncoder.init(self, handle)
	local obj = {
		Handle = handle;	-- drmModeEncoderPtr

		Id = handle.encoder_id;
		Type = handle.encoder_type;
		CrtcId = handle.crtc_id;
		PossibleCrtcs = handle.possible_crtcs;
		PossibleClones = handle.possible_clones;
	}
	setmetatable(obj, DRMEncoder_mt);

	return obj;
end

function DRMEncoder.new(self, fd, id)
	local enc = drmModeGetEncoder(fd, id);
	
	if enc == nil then return false, "could not create encoder" end
	
	ffi.gc(enc, drmModeFreeEncoder);

	return DRMEncoder:init(enc);
end
