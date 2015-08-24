local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local exports = {
	S_IFMT   = 00170000;
	S_IFSOCK = 0140000;
	S_IFLNK	 = 0120000;
	S_IFREG  = 0100000;
	S_IFBLK  = 0060000;
	S_IFDIR  = 0040000;
	S_IFCHR  = 0020000;
	S_IFIFO  = 0010000;
	S_ISUID  = 0004000;
	S_ISGID  = 0002000;
	S_ISVTX  = 0001000;

	S_ISLNK	= function(m) return (band((m), S_IFMT) == S_IFLNK) end;
	S_ISREG	= function(m) return (band((m), S_IFMT) == S_IFREG) end;
	S_ISDIR	= function(m) return (band((m), S_IFMT) == S_IFDIR) end;
	S_ISCHR	= function(m) return (band((m), S_IFMT) == S_IFCHR) end;
	S_ISBLK	= function(m) return (band((m), S_IFMT) == S_IFBLK) end;
	S_ISFIFO	= function(m) return (band((m), S_IFMT) == S_IFIFO) end;
	S_ISSOCK	= function(m) return (band((m), S_IFMT) == S_IFSOCK) end;

	S_IRWXU = 00700;
	S_IRUSR = 00400;
	S_IWUSR = 00200;
	S_IXUSR = 00100;

	S_IRWXG = 00070;
	S_IRGRP = 00040;
	S_IWGRP = 00020;
	S_IXGRP = 00010;

	S_IRWXO = 00007;
	S_IROTH = 00004;
	S_IWOTH = 00002;
	S_IXOTH = 00001;
}

setmetatable(exports, {
	__call = function(self, ...)
		for k,v in pairs(self) do
			_G[k]=v;
		end

		return self;
	end,

})

return exports
