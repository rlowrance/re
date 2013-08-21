-- mOp.lua
-- matrix operations (a matrix is a 2D Tensor or NamedTensor)
-- attempt to shorten amount of code at expense of extra function call

-- Principles:
-- 1. Promote scalars to appropriately-sized matrices
-- 2. Mimic Matlab for function names

mOp = {}

-- convert to matrix of size m x n
function mOp.asMatrix(scalar, m, n) end

-- matrix of zeros
function mOp.zeros(m, n) end

-- matrix of ones
function mOp.ones(m, n) end

-- matrix of uniform random values in [0, 1]
function mOp.rand(m, n) end

-- add corresponding elements of 2 or more matrices
function mOp.add(...) end

-- divide corresponding elements of 2 or more matrices
function mOp.div(x, y) end

-- subtract corresponding elements of 2 matrices
function mOp.sub(x, y) end

-- multiply 2 or more matrices in optimal order
function mOp.mult(...) end

