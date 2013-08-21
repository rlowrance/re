-- endMain.lua
-- shut down main program

function mainEnd(options)
   local v, isVerbose = makeVerbose(false, 'endMain')
   verify(v, isVerbose,
          {{options, 'options', 'isTable'}})


   printOptions(options, options.log)
   
   if options.debug and options.debug ~= 0 then
      options.log:log('DEBUGGING: toss results')
   end

   if options.test and options.test ~= 0 then
      options.log:log('TESTING: toss results')
   end

   options.log:log('consider commiting the code')

   options.log:close()
end