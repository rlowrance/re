# run_tests.R
# use RUnit to run all the tests
library('RUnit')

source('Center.R')
source('SplitDate.R')

test.suite <- defineTestSuite('all',
                              dirs = file.path('tests'),
                              testFileRegexp = '*.R')

test.result <- runTestSuite(test.suite)

printTextProtocol(test.result)
