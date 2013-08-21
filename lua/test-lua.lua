-- test-lua.lua
-- test for a bug

cmd = torch.CmdLine()
cmd:text('something')
cmd:option('-algo','', 'algorithm')

params = cmd:parse(arg)

cmd:log('test-lua', params)

print('done')
