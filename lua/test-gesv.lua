-- test-gesv.lua

nDim = 64
A = torch.rand(nDim, nDim)
B = torch.rand(nDim,1)  -- must be 2D
print('A', A)
print('B', B)
print('A:size()', A:size())
print('B:size()', B:size())
X = torch.gesv(B,A)
print('X', X)
print('X:size()', X:size())