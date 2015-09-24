local ffi = require("ffi")

ffi.cdef[[
typedef uint32_t __useconds_t;
typedef __useconds_t useconds_t;
typedef long time_t;
typedef int64_t off_t;
typedef uint16_t      mode_t;
]]

ffi.cdef[[
	void *memcpy (void *__dest, const void * __src, size_t __n) ;
	void *memset (void *__s, int __c, size_t __n) ;
	
	void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
	int munmap (void *, size_t);

	int mprotect (void *, size_t, int);
	int msync (void *, size_t, int);

	int rand (void);
	void srand (unsigned int __seed);
	int usleep (__useconds_t __useconds);
	time_t time(time_t *t);

	int open (const char *__file, int __oflag, ...);
	int close(int fd);

]]

local function printf(fmt, ...)
    io.write(string.format(fmt, ...));
end

local function fprintf(f, fmt, ...)
	f:write(string.format(fmt, ...));
end

local function stringvalue(str, default)
	default = default or ""

	if str == nil then
		return default;
	end

	return ffi.string(str)
end


local errnos = {
	-- Constants
	-- errno-base
	EPERM		= 1	; -- Operation not permitted 
	ENOENT		= 2	; -- No such file or directory 
	ESRCH		= 3	; -- No such process 
	EINTR		= 4	; -- Interrupted system call 
	EIO		= 5	; -- I/O error 
	ENXIO		= 6	; -- No such device or address 
	E2BIG		= 7	; -- Argument list too long 
	ENOEXEC		= 8	; -- Exec format error 
	EBADF		= 9	; -- Bad file number 
	ECHILD		=10	; -- No child processes 
	EAGAIN		=11	; -- Try again 
	ENOMEM		=12	; -- Out of memory 
	EACCES		=13	; -- Permission denied 
	EFAULT		=14	; -- Bad address 
	ENOTBLK		=15	; -- Block device required 
	EBUSY		=16	; -- Device or resource busy 
	EEXIST		=17	; -- File exists 
	EXDEV		=18	; -- Cross-device link 
	ENODEV		=19	; -- No such device 
	ENOTDIR		=20	; -- Not a directory 
	EISDIR		=21	; -- Is a directory 
	EINVAL		=22	; -- Invalid argument 
	ENFILE		=23	; -- File table overflow 
	EMFILE		=24	; -- Too many open files 
	ENOTTY		=25	; -- Not a typewriter 
	ETXTBSY		=26	; -- Text file busy 
	EFBIG		=27	; -- File too large 
	ENOSPC		=28	; -- No space left on device 
	ESPIPE		=29	; -- Illegal seek 
	EROFS		=30	; -- Read-only file system 
	EMLINK		=31	; -- Too many links 
	EPIPE		=32	; -- Broken pipe 
	EDOM		=33	; -- Math argument out of domain of func 
	ERANGE		=34	; -- Math result not representable 

	-- errno
	EOPNOTSUPP	= 95;	-- Operation not supported on transport endpoint
	
}

local function strerror(num)
	num = num or ffi.errno();
	for k,v in pairs(errnos) do
		if v == num then
			return k;
		end
	end

	return string.format("UNKNOWN ERROR: %d", num);
end

local function octal(val)
	return tonumber(val,8);
end

local exports = {

	-- fcntl
	O_RDONLY	= octal(00000000);
	O_WRONLY	= octal(00000001);
	O_RDWR		= octal(00000002);
	O_CLOEXEC	= octal(02000000);	-- set close_on_exec

	-- mmap
	MAP_FAILED  = ffi.cast("void *", -1);

	PROT_NONE   =   0;
	PROT_READ   =   1;
	PROT_WRITE  =   2;
	PROT_EXEC   =   4;

	MAP_SHARED  =   0x01;
	MAP_PRIVATE =   0x02;
	MAP_FIXED   =   0x10;


	fprintf = fprintf;
	printf = printf;
	strerror = strerror;
	stringvalue = stringvalue;

	-- library functions
	memcpy = ffi.C.memcpy;
	memset = ffi.C.memset;
	mmap = ffi.C.mmap;
	munmap = ffi.C.munmap;

	open = ffi.C.open;
	close = ffi.C.close;

	rand = ffi.C.rand;
	srand = ffi.C.srand;

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
