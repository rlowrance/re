-- NamedMatrix_test.lua
-- unit test

require 'assertEq'
require 'makeVp'
require 'NamedMatrix'

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- bug #1: test case to repliace
local nm = NamedMatrix.readCsv{
   file='NamedMatrix_test_data.csv',
   sep=',',
   nanString='',
   nRows=-1,
   numberColumns={'number1', 'number2'},
   factorColumns={'factor1', 'factor2'},
   skip=0}

error('expected to fail')
stop()

-- construction: sequence
local seq = {1, 2, 3}
local names = {'a', 'b', 'c'}
local levels = {}
levels.a = {'first', 'second'}

-- construction by hand
local nm = NamedMatrix{tensor=seq, names=names, levels=levels}
assertEq(nm.t, torch.Tensor{{1, 2, 3}}, 0)
assert(#nm.names == 3)
assert(nm.names[2] == 'b')
vp(2, 'nm', nm)
vp(2, 'nm.levels', nm.levels)
assert(type(nm.levels) == 'table')
for k, v in pairs(nm.levels) do
   assert(k == 'a')
   assert(type(v) == 'table')
end

-- construction: 1D Tensor
local nm = NamedMatrix{tensor=torch.Tensor{1,2,3}, names=names, levels=levels}
vp(2, 'nm', nm)
assert(nm.t:dim() == 2)
assert(nm.t:size(1) == 1)
assert(nm.t:size(2) == 3)

-- construction: 2D Tensor
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
vp(2, 'nm', nm)
tensor = nil
assert(nm.t:dim() == 2)
assert(nm.t[1][1] == 1)
assert(nm.t[2][3] == 4)

-- dropColumn
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
local nm2 = nm:dropColumn('b')
vp(2, 'nm2', nm2)
assert(nm2.t:dim() == 2)
assert(nm2.t:size(2) == 2)
assert(nm2.t[1][1] == 1)
assert(nm2.t[2][2] == 4)
assert(nm2.names[1] == 'a')
assert(nm2.names[2] == 'c')

-- head
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
local nm2 = nm:head(1)
assert(nm2.t:size(1) == 1)

-- split rows according to indicator
local tensor = torch.rand(100, 5)
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
local to1 = {}
for i = 1, nm.t:size(1) do
   table.insert(to1, i % 2 == 0)
end
local function evenTo1(rowIndex)
   return rowIndex % 2 == 0
end
local nm1, nm2 = nm:splitRows(evenTo1)
vp(2, 'nm1.t:size', nm1.t:size())
vp(2, 'nm2.t:size', nm2.t:size())
assert(nm1.t:size(1) == 50)
assert(nm2.t:size(1) == 50)

-- split rows randomly
local tensor = torch.rand(100, 5)
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
local function random(rowIndex)
   local fractionToNm1 = .70
   return torch.uniform(0,1) < fractionToNm1
end
local nm1, nm2 = nm:splitRows(random)
--local nm1, nm2 = nm:splitRowsRandomly(.70)
vp(2, 'nm1:size', nm1.t:size())
vp(2, 'nm2:size', nm2.t:size())
assert(nm1.t:size(1) > nm2.t:size(1))

-- get(i, 'a')
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
vp(2, 'nm', nm)
assert(nm:get(2, 'a') == 2)
assert(nm:get(2, 'a') == nm.t[2][1])

-- getLevel(i, 'a')
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
vp(2, 'nm', nm)
vp(2, 'nm.t', nm.t)
assert(nm:getLevel(1, 'a') == 'first')
assert(nm:getLevel(2, 'a') == 'second')

-- getLevel(i, j)
assert(nm:getLevel(1, 1) == 'first')
assert(nm:getLevel(2, 1) == 'second')

-- columnKind
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
vp(2, 'nm', nm)
assert(nm:columnKind('a') == 'factor')
assert(nm:columnKind('b') == 'number')
assert(nm:columnKind('c') == 'number')

-- columnIndex
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
vp(2, 'nm', nm)
assert(nm:columnIndex('a') == 1)
assert(nm:columnIndex('b') == 2)
assert(nm:columnIndex('c') == 3)

-- print
if verbose > 0 and false then
   local tensor = torch.Tensor{{1,2,3},{2,3,4}}
   local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
   vp(2, 'nm', nm)
   nm:print{n=1, maxLevels = 3, name='nm'}
   print('examine output')
end

-- write CSV
local tensor = torch.Tensor{{1,2,3},{2,3,4}}
local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}
nm.t[1][1] = 0 / 0  -- set to NaN
if verbose > 0 then nm:print() end
nm:writeCsv{file='/tmp/NamedMatrix_test.lua'}

-- readCsv  (no transformation)
local t = {file='/tmp/NamedMatrix_test.lua',
           numberColumns={'b', 'c'},
           factorColumns={'a'}}
local nm = NamedMatrix.readCsv(t)
if verbose > 0 then nm:print() end
if verbose > 0 then vp(2, 'nm.t', nm.t) end
assert(nm.t:size(1) == 2)
assert(nm.t:size(2) == 3)
assert(isnan(nm:get(1,'a')))
assert(nm:get(1,'b') == 2)
assert(nm:get(1,'c') == 3)
assert(nm:get(2,'a') == 1)
assert(nm:get(2,'b') == 3)
assert(nm:get(2,'c') == 4)


-- readCsv  (with transformation of input records)
local function transformF(inputSeq, isHeader)
   -- add column d = b * c
   local vp = makeVp(0, 'transformF')
   vp(2, 'inputSeq', inputSeq, 'isHeader', isHeader)
   local transformed
   if isHeader then
      transformed = {'b', 'c', 'd'}
   else
      local b = tonumber(inputSeq[2])
      local c = tonumber(inputSeq[3])
      local d = b * c
      transformed = {inputSeq[2], inputSeq[3], tostring(d)}
   end
   vp(2, 'transformed', transformed)
   return transformed
end

-- input file fields 
-- record 1: a     , b, c
-- record 2:       , 2, 3
-- record 3: second, 3, 4
local t = {file='/tmp/NamedMatrix_test.lua',
           numberColumns={'b', 'c', 'd'},
           transformF=transformF}
local nm = NamedMatrix.readCsv(t)
if verbose > 0 then nm:print() end
if verbose > 0 then vp(2, 'nm.t', nm.t) end
assert(nm.t:size(1) == 2)
assert(nm.t:size(2) == 3)
assertEq(nm.t[1], torch.Tensor{2,3,6}, 0)
assertEq(nm.t[2], torch.Tensor{3,4,12}, 0)

-- merge
local tensor1 = torch.Tensor{{1,112,113,100},
                             {2,122,123,200},
                             {1,132,133,300}}
local levels1 = {}
levels1['1a'] = {'one', 'two'}
local nm1 = NamedMatrix{tensor=tensor1, 
                        names={'1a','1b','1c','id1'}, 
                        levels=levels1}

local tensor2 = torch.Tensor{{211,212,3,100},
                             {221,222,2,101},
                             {231,232,1,300}}
local levels2 = {}
levels2['2c'] = {'three', 'two', 'one'}
local nm2 = NamedMatrix{tensor=tensor2, 
                        names={'2a', '2b', '2c', 'id2'}, 
                        levels=levels2}

local nm = NamedMatrix.merge{nmX=nm1, nmY=nm2, byX='id1', byY='id2', newBy='id'}
if verbose > 0 then nm:print() end
if verbose > 0 then vp(2,'nm.t',nm.t) end
assert(nm.t:size(1) == 2)
assert(nm.t:size(2) == 7)

assertEq(nm.t[1], torch.Tensor{1,112,113,211,212,3,100}, 0)
assertEq(nm.t[2], torch.Tensor{1,132,133,231,232,1,300}, 0)

vp(2, 'nm.names', nm.names) 

assert(nm.names[1] == '1a')
assert(nm.names[4] == '2a')
assert(nm.names[7] == 'id')

vp(2, 'nm.levels', nm.levels)
assert(nm.levels['1a'])
assert(nm.levels['2c'])

-- onlyColumns
-- readCsv  (no transformation)
local t = {file='/tmp/NamedMatrix_test.lua',
           numberColumns={'b', 'c'},
           factorColumns={'a'}}
local nm = NamedMatrix.readCsv(t)
if verbose > 0 then nm:print() end
if verbose > 0 then vp(2, 'nm.t', nm.t) end

local justA = nm:onlyColumns({'a'})
if verbose > 0 then vp(0, 'justA', justA) end
assert(justA.t:dim() == 2)
assert(justA.t:size(1) == 2)
assert(justA.t:size(2) == 1)
assert(isnan(justA.t[1][1]))
assert(justA.t[2][1] == 1)
    
local justBC = nm:onlyColumns({'b', 'c'})
vp(2, 'justBC', justBC)
assert(justBC.t:dim() == 2)
assert(justBC.t:size(1) == 2)
assert(justBC.t:size(2) == 2)
assert(justBC:get(1, 'b') == 2)
assert(justBC:get(1, 'c') == 3)
assert(justBC:get(2, 'b') == 3)
assert(justBC:get(2, 'c') == 4)

-- constructor NamedMatrix.concatenateHorizontally
local a = NamedMatrix{tensor=torch.Tensor{{1,2,1},{11,12,13}}:t(),
                      names={'a1', 'a2'},
                      levels={a1={'one', 'two'}}}
local b = NamedMatrix{tensor=torch.Tensor{{101,102,103}}:t(),
                      names={'b1'},
                      levels={}}
if verbose > 0 then a:print() end
local m = NamedMatrix.concatenateHorizontally(a, b)
if verbose > 0 then m:print() print(m.t) end
assertEq(m.t, torch.Tensor{{1,11,101},{2,12,102},{1,13,103}}, 0)

-- equalValue
assert(a:equalValue(a))
assert(not a:equalValue(b))

print('ok NamedMatrix')

         
