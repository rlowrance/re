-- test-tensor-select.lua

x = torch.randn(5, 3)
y = x[1]
y[1] = 27

print('x', x)
print('y', y)

assert(y[1] == x[1][1]) -- surprise!

