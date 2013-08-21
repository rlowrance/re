-- NnwSmoother-test.lua

require 'all'

tester = Tester()
test = {}

function test.one()
   local xs = torch.rand(3, 4)
   local ys = torch.rand(3)
   local visible = torch.Tensor(3):fill(1)
   visible[2] = 0
   
   local cache = Nncache()
   
   s = NnwSmoother(xs, ys, visible, cache)
   tester:assert(s ~= nil)
   tester:asserteq(torch.typename(s), 'NnwSmoother')
end -- one




tester:add(test)
tester:run(true) -- true ==> verbose