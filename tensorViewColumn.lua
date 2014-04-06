-- tensorViewColumn.lua
-- DEPRECATED: use tensor.viewColumn instead
-- view the underlying storage of a column in a 2D Tensor
-- ARGS
-- tensor : 2D Tensor
-- columnIndex : number > 0, column to view
-- RETURNS
-- view        : tensor viewing the appropriate column
--               CHANGING THE VIEW ALSO CHANGES tensor
function tensorViewColumn(tensor, columnIndex)
   assert(columnIndex > 0)
   assert(columnIndex <= tensor:size(2))
   return tensor:select(2, columnIndex)
end
