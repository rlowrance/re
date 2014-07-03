# compare-models.makefile
#

OUTPUT=../data/v6/output
TRANSACTIONS=$(OUTPUT)/transactions-subset1.csv.gz
AN01=$(OUTPUT)/compare-models-an-01.pdf
#CV01=$(OUTPUT)/compare-models-cv-01.rsave
TARGETS=$(AN01) $(CV01)

SOURCES=$(wildcard *.R)

$(warning TARGETS is $(TARGETS))
$(warning SOURCES is $(SOURCES))

.PHONY: all
all: $(AN01) $(CV01) dependencies-in-R-sources.makefile

# rebuild dependencies if any source file has changed
dependencies-in-R-sources.generated: $(SOURCES)
	Rscript make-dependencies.R --filename dependencies-in-R-sources.generated

# analyses
$(AN01): compare-models.R CompareModelsAn01.R $(TRANSACTIONS)
	Rscript compare-models.R --what an --choice 01


# experiments
$(CV01): compare-models.R CompareModelsCv01.R $(TRANSACTIONS) 
	Rscript compare-models.R --what cv --choice 01

include dependencies-in-R-sources.generated
#
# Output info about each rule and why it was executed
# ref: drdobbs.com/toools/debugging-makefiles/199703338?pgno=3
#OLD_SHELL := $(SHELL)
#SHELL := ($warning [$@ ($^) ($?)] $(OLD_SHELL)
