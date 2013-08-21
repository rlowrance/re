-- test-parallel.lua
-- removal of duplicate rows from 2D Tensor

require 'all' 
require 'parallel'

function worker()
   require 'all'
   require 'parallel'

   local function equal(xs, i, j)
      for d = 1, xs:size(2) do
         if xs[i][d] ~= xs[j][d] then
            return false
         end
      end
      return true
   end -- equal

   parallel.print('Worker: ID = ' .. parallel.id)

   while true do
      local m = parallel.yield()
      print('worker ' .. parallel.id .. ' m = ' .. tostring(m))
      if m == 'break' then break end

      -- do the work
      local d = parallel.parent:receive()
      -- d.xs is 2D tensor
      -- d.i is the index
      local target = d.xs[i]
      local duplicates = {}
      for j = i + 1, d.xs:size(1) do
         if equal(d.xs, i, j) then
            duplicates[#duplicates + 1] = j
         end
      end
      local result = {}
      result.id = parallel.id
      result.i = i
      result.duplicates = duplicates
      parallel.parent:send(result)
   end
end -- worker

function createData()
   local nObs = 10
   local nDims = 3
   xs = torch.rand(nObs, nDims)
   xs[3] = xs[2]
   xs[9] = xs[2]
   xs[7] = xs[4]
   return xs
end -- createData

function send(childNumber, index, xs)
   local data = {}
   data.xs = xs
   data.i = index
   parallel.children[childNumber].send(data)
end

function parent()
   local nChildren = 2
   local xs = createData()
   parallel.print('Parent: ID = ' .. parallel.id)
   paralle.nfork(nChildren)
   parallel.children:exec(worker)
   
   -- start all the workers
   parallel.children:join()

   -- start the children
   for c = 1, nChildren do
      send(c, c)
   end

   local allDuplicates = {}
   for i = nChildren + 1, xs:size(1) - 1 do
      -- receive data from one of the children
      local received = parallel.children:receive()
      for _, duplicate in ipairs(received.duplicates) do
         allDuplicates[#allDuplicates + 1] = duplicate
      end
      send(received.id, i)
   end

   print('allDuplicates', allDuplicates)
end -- parent

-- protected execution
local ok, err = pcall(parent)
if not ok then
   print('An error occured: ' .. err)
   parallel.close()
end