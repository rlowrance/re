-- test-creation.lua
-- determine how to create a class instance within a class method

do
   local Foo = torch.class('Foo')

   function Foo:__init()
      self.contents = 'stuff'
   end

   -- class method that returns a Foo
   function Foo.cm()
      print('in Foo.cm')
      -- below does not work
      -- local x = Foo()

      -- below does not work
      -- local x = torch.Foo()

      local x = torch.factory("Foo")()
      print('x from factory', x)
      x:__init()
      print('x after __init', x)
      return x
   end
end

y = Foo()
x = Foo.cm()
