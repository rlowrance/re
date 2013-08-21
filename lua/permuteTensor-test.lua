-- permuteTensor-test.lua

require 'all'

tester = Tester()
test = {}

function test.one()
   -- 1D test
   local nObs = 3
   t = torch.Tensor(nObs)
   t[1] = 10
   t[2] = 20
   t[3] = 30

   local permutation = torch.Tensor(nObs)
   permutation[1] = 3
   permutation[2] = 1
   permutation[3] = 2

   local permuted = permuteTensor(t, permutation)
   tester:asserteq(1, permuted:nDimension())
   tester:asserteq(nObs, permuted:size(1))
   tester:asserteq(30, permuted[1])
   tester:asserteq(10, permuted[2])
   tester:asserteq(20, permuted[3])
end -- test.one

function test.two()
   -- 1D test
   local nObs = 3
   local nDims = 2
   t = torch.Tensor(nObs, nDims)
   for i = 1, nObs do
      for j = 1, nDims do
         t[i][j] = 10 * i + j
      end
   end

   local permutation = torch.Tensor(nObs)
   permutation[1] = 3
   permutation[2] = 1
   permutation[3] = 2

   local permuted = permuteTensor(t, permutation)
   tester:asserteq(2, permuted:nDimension())
   tester:asserteq(nObs, permuted:size(1))
   tester:asserteq(nDims, permuted:size(2))
   tester:asserteq(31, permuted[1][1])
   tester:asserteq(12, permuted[2][2])
   tester:asserteq(21, permuted[3][1])
end -- test.two

tester:add(test)
tester:run(true) -- true ==> verbose