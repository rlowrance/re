-- merge-pieces.lua
-- merge pieces (shards) of an analysis into one big file

-- test each record for integrity, defined as
-- + contains 4 fields

cmd = torch.CmdLine()
cmd:text('Merge pieces of an analysis into one big csv file')
cmd:text()
cmd:text('example')
cmd:text('  cd src.git/lua')
cmd:text(   '  torch merge-pieces.lua -algo=knn -obs=1A -k=24 -pieces=100 -base=estimates')
cmd:text('    will merge all files estimates-knn-1A-*.txt into')
cmd:text('    estimates-knn-1A-merged.txt in the analysis directory')
cmd:text('    for obs 1A')
cmd:text()
cmd:text('Options')
cmd:option('-algo','knn','Algorithm in {knn}')
cmd:option('-base','estimates','Base portion of file name')
cmd:option('-datadir','../../data/','Path to data directory')
cmd:option('-k',24,'Parameter when algo was run')
cmd:option('-obs','1A','Observation set in {1A}')
cmd:option('-pieces',100,'Number of pieces (shards) to expect')
cmd:text()

-- parse command line
params = cmd:parse(arg)

-- where data are
params.rundir = 
   params.datadir .. 
   'generated-v4/obs' .. params.obs ..
   '/analysis/algo=' .. params.algo .. 
   ',k=' .. params.k ..
   ',pieces=' .. params.pieces ..
   '/'

function printParams()
   print()
   print('Command line parameters')
   for k,v in pairs(params) do
      print(string.format('%10s %q', k, v))
   end
end

printParams()

-- set logfilename (actuall the path)
cmd:log(params.rundir .. 'merge-pieces.lua-log.txt', params)

print('params.rundir', params.rundir)

infilebase = 
   params.base .. 
   '-' .. params.algo .. 
   '-' .. params.obs .. 
   '-' 

-- return number of commas in a string
function numberOfCommas(s)
   local count = 0
   -- iterate over each character
   for c in string.gmatch(s, ',') do
      count = count + 1
   end
   return count
end

outfilename = infilebase .. 'merged.csv'
outfile = io.open(params.rundir .. outfilename, 'w')
outfile:write('apn,date,k,estimate')  -- vary if not algo=knn
outfile:write('\n')
countOut = 0

for piece=0,params.pieces-1 do
   local infilename = infilebase .. string.format('%d', piece) .. '.txt'
   local infilepath = params.rundir .. infilename
   local infile = io.open(infilepath, 'r')
   assert(infile,'Did not open: ' .. infilepath)
   local countIn = 0
   for line in infile:lines('*l') do
      countIn = countIn + 1
      -- check that each line contains 3 commas (hence 4 fields)
      if numberOfCommas(line) ~= 3 then
	 print(string.format(
		  'Error in file %s: not 3 commas in line # %d = \n%s',
		  infilename, countIn, line))
      end
      outfile:write(line)
      outfile:write('\n')
      countOut = countOut + 1
   end
   infile:close()
   print(string.format('Read %7d records from file %s',
		       countIn, infilename))
end

outfile:close()
print(string.format('Wrote %d data records to file %s',
		    countOut, outfilename))
printParams()
print()
print('Finished')