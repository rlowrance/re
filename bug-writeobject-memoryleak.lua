-- bug-writeobject-memoryleak.lua
-- demonstrate memory leak in torch.writeObject

require 'torch'

local function append(outputFile, count)
   local tensor = torch.rand(100000)
   print('appending', count)
   outputFile:writeObject(tensor)
   --collectgarbage()
end

local outputFile = torch.DiskFile('/tmp/bug-writeObject-memoryleak.serialized', 'rw')
outputFile:seekEnd()
assert(outputFile)

for i = 1, 4000 do
   append(outputFile, i)
end

print('done')
