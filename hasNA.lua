-- hasNA.lua

require 'Dataframe'
require 'ifelse' 
require 'makeVp'

local function hasNA_Dataframe(df, verbose)
   local vp = makeVp(verbose, 'hasNA_Dataframe')
   local NA = Dataframe.NA
   for _, colName in ipairs(df:columnNames()) do
      local seq = df:column(colName)
      for rowIndex, element in ipairs(seq) do
         if element == NA then
            vp(1, 'element that is NA', element)
            vp(1, 'colName', colName)
            vp(1, 'rowIndex', rowIndex)
            vp(1, string.format('found NA in column %s row %d',
                                colName, rowIndex))
            return true
         end
      end
   end
   return false
end

local function hasNA_table(tab, verbose)
   local vp = makeVp(verbose, 'hasNA_table')
   vp(1, 'tab', tab)
   if verbose == 1 then stop() end
   local NA = Dataframe.NA    -- this value is a special table

   local function isNA(element, where)
      if element == NA then
         vp(1, string.format('found NA as a %s of table', where))
         return true
      else
         return false
      end
   end

   local function containsNA(element)
      if type(element) == 'table' or torch.typename(element) == 'Dataframe' then
         return hasNA(element, verbose)
      else
         return false
      end
   end

   for k, v in pairs(tab) do  -- examine the keys and values
      if isNA(k, 'key') or isNA(v, 'value') then
         return true
      end
      if containsNA(k) or containsNA(v) then
         return true
      end
   end
   return false
end
      
-- return true iff there is at least one NA in a Dataframe or table
-- ARGS
-- obj     : any object, including Dataframe and table
-- verbose : optional integer >= 0 or boolean, default 0
-- RETURNS true iff there is at least one NA somewhere in the df
function hasNA(obj, verbose)
   -- map boolean values of verbose to equivalent integer values
   -- supply default values
   -- NOTE: verboseValue is used in sub-functions, not in this function
   local verboseValue = ifelse(verbose == true, 
                               1, 
                               ifelse(type(verbose) == 'number',
                                      verbose,
                                      0))
   local vp = makeVp(verboseValue, 'hasNA')
   if torch.typename(obj) == 'Dataframe' then
      return hasNA_Dataframe(obj, verboseValue)
   elseif type(obj) == 'table' then
      return hasNA_table(obj, verboseValue)
   else
      vp(1, 'obj', obj)
      error('obj is not a Dataframe or table')
   end

end