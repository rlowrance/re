-- Accumulators.lua

if false then
   a = Accumulators()
   a:add1('name')
   a:add('name', 23)
   a:addTable({x = 10, y = 20})
   a:addAccumulators(a)

   for k, v in pairs(a:getTable()) do
      -- key = name
      -- value = accumulated amount
   end
end

require 'torch'

torch.class('Accumulators')

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

function Accumulators:__init()
   self.table = {}
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

function Accumulators:add(name, amount)
   assert(type(amount) == 'number', 'amount not a number; amount = ' .. tostring(amount))
   self.table[name] = (self.table[name] or 0) + amount
end

function Accumulators:add1(name)
   self:add(name, 1)
end

function Accumulators:addAccumulators(other)
   self:addTable(other:getTable())
end

function Accumulators:addTable(table)
   assert(table ~= nil, 'table is nil')
   for k, v in pairs(table) do
      self:add(k, v)
   end
end

function Accumulators:getTable()
   return self.table
end
