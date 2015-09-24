# LJIT2RenderingManager
LuaJIT binding to the Direct Rendering Manager (DRM) API with most X based systems

The first layer of the binding provides simple ffi.cdef so that programs can be written 
as if they were 'C'.
* drm
* drm_ffi
* drm_mode
* xf86drmMode_ffi
* xf86drm_ffi


The second level of binding is to use the few objects that make things a bit easier
* DRM
* DRMCard
* DRMCardConnector
* DRMCardMode
* DRMEncoder

Resources
* https://www.kernel.org/doc/htmldocs/drm/index.html
* http://people.freedesktop.org/~marcheu/linuxgraphicsdrivers.pdf
* http://virtuousgeek.org/blog/index.php/jbarnes/2011/10/31/writing_stanalone_programs_with_egl_and_

