-- HierarchialTable.lua
-- table with nested inner tables

if false then
   ht = HierarchialTable(3)
   ht:put(key1, key2, key3, value)
   value = ht:get(key1, key2, key)
   f = function (value) end
   ht:eachValue(f)
end

require 'makeVp'
require 'printAllVariables'
require 'printTableValue'
require 'printTableVariable'
require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

torch.class('HierarchialTable')

function HierarchialTable:__init(nKeys)
   assert(type(nKeys) == 'number')
   assert(nKeys == 3, 'for now')

   self.nKeys = nKeys

   self.table = {}
end


-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

function HierarchialTable:eachValue(f)
   local function apply(t)
      for k, v in pairs(t) do
         if type(v) == 'table' then
            apply(v)
         else
            f(v)
         end
      end
   end

   apply(self.table)
end

function HierarchialTable:get(key1, key2, key3)
   assert(key1)
   assert(key2)
   assert(key3)

   local t2 = self.table[key1]
   assert(t2 == nil or type(t2) == 'table')
   if t2 ~= nil then
      local t3 = t2[key2]
      assert(t3 == nil or type(t3) == 'table')
      if t3 ~= nil then
         return t3[key3]
      end
   end
   return nil
end

function HierarchialTable:put(key1, key2, key3, value)
   assert(key1 ~= nil)
   assert(key2 ~= nil)
   assert(key3 ~= nil)

   self:_put3(key1, key2, key3, value, self.table)
end


-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

function HierarchialTable:_put3(key1, key2, key3, value, table)
   local nested = table[key1]
   if nested == nil then
      table[key1] = {}
      self:_put2(key2, key3, value, table[key1])
   else
      self:_put2(key2, key3, value, nested)
   end
end

function HierarchialTable:_put2(key2, key3, value, table)
   local nested = table[key2]
   if nested == nil then 
      table[key2] = {}
      self:_put1(key3, value, table[key2])
   else
      self:_put1(key3, value, nested)
   end
end

function HierarchialTable:_put1(key3, value, table)
   table[key3] = value
end
