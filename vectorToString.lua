 -- vectorToString.lua
 
 require 'torch'

 -- convert Torch 1D Tensor (a vector) to a string
 -- ARGS
 -- v : Tensor 1D
 -- RETURNS
 -- s : string
 function vectorToString(v)
    assert(v:nDimension() == 1, 'v is a ' .. type(v) .. ', not a 1D Tensor')
    local s = nil
    for i = 1, v:size(1) do
       local next = string.format('%.6f', v[i])

       require 'torch'

       if i == 1 then
          s = '[' .. next
       else
          s = s .. ', ' .. next
       end
    end
    s = s .. ']'
    return s
 end
