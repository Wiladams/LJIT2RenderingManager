local function printf(fmt, ...)
    io.write(string.format(fmt, ...));
end

local function fprintf(f, fmt, ...)
	f:write(string.format(fmt, ...));
end


local exports = {
	fprintf = fprintf;
	printf = printf;
}

setmetatable(exports, {
	__call = function(self, ...)
		for k,v in pairs(exports) do
			_G[k] = v;
		end

		return self;
	end,
})

return exports
