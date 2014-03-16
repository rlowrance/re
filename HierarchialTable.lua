-- HierarchialTable.lua
-- table with nested inner tables

if false then
   ht = HierarchialTable(3)
   ht:put(key1, key2, key3, value)
   value = ht:get(key1, key2, key)
   f = function (value) end
   ht:each(f)  -- f(key1, key2, key3, value)
   ht:eachValue(f)  -- f(value)
   ht:print(file)
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

function HierarchialTable:each(f)
   --printTableValue('self.table', self.table)
   for key1, table1 in pairs(self.table) do
      --print('key1', key1) printTableValue('table1', table1)
      for key2, table2 in pairs(table1) do
         --print('key2', key2) printTableValue('table2', table2)
         for key3, value in pairs(table2) do
            f(key1, key2, key3, value)
         end
      end
   end
end

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

function HierarchialTable:print(file)
   local function print1(key1, key2, key3, value)
      io.write(string.format('[%s][%s][%s] = %s',
                             tostring(key1),
                             tostring(key2),
                             tostring(key3),
                             tostring(value)))
      io.write('\n')
   end
   
   self:each(print1)
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
