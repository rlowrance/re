-- extractTensor.lua

-- extract 2D Tensor for a data frame
-- ARGS
-- df : Dataframe
-- columnNames : seq of names of column
--               each column should be numeric
--               factor columns lead to weird results
-- RETURNS
---tensor : a 2D Tensor
function extractTensor(df, columnNames)
   local n = df:nRows()
   local result = torch.Tensor(n, #columnNames)
   
   for c, columnName in ipairs(columnNames) do
      local values = df:column(columnName)
      for i = 1, n do
         result[i][c] = values[i]
      end
   end

   return result
end
