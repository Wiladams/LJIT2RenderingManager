-- modeset.lua
package.path = package.path..";../?.lua"

--[[
/*
 * modeset - DRM Modesetting Example
 *
 * Written 2012 by David Herrmann <dh.herrmann@googlemail.com>
 * Dedicated to the Public Domain.

	Reference: https://github.com/dvdhrm/docs/blob/master/drm-howto/modeset.c
 */
--]]

local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor
local band = bit.band

local xf86drm = require("xf86drm_ffi")()
local xf86drmMode = require("xf86drmMode_ffi")()
local utils = require("test_utils")()



local function modeset_open(node)

	local fd = open(node, bor(O_RDWR, O_CLOEXEC));
	if (fd < 0) then
		fprintf(io.stderr, "cannot open '%s': %m\n", node);
		return false, ffi.errno();
	end

	local has_dumb_p = ffi.new("uint64_t[1]");
	if (drmGetCap(fd, DRM_CAP_DUMB_BUFFER, has_dumb_p) < 0 or (has_dumb_p[0] == 0)) then
		fprintf(io.stderr, "drm device '%s' does not support dumb buffers\n", node);
		close(fd);
		return false, EOPNOTSUPP;
	end

	return fd;
end 


--[[
struct modeset_dev {
	struct modeset_dev *next;

	uint32_t width;
	uint32_t height;
	uint32_t stride;
	uint32_t size;
	uint32_t handle;
	uint8_t *map;

	drmModeModeInfo mode;
	uint32_t fb;
	uint32_t conn;
	uint32_t crtc;
	drmModeCrtc *saved_crtc;
};
--]]

local modeset_list = {};

--[=[
local function modeset_prepare(fd)

	drmModeRes *res;
	drmModeConnector *conn;
	unsigned int i;
	struct modeset_dev *dev;
	int ret;

	-- retrieve resources */
	local res = drmModeGetResources(fd);
	if (!res) {
		fprintf(stderr, "cannot retrieve DRM resources (%d): %m\n",
			errno);
		return -errno;
	}

	-- iterate all connectors 
	for (i = 0; i < res.count_connectors; ++i) {
		-- get information for each connector */
		conn = drmModeGetConnector(fd, res.connectors[i]);
		if (!conn) {
			fprintf(stderr, "cannot retrieve DRM connector %u:%u (%d): %m\n",
				i, res.connectors[i], errno);
			continue;
		}

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
			drmModeFreeConnector(conn);
			continue;
		end

		-- free connector data and link device into global list */
		drmModeFreeConnector(conn);
		dev.next = modeset_list;
		modeset_list = dev;
	}

	-- free resources again */
	drmModeFreeResources(res);
	return 0;
end


local function modeset_setup_dev(fd, drmModeRes *res, drmModeConnector *conn,  struct modeset_dev *dev)

	-- check if a monitor is connected */
	if (conn.connection ~= DRM_MODE_CONNECTED) then
		fprintf(io.stderr, "ignoring unused connector %u\n",
			conn.connector_id);
		return false, ENOENT;
	end

	-- check if there is at least one valid mode */
	if (conn.count_modes == 0) then
		fprintf(io.stderr, "no valid mode for connector %u\n",
			conn.connector_id);
		return false, EFAULT;
	}

	-- copy the mode information into our device structure */
	--memcpy(&dev.mode, &conn.modes[0], sizeof(dev.mode));
	dev.mode = conn.modes[0];
	dev.width = conn.modes[0].hdisplay;
	dev.height = conn.modes[0].vdisplay;
	fprintf(io.stderr, "mode for connector %u is %ux%u\n",
		conn.connector_id, dev.width, dev.height);

	-- find a crtc for this connector
	local ret = modeset_find_crtc(fd, res, conn, dev);
	if (not ret) then
		fprintf(io.stderr, "no valid crtc for connector %u\n",
			conn.connector_id);
		return ret;
	end

	-- create a framebuffer for this CRTC
	ret = modeset_create_fb(fd, dev);
	if (not ret) then
		fprintf(io.stderr, "cannot create framebuffer for connector %u\n",
			conn.connector_id);
		return ret;
	end

	return true;
end


local function modeset_find_crtc(fd, drmModeRes *res, drmModeConnector *conn,  struct modeset_dev *dev)

	drmModeEncoder *enc;
	unsigned int i, j;
	int32_t crtc;
	struct modeset_dev *iter;

	-- first try the currently conected encoder+crtc
	if (conn.encoder_id ~= 0) then
		enc = drmModeGetEncoder(fd, conn.encoder_id);
	else
		enc = nil;
	end

	if (enc) then
		if (enc.crtc_id ~= 0) then
			crtc = enc.crtc_id;
			for _,iter in ipairs(modeset_list) do
				if (iter.crtc == crtc) then
					crtc = -1;
					break;
				end
			end

			if (crtc >= 0) then
				drmModeFreeEncoder(enc);
				dev.crtc = crtc;
				return 0;
			end
		end

		drmModeFreeEncoder(enc);
	end

	--[[ If the connector is not currently bound to an encoder or if the
	 * encoder+crtc is already used by another connector (actually unlikely
	 * but lets be safe), iterate all other available encoders to find a
	 * matching CRTC. --]]
	local i = 0;
	while (i < conn.count_encoders) do
		enc = drmModeGetEncoder(fd, conn.encoders[i]);
		if (enc == nil) then
			fprintf(io.stderr, "cannot retrieve encoder %u:%u (%d): %m\n",
				i, conn.encoders[i], ffi.errno());
			continue;
		end

		-- iterate all global CRTCs 
		for (j = 0; j < res.count_crtcs; ++j) {
			-- check whether this CRTC works with the encoder */
			if (!(enc.possible_crtcs & (1 << j)))
				continue;

			-- check that no other device already uses this CRTC */
			crtc = res.crtcs[j];
			for (iter = modeset_list; iter; iter = iter.next) {
				if (iter.crtc == crtc) {
					crtc = -1;
					break;
				}
			}

			-- we have found a CRTC, so save it and return */
			if (crtc >= 0) {
				drmModeFreeEncoder(enc);
				dev.crtc = crtc;
				return 0;
			}
		}

		drmModeFreeEncoder(enc);
		i = i + 1;
	}

	fprintf(io.stderr, "cannot find suitable CRTC for connector %u\n",
		conn.connector_id);
	
	return false, ENOENT;
end



local function modeset_create_fb(int fd, struct modeset_dev *dev)

	struct drm_mode_destroy_dumb dreq;
	
	int ret;

	-- create dumb buffer
	local creq = ffi.new("struct drm_mode_create_dumb");
	creq.width = dev.width;
	creq.height = dev.height;
	creq.bpp = 32;
	local ret = drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, creq);
	if (ret < 0) then
		fprintf(stderr, "cannot create dumb buffer (%d): %m\n",
			errno);
		return false, ffi.errno();
	end

	dev.stride = creq.pitch;
	dev.size = creq.size;
	dev.handle = creq.handle;

	-- create framebuffer object for the dumb-buffer
	ret = drmModeAddFB(fd, dev.width, dev.height, 24, 32, dev.stride,
			   dev.handle, dev.fb);
	if (ret ~= 0) then
		fprintf(io.stderr, "cannot create framebuffer (%d): %m\n",
			errno);
		ret = -errno;
		goto err_destroy;
	end

	-- prepare buffer for memory mapping */
	mreq = ffi.new("struct drm_mode_map_dumb");
	mreq.handle = dev.handle;
	ret = drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, mreq);
	if (ret ~= 0) then
		fprintf(io.stderr, "cannot map dumb buffer (%d): %m\n",
			ffi.errno());
		ret = false;
		goto err_fb;
	end

	-- perform actual memory mapping */
	dev.map = mmap(0, dev.size, PROT_READ | PROT_WRITE, MAP_SHARED,
		        fd, mreq.offset);
	if (dev.map == MAP_FAILED) then
		fprintf(io.stderr, "cannot mmap dumb buffer (%d): %m\n",
			ffi.errno());
		ret = false;
		goto err_fb;
	end

	-- clear the framebuffer to 0 */
	memset(dev.map, 0, dev.size);

	return true;

err_fb:
	drmModeRmFB(fd, dev.fb);
err_destroy:
	memset(&dreq, 0, sizeof(dreq));
	dreq.handle = dev.handle;
	drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
	
	return ret;
end



local function next_color(up, uint8_t cur, mod)
	local nextone = cur;

	if up then
		nextone = nextone + rand()%mod;
	else
		nextone = nextone - rand()%mod;
	end

	if ((up and nextone < cur) or (not up and nextone > cur)) then
		up = not up;
		nextone = cur;
	end

	return nextone, up;
end


local function modeset_draw()

	uint8_t r, g, b;
	bool r_up, g_up, b_up;
	unsigned int i, j, k, off;
	struct modeset_dev *iter;

	srand(time(nil));
	local r = rand() % 0xff;
	local g = rand() % 0xff;
	local b = rand() % 0xff;
	local r_up = true;
	local g_up = true;
	local b_up = true;

	for i = 0, 49 do
		r, r_up = next_color(r_up, r, 20);
		g, g_up = next_color(g_up, g, 10);
		b, b_up = next_color(b_up, b, 5);

		for (iter = modeset_list; iter; iter = iter.next) {
			for (j = 0; j < iter.height; ++j) {
				for (k = 0; k < iter.width; ++k) {
					off = iter.stride * j + k * 4;
					*(uint32_t*)&iter.map[off] =
						     (r << 16) | (g << 8) | b;
				}
			}
		}

		usleep(100000);
	}
end



local function modeset_cleanup(fd)

	struct modeset_dev *iter;
	struct drm_mode_destroy_dumb dreq;

	while (modeset_list) {
		-- remove from global list 
		iter = modeset_list;
		modeset_list = iter.next;

		-- restore saved CRTC configuration 
		drmModeSetCrtc(fd,
			       iter.saved_crtc.crtc_id,
			       iter.saved_crtc.buffer_id,
			       iter.saved_crtc.x,
			       iter.saved_crtc.y,
			       &iter.conn,
			       1,
			       &iter.saved_crtc.mode);
		drmModeFreeCrtc(iter.saved_crtc);

		-- unmap buffer
		munmap(iter.map, iter.size);

		-- delete framebuffer
		drmModeRmFB(fd, iter.fb);

		-- delete dumb buffer
		memset(&dreq, 0, sizeof(dreq));
		dreq.handle = iter.handle;
		drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);

		-- free allocated memory
		free(iter);
	}
end
--]=]

local function main(argc, argv)

	--int ret, fd;
	--struct modeset_dev *iter;
	local nodename = "/dev/dri/card0";

	-- check which DRM device to open */
	if (argc > 0) then
		nodename = argv[1];
	end

	local card, err = DRMCard(nodename);

	if not card or not card:hasDumbBuffer() then
		fprintf(io.stderr, "could not create card: %s\n", err);
		return false;
	end


--[[
	-- prepare all connectors and CRTCs
	ret = modeset_prepare(fd);
	if (ret)
		goto out_close;

	-- perform actual modesetting on each found connector+CRTC
	for (iter = modeset_list; iter; iter = iter.next) {
		iter.saved_crtc = drmModeGetCrtc(fd, iter.crtc);
		ret = drmModeSetCrtc(fd, iter.crtc, iter.fb, 0, 0,
				     &iter.conn, 1, &iter.mode);
		if (ret)
			fprintf(stderr, "cannot set CRTC for connector %u (%d): %m\n",
				iter.conn, errno);
	}

	-- draw some colors for 5seconds
	modeset_draw();

	-- cleanup everything
	modeset_cleanup(fd);

	ret = 0;

out_close:
	close(fd);
out_return:
	if (ret) {
		errno = -ret;
		fprintf(stderr, "modeset failed with error %d: %m\n", errno);
	} else {
		fprintf(stderr, "exiting\n");
	}
	return ret;
--]]
end


main(#arg, arg)
