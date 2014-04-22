-- test-ffi.lua

-- ref: luajit.org/ext_ffi.html

local ffi = require 'ffi'

ffi.cdef[[
int printf(const char* fmt, ...);
]]

ffi.C.printf("Hello %s!", "world")
print('done')
