# makefile

# directories
INPUTS  = ../../data/v5/inputs
OUTPUTS = ../../data/v5/outputs

# rebuild all the output files
# use a proxy (apns) to stand for a long list of files
.PHONY: allData
allData: \
  $(OUTPUTS)/obs1A-nncache-merged.txt \
  $(INPUTS)/obs1A-all-apns.csv \
  $(OUTPUTS)/obs1A-test-apns.csv \
  $(OUTPUTS)/hp-search-knn-1A.txt

# generateV5Inputs.lua creates all the files in v5/inputs/
.PHONY: inputs
inputs: $(INPUTS)/obs1A-all-apns.csv

$(INPUTS)/obs1A-all-apns.csv: generateV5Inputs.lua
	torch generateV5Inputs.lua -test 0

# split-all.lua creates the train and test outputs
# use output file obsOBS-TT-apns.csv as proxy for the 4 created output files
# also drops duplicate features rows
# TT \in {train, test}
.PHONY: split-all
split-all: split-1A split-2R

.PHONY: split-1A
split-1A: $(OUTPUTS)/obs1A-test-apns.csv

$(OUTPUTS)/obs1A-test-apns.csv: split-all.lua
	torch split-all.lua -obs 1A -test 0

.PHONY: split-2R
split-2R: $(OUTPUTS)/obs2R-test-apns.csv

$(OUTPUTS)/obs2R-test-apns.csv: split-all.lua
	torch split-all.lua -obs 2R -test 0



# generate nearest neighbors indices cache
.PHONY: cache-obs1A
cache-obs1A: $(OUTPUTS)/obs1A-nn-cache-merged.txt

$(OUTPUTS)/obs1A-nn-cache-merged.txt: create-nn-cache.lua \
 $(OUTPUTS)/obs1A-nn-cache-shard-1.txt \
 $(OUTPUTS)/obs1A-nn-cache-shard-2.txt \
 $(OUTPUTS)/obs1A-nn-cache-shard-3.txt
	torch create-nn-cache.lua -obs 1A -test 0 -shards 3 -merge 1

.PHONY: cache-obs1A-shard-1
cache-obs1A-shard-1: $(OUTPUTS)/obs1A-nn-cache-shard-1.txt

$(OUTPUTS)/obs1A-nn-cache-shard-1.txt: create-nn-cache.lua
	torch create-nn-cache.lua -obs 1A -test 0 -shards 3 -shard 1

$(OUTPUTS)/obs1A-nn-cache-shard-2.txt: create-nn-cache.lua
	torch create-nn-cache.lua -obs 1A -test 0 -shards 3 -shard 2

$(OUTPUTS)/obs1A-nn-cache-shard-3.txt: create-nn-cache.lua
	torch create-nn-cache.lua -obs 1A -test 0 -shards 3 -shard 3


$(OUTPUTS)/obs1A-test-apns.csv: $(INPUTS)/obs1A-all-apns.csv split.lua
	torch split.lua -test 0

# find best hp for KNN model
.PHONY: hp-search-knn
hp-search-knn: $(OUTPUTS)/hp-search-knn-1A.txt

$(OUTPUTS)/hp-search-knn-1A.txt: \
  $(OUTPUTS)/obs1A-train-apns.csv hp-search-knn.lua HpSearch.lua
	torch hp-search-knn.lua -obs 1A -test 0


.PHONY: check-kernel-smoothers
check-kernel-smoothers:
	torch NnwEstimator-test.lua
	torch NnwEstimatorAvg-test.lua
	torch NnwEstimatorKwavg-test.lua
	torch NnwEstimatorLlr-test.lua
	torch Nnw-test.lua
	torch NnwSmoother-test.lua
	torch NnwSmootherAvg-test.lua
	torch NnwSmootherKwavg-test.lua
	torch NnwSmootherLlr-test.lua
