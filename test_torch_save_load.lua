-- test_torch_save_load.lua

require 'torch'

local x = 913062344
local file = 'test_torch_save_load.data'
local format = 'ascii'


torch.save(file, x, format)
local y = torch.load(file, format)
print(x, y)

assert(x == y)
print('ok')
