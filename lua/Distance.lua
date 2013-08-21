-- Distance.lua
-- define various distance functions

require 'Validations'

local Distance = torch.class('Distance')

function Distance:__init()
end

-- return Euclidean distance between two compatible Tensors
-- static method
function Distance.euclidean(t1, t2)
   Validations.isTensor(t1, 't1')
   Validations.isTensor(t2, 't2')
   return torch.dist(t1, t2) -- 2-norm of (t1-t2)
end
