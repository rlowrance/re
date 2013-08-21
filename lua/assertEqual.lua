-- assertEqual.lua: halt if arguments are not equal

function assertEqual(expected, actual)
   if expected == actual then return end
   print('assertEqual failed')
   print('expected', expected)
   print('actual', actual)
   error('assertEqual failed')
end
