-- all.lua
-- require all Roy's modules

require 'affirm'
require 'allZeroes'
require 'crossValidation'
require 'CsvUtils'
require 'CvLoss'
require 'DiagonalMatrix'
require 'HpSearch'
require 'Log'
require 'makeFittedDataSelector'
require 'mainEnd'
require 'mainStart'
require 'makeVerbose'
require 'modelUseKernelSmoother'
require 'ModelIndex'

require 'Nncache'
require 'Nncachebuilder'

-- nearest neighbor kernel smoothers
require 'Nnw'
require 'NnwEstimator'
require 'NnwEstimatorAvg'
require 'NnwEstimatorKwavg'
require 'NnwEstimatorLlr'
require 'NnwSmoother'
require 'NnwSmootherAvg'
require 'NnwSmootherKwavg'
require 'NnwSmootherLlr'

-- require 'parseOptions'   use mainStart instead
require 'permuteTensor'
require 'printOptions'
require 'readTrainingData'
require 'setRandomSeeds'
require 'Set'
require 'shuffleSequence'
require 'StandardizeDate'
require 'standardizedDayColumn'
require 'sortedKeys'
require 'Tester'
require 'TimerCpu'
require 'verify'

-- metric window kernel smoothers
--require 'MwKwavg'
--require 'MwLlr'