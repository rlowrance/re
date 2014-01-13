-- keyWithMinimumValue_test.lua
-- unit test

require 'keyWithMinimumValue'
require 'makeVp'
require 'printAllVariables'

local function testEmptyTable()
   local table = {}
   assert(keyWithMinimumValue(table) == nil)
end

testEmptyTable()

local function testFilledTable()
   local table = {one= 1, small= 0.1, ten= 10}
   assert(keyWithMinimumValue(table) == 'small')
end

testFilledTable()

local function testSequence()
   local sequence = {1, 0.1, 10}
   assert(keyWithMinimumValue(sequence) == 2)
end

testSequence()

print('ok keyWithMinimumValue')
