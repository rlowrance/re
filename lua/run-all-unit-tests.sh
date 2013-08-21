# run-all-unit-tests.sh
# run all the tests in the lua directory

torch checkGradient-test.lua
torch Csv-test.lua
torch CsvUtils-test.lua
torch daysPastEpoch-test.lua
torch IncompleteMatrix-test.lua
torch Resampling-test.lua
torch shuffleSequence-test.lua
