-- Set.lua
-- set of objects with supporting methods

-- API overview
if false then
   -- constructing
   s = Set()
   s = Set('abc', 123, {20})
   ss = s:clone()

   -- iterating over elements
   for _, element in pairs(s:elements()) do  end

   -- mutating a set
   s:add(element)
   s:difference(otherSet)
   s:remove(element)        -- no error if element is not in the set
   existingElement = s:removeOne()  -- remove and return random element
   s:union(otherSet)

   -- checking content
   s:equals(otherSet)   -- each a subset of the other
   s:hasElement(element)
   s:nElements()

   -- checking type
   Set.isSet(s)

   -- printing on stdout
   s:print()
end -- API overview

local Set = torch.class('Set')

-- construct from optional VARARGS
function Set:__init(...)
   self._elements = {}
   for _, element in ipairs({...}) do
      self:add(element)
   end
end

-- mutate self by adding the new element, if its not already in Set
function Set:add(element)
   local trace = false
   local me = 'Set:add: '

   if trace then
      print(me .. 'element', element)
   end

   if element == nil then
      error('element is nil')
   end
   self._elements[element] = true
end

local function newSet()
   local trace = false
   local result = torch.factory('Set')()
   if trace then 
      print('newSet result after factory', result)
   end
   result:__init()
   if trace then 
      print('newSet result after init', result)
   end
   return result
end

-- return new Set with same elemnts as self
function Set:clone()
   local result = newSet()
   for element in pairs(self._elements) do
      result:add(element)
   end
   return result
end

-- mutate self by subtracting any elements in other set
function Set:difference(otherSet)
   local trace = false
   if trace then
      print('Set:difference self elements before difference', self:elements())
      print('Set:difference other elements', otherSet:elements())
   end
   assert(otherSet)
   for _, element in ipairs(otherSet:elements()) do
      self:remove(element)
      if trace then print('Set:difference removed', element) end
   end
   if trace then
      print('Set:difference elements after difference', self:elements())
   end
end

-- return sequence of elements in the set
-- example: 
-- for _, element in ipairs(Myset:elements()) do ... end
function Set:elements()
   local result = {}
   for element in pairs(self._elements) do
      result[#result + 1] = element
   end
   return result
end

-- return true if two set have exactly same elements
-- otherwise return false
function Set:equals(otherSet)
   local trace = false
   if otherSet == nil then error('otherSet is nil') end
   if not Set.isSet(otherSet) then error('otherSet is not a Set') end

   if self:nElements() ~= otherSet:nElements() then
      if trace then
         print(string.format('Set:equals %d elements in self, %d in otherSet',
                             self:nElements(), otherSet:nElements()))
      end
      return false
   end
   for _, node in ipairs(self:elements()) do
      if not otherSet:hasElement(node) then
         if trace then
            print('Set:equals node in self not in otherSet; node =', node)
         end
         return false
      end
   end
   return true
end

-- return true if element is in the set
-- otherwise return false
function Set:hasElement(element)
   if element == nil then
      error('element is nil')
   end
   local value = self._elements[element]
   if value == true then 
      return true 
   end
   return false
end

-- return true if x is a Set
-- otherwise return false 
function Set.isSet(x)
   local trace = false
   if trace then 
      print('Set.isSet x', x) 
      print('Set.isSet type(x)', type(x))
   end
   assert(x)
   if type(x) == 'table' then
      local tn = torch.typename(x)
      if trace then print('Set.isSet typename', tn) end
      return tn == 'Set'
   else
      return false
   end
end

-- return number of elements in set
function Set:nElements()
   local trace = false
   if trace then
      print('Set:nElements self', self)
      print('Set:nElements self._elements', self._elements)
   end

   local count = 0
   for k, v in pairs(self._elements) do
      if trace then
         print('Set:nElements k,v', k, v)
      end
      count = count + 1
   end
   return count
end

-- print on stdout
function Set:print()
   print('Set(')
   for element in pairs(self._elements) do
      print(' ', element)
   end
   print(')')
end

-- mutate self by removing element, which need not be in set
function Set:remove(element)
   local trace = false
   assert(element)
   if trace then 
      print('Set:remove element', element)
      print('Set:remove type(element)', type(element))
   end
   local value = self._elements[element]
   if value == nil then
   else
      self._elements[element] = nil
   end
end

-- mutate self by removing and returning an arbitrary element
-- error if self is empty
function Set:removeOne()
   for element in pairs(self._elements) do
      self._elements[element] = nil
      return element
   end
   error('attempt to remove element from empty set; Set = ' .. self)
end

-- mutate self by adding elements in other set
function Set:union(otherSet)
   assert(otherSet)
   assert(Set.isSet(otherSet), 'variable otherSet is not a Set')
   for i, element in ipairs(otherSet:elements()) do
      self:add(element)
   end
end
