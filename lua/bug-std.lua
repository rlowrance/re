-- bug-std.lua
-- illustrate that torch.std(x, true) fails

tensor = torch.rand(10)
print('std', torch.std(tensor))

-- should print the same thing but fails
print('std version 2', torch.std(tensor, false))