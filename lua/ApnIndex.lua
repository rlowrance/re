-- ApnIndex.lua
-- convert APNs to sequence numbers, assigning the same sequence number to 
-- the same APNs

require 'assertEqual'

-- class to convert APNs to and from row indices
torch.class('ApnIndex')
   
--------------------------------------------------------------------------------
-- __init
--------------------------------------------------------------------------------

function ApnIndex:__init()
   self.apnTable = {}
   self.apnIndex = 0
end
   
--------------------------------------------------------------------------------
-- apn2Index
--------------------------------------------------------------------------------

-- return index associated with the APN
-- create a new association the APN is not yet associated with an index
   function ApnIndex:apn2Index(apn)
      local trace = false
      assert(type(apn) == 'string')
      assert(string.len(apn) == 10)
      local index = self.apnTable[apn]
      if index then return index end  -- have already seen this APN
      self.apnIndex = self.apnIndex + 1
      self.apnTable[apn] = self.apnIndex
      if trace then
         print('ApnIndex:apn2Index apn,index', apn, self.apnIndex)
      end
      return self.apnIndex
end

--------------------------------------------------------------------------------
-- index2Apn
--------------------------------------------------------------------------------

-- return the APN associated with an index
function ApnIndex:index2Apn(index)
   local trace = false
   assert(type(index) == 'number', index)
   assert(index > 0, index)
   if self.indexTable == nil then self:_makeIndexTable() end
   local apn = self.indexTable[index]
   assert(apn, string.format('ApnIndex:index2Apn index %f not found', index))
   if trace then
      print('ApnIndex:index2Apn index,apn', index, apn)
   end
   return apn
end

--------------------------------------------------------------------------------
-- _makeIndexTable
--------------------------------------------------------------------------------

function ApnIndex:_makeIndexTable()
   local trace = false
   self.indexTable = {}
   for k, v in pairs(self.apnTable) do
      self.indexTable[v] = k
   end
   if trace then 
      print('ApnIndex:_makeIndexTable: indexTable')
      print(self.indexTable)
   end
end


--------------------------------------------------------------------------------
-- UNIT TEST
--------------------------------------------------------------------------------

-- unit test of methods apn2Index and index2Apn
do 
   local apnIndex = ApnIndex()

   local function checkIndex(expectedIndex, apn)
      local actualIndex = apnIndex:apn2Index(apn)
      assertEqual(expectedIndex, actualIndex)
   end

   local function checkApn(expectedApn, index)
      local actualApn = apnIndex:index2Apn(index)
      assertEqual(expectedApn, actualApn)
   end

   checkIndex(1, '1230000000')
   checkIndex(1, '1230000000')
   checkIndex(2, '4560000000')
   checkIndex(1, '1230000000')
   checkIndex(2, '4560000000')
   checkIndex(3, '7890000000')

   checkApn('1230000000', 1)
   checkApn('4560000000', 2)
   checkApn('7890000000', 3)
end
