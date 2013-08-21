-- NnwEstimator.lua
-- parent class for all NnwEstimator classes

require 'affirm'
require 'makeVerbose'
require 'verify'

-- API overview
if false then
   e = NnwEstimator(xs, ys)

   -- all methods are supplied by a subclass
end -- API overview

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

torch.class('NnwEstimator')

function NnwEstimator:__init(xs, ys)
   local v, isVerbose = makeVerbose(false, 'NnwEstimator:__init')
   verify(v, isVerbose,
          {{xs, 'xs', 'isTensor2D'},
           {ys, 'ys', 'isTensor1D'}})

   assert(xs:size(1) == ys:size(1))

   self._xs = xs
   self._ys = ys
   self._selected = torch.Tensor(xs:size(1)):fill(1)
end -- __init()

--------------------------------------------------------------------------------
-- PUBLIC METHODS: (NONE)
--------------------------------------------------------------------------------
