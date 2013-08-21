-- test-serialization.lua

-- test using ASCII format

function test(format)
   print('testing', format)
   problemValue = 1.184856
   t = torch.Tensor(1):fill(problemValue)
   print(string.format('%s = %f', 't[1]', t[1]))
   
   fileName = 'test-serialization.tmp'
   file = torch.DiskFile(fileName, 'w')
   assert(file)
   if format == 'binary' then
      file:binary()
   end
   
   file:writeObject(t)
   
   file:close()
   
   file = torch.DiskFile(fileName, 'r')
   if format == 'binary' then
      file:binary()
   end
   
   other = file:readObject()
   
   print(string.format('%s = %f', 'other[1]', other[1]))

   assert(other[1] == t[1], 'should be identical but are not')
end -- test

test('binary')
test('ASCII')

