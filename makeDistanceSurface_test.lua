-- makeDistanceSurface_test.lua
-- unit test

require 'makeDistanceSurface'

require 'makeVp'

local verboseLevel = 0
local vp = makeVp(0)

local latitudes = torch.Tensor({30, 31})
local longitudes = torch.Tensor({-110, -111})
local years = torch.Tensor({1980, 1979})

local queryLatitude = 29
local queryLongitude = -112
local queryYear = 1981

local filename = 'makeDistanceSurface-test-testfile.txt'
local mPerYear = 100000

local distances, writeCache = 
   makeDistanceSurface{mPerYear=mPerYear,
                       latitudes=latitudes,
                       longitudes=longitudes,
                       years=years,
                       filename=filename}
assert(type(distances) == 'function')
assert(type(writeCache) == 'function')

-- first time without cache
local d, usedCache = distances{latitude=queryLatitude,
                               longitude=queryLongitude,
                               year=queryYear}
vp(1, 'd', d)
local tol = 1
assert(math.abs(d[1] - 244737) < tol)
assert(math.abs(d[2] - 313787) < tol)
-- may or may not have used cache, depending on whether cache file exists

-- second time with cache
local d, usedCache = distances{latitude=queryLatitude,
                               longitude=queryLongitude,
                               year=queryYear}
vp(1, 'd', d)
local tol = 1
assert(math.abs(d[1] - 244737) < tol)
assert(math.abs(d[2] - 313787) < tol)
assert(usedCache)

-- write cache
writeCache()

-- read cache
local distances2, writeCache2 = 
   makeDistanceSurface{mPerYear=mPerYear,
                       latitudes=latitudes,
                       longitudes=longitudes,
                       years=years,
                       filename=filename}

-- third time with cache
local d, usedCache = distances2{latitude=queryLatitude,
                                longitude=queryLongitude,
                                year=queryYear}
vp(1, 'd', d)
local tol = 1
assert(math.abs(d[1] - 244737) < tol)
assert(math.abs(d[2] - 313787) < tol)
assert(usedCache)


-- remove the temporary file
local command = 'rm ' .. filename
os.execute(command)

print('ok makeDistanceSurface')
