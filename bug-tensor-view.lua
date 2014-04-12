-- bug-tensor-view.lua
-- demonstrate possible bug in Torch
-- never submitted, as the fix is to call torch.LongTensor to construct the view

require 'torch'

-- build tensor of size 3
local tDouble = torch.Tensor{1,2,3}
local tLong = torch.LongTensor{1,2,3}

-- examine storages
print('storage for tDouble', tDouble:storage())
print('storage for tLong', tLong:storage())

-- view first 2 elements of each tensor
local viewDouble = torch.Tensor(tDouble:storage(), 1, 2, 1)  -- this works

local function verifyError(expectedErrorMessage, f, arg1, arg2, arg3, arg4)
   local statusCode, resultOrErrorMessage = pcall(f, arg1, arg2, arg3, arg4)
   assert(statusCode == false, 'statusCode = ' .. tostring(statusCode))
   local errorMessagePrefix = string.sub(resultOrErrorMessage, 1, string.len(expectedErrorMessage))
   assert(errorMessagePrefix == expectedErrorMessage, 'actual error message = ' .. resultOrErrorMessage)
end

verifyError('bad argument #2', torch.Tensor, tLong:storage(), 1, 2, 1)
local viewLong = torch.Tensor()
print('obtained expected failure')
stop()

-- if you remove the above stop() function call, the following statements will fail
local viewLong = torch.Tensor(tLong:storage(), 1, 2, 1) -- this is the pcall above

-- this version also fails
local viewLong = torch.Tensor()
viewLong:set(tLong:storage(), 1, 2)

print('ok')
