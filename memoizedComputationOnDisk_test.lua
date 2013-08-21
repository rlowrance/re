-- memoizedComputationOnDisk_test.lua
-- unit test


require 'makeVp'
require 'memoizedComputationOnDisk'

local vp = makeVp(0, 'tester')

local pathToFile = '/tmp/memoizedComputationOnDisk_test.ser'
local version = 6

-- function returning one result
local function f1(arg1)
   return arg1 + 1
end

local mcod = memoizedComputationOnDisk

local arg1 = 100
local ucv, res1 = mcod(pathToFile, version, f1, arg1)
vp(1, 'ucv', ucv, 'res1', res1)
assert(res1 == 101)  -- ucv could be true or false
local ucv, res1 = mcod(pathToFile, version, f1, arg1)
vp(1, 'ucv', ucv, 'res1', res1)
assert(ucv and res1 == 101)

local ucv, res1 = mcod(pathToFile, version, f1, arg1 + 1)
assert(not ucv)
assert(res1 == 102)

-- test 2 to 7 args
local function f2(a1, a2)
   return a1 + 1, a2 + 1
end
local ucv, r1, r2 = mcod(pathToFile, version, f2, 10, 11)
assert(not ucv and r1 == 11 and r2 == 12)
local ucv, r1, r2 = mcod(pathToFile, version, f2, 10, 11)
assert(ucv and r1 == 11 and r2 == 12)

local function f3(a1, a2, a3)
   return a1, a2, a3
end
local ucv, r1, r2, r3 = mcod(pathToFile, version, f3, 1, 2, 3)
assert(r1 == 1 and r2 == 2 and r3 == 3)
local ucv, r1, r2, r3 = mcod(pathToFile, version, f3, 1, 2, 3)
assert(ucv and r1 == 1 and r2 == 2 and r3 == 3)

local function f4(a1, a2, a3, a4)
   return a1, a2, a3, a4
end
local ucv, r1, r2, r3, r4 = mcod(pathToFile, version, f4, 1, 2, 3, 4)
assert(r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4)
local ucv, r1, r2, r3, r4 = mcod(pathToFile, version, f4, 1, 2, 3, 4)
assert(ucv and r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4)

local function f5(a1, a2, a3, a4, a5)
   return a1, a2, a3, a4, a5
end
local ucv, r1, r2, r3, r4, r5 = mcod(pathToFile, version, f5, 1, 2, 3, 4, 5)
assert(r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4 and r5 == 5)
local ucv, r1, r2, r3, r4, r5 = mcod(pathToFile, version, f5, 1, 2, 3, 4, 5)
assert(ucv and r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4 and r5 == 5)

local function f6(a1, a2, a3, a4, a5, a6)
   return a1, a2, a3, a4, a5, a6
end
local ucv, r1, r2, r3, r4, r5, r6 = mcod(pathToFile, version, f6, 1, 2, 3, 4, 5, 6)
assert(r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4 and r5 == 5 and r6 == 6)
local ucv, r1, r2, r3, r4, r5, r6 = mcod(pathToFile, version, f6, 1, 2, 3, 4, 5, 6)
assert(ucv and r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4 and r5 == 5 and r6 == 6)

local function f7(a1, a2, a3, a4, a5, a6, a7)
   return a1, a2, a3, a4, a5, a6, a7
end
local ucv, r1, r2, r3, r4, r5, r6, r7 = mcod(pathToFile, version, f7, 1, 2, 3, 4, 5, 6, 7)
assert(r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4 and r5 == 5 and r6 == 6 and r7 == 7)
local ucv, r1, r2, r3, r4, r5, r6, r7 = mcod(pathToFile, version, f7, 1, 2, 3, 4, 5, 6, 7)
assert(ucv and r1 == 1 and r2 == 2 and r3 == 3 and r4 == 4 and r5 == 5 and r6 == 6 and r7 == 7)


-- test 8 args
local status = pcall(mcod, pathToFile, version, f1, 1,2,3,4,5,6,7,8)
assert(status == false)

-- test changing the number of arguments
local ucv, r1 = mcod(pathToFile, version, f1, 100)
assert(not ucv and r1 == 101)
local ucv, r1 = mcod(pathToFile, version, f1, 200)
assert(not ucv and r1 == 201)

local ucv, r1, r2 = mcod(pathToFile, version, f2, 1, 2)
assert(not ucv and r1 == 2 and r2 == 3)

print('ok memoizedComputationOnDisk')