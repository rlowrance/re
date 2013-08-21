-- DiagonalMatrix-test.lua

require 'DiagonalMatrix'
require 'Tester'

test = {}
tester = Tester()

function test.mulMatrix()
   local v = makeVerbose(true, 'test.one')

   d = torch.Tensor(3)
   d[1] = 1
   d[2] = 2
   d[3] = 3

   a = torch.Tensor(3,4)
   for i = 1, 3 do
      for j = 1, 4 do
         a[i][j] = 10 * i + j
      end
   end
   r = DiagonalMatrix(d):mul(a)
   v('r', r)

   tester:assert(2, r:nDimension())
   tester:assert(3, r:size(1))
   tester:assert(4, r:size(2))

   tester:asserteq(11, r[1][1])
   tester:asserteq(12, r[1][2])
   tester:asserteq(13, r[1][3])
   tester:asserteq(14, r[1][4])

   tester:asserteq(42, r[2][1])
   tester:asserteq(44, r[2][2])
   tester:asserteq(46, r[2][3])
   tester:asserteq(48, r[2][4])

   tester:asserteq(93, r[3][1])
   tester:asserteq(96, r[3][2])
   tester:asserteq(99, r[3][3])
   tester:asserteq(102, r[3][4])

end -- mulMatrix

function test.mulVector()
   local v = makeVerbose(true, 'test.one')
   d = torch.Tensor(3)
   d[1] = 1
   d[2] = 2
   d[3] = 3

   vector = torch.Tensor(3)
   for i = 1, 3 do
      vector[i] = 10 + i
   end

   r = DiagonalMatrix(d):mul(vector)
   v('r', r)
   
   tester:asserteq(1, r:nDimension())
   tester:asserteq(3, r:size(1))

   tester:asserteq(11, r[1])
   tester:asserteq(24, r[2])
   tester:asserteq(39, r[3])
end -- mulVector
      
tester:add(test)
tester:run(true) -- true ==> verbose
