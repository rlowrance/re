# compare-models.makefile
# USAGE
# make -file compare-models.makefile depend
# make -file compare-models.makefile all
#

OUTPUT=../data/v6/output
TRANSACTIONS_SUBSET1=$(OUTPUT)/transactions-subset1.csv.gz
SUBSET1=$(OUTPUT)/transactions-subset1

# splits of subset1; use -anp as a proxy for all of them
SPLIT_APN=$(SUBSET1)-apn.rsave

# also produces ...compare-models-an-01.pdf
AN01=$(OUTPUT)/an-01.rsave

BMTPASSESSOR=$(OUTPUT)/compare-models-bmtp-assessor.rsave
BMTPASSESSORCHART1=$(OUTPUT)/compare-models-chart-bmtp-assessor-chart-1.rsave

CV01=$(OUTPUT)/compare-models-cv-01.rsave
CV01CHART1=$(OUTPUT)/compare-models-chart-cv-01-chart-1.pdf

CV02=$(OUTPUT)/compare-models-cv-02.rsave
CV02CHART1=$(OUTPUT)/compare-models-chart-cv-02-chart-1.pdf

CV03=$(OUTPUT)/compare-models-cv-03.rsave
CV03CHART1=$(OUTPUT)/compare-models-chart-cv-03-chart-1.pdf

CV04=$(OUTPUT)/compare-models-cv-04.rsave
CV04CHART1=$(OUTPUT)/compare-models-chart-cv-04-chart-1.pdf

CV05=$(OUTPUT)/compare-models-cv-05.rsave
CV05CHART1=$(OUTPUT)/compare-models-chart-cv-05-chart-1.pdf

TARGETS=$(AN01) $(SPLIT_APN)
#		$(BMTPASSESSOR) $(BMTPASSESSORCHART1) 
#		$(CV01) $(CV01CHART1) \
#		$(CV02) $(CV02CHART1) \
#		$(CV03) $(CV03CHART1) \
#		$(CV04) $(CV04CHART1) \
#		$(CV05) $(CV05CHART1)

#SOURCES=$(wildcard *.R)

$(warning TARGETS is $(TARGETS))
$(warning SOURCES is $(SOURCES))

#include dependencies-in-R-sources.generated

.PHONY: all
all: $(TARGETS) #dependencies-in-R-sources.makefile

# subset1 splits
$(SPLIT_APN): transactions-subset1-SPLIT.R $(TRANSACTIONS_SUBSET1)
	Rscript transactions-subset1-SPLIT.R

# experiment: analyses
$(AN01): an-01.R FileInput.R FileOutput.R InitializeR.R LoadColumns.R \
	$(TRANSACTIONS_PRICE) $(TRANSACTIONS_SALE_YEAR) $(TRANSACTIONS_SALE_MONTH)
	Rscript an-01.R
	Rscript an-01-chart.R

#$(AN01): compare-models.R CompareModelsAn01.R $(TRANSACTIONS)
#	Rscript compare-models.R --what an --choice 01

# experiment: bmtp (best model for test period)
$(warning BMTPASSESSOR is $(BMTPASSESSOR))
$(warning TRANSACTIONS is $(TRANSACTIONS))
$(warning AN01 is $(AN01))
$(warning BMTPASSESSORCHART1 is $(BMTPASSESSORCHART1))

$(BMTPASSESSOR): compare-models.R CompareModelsCv01.R $(TRANSACTIONS)
	Rscript compare-models.R --what bmtp --choice assessor

$(BMTPASSESSORCHART1): compare-models-chart.R $(AN01) $(BMTPASSESSOR)
	Rscript compare-models-chart.R --what bmtp --choice assessor

# cros-validation driven experiments
$(CV01): compare-models.R CompareModelsCv01.R $(TRANSACTIONS) 
	Rscript compare-models.R --what cv --choice 01

$(CV02): compare-models.R CompareModelsCv02.R $(TRANSACTIONS) 
	Rscript compare-models.R --what cv --choice 02

$(CV03): compare-models.R CompareModelsCv03.R $(TRANSACTIONS) 
	Rscript compare-models.R --what cv --choice 03

$(CV04): compare-models.R CompareModelsCv04.R $(TRANSACTIONS) 
	Rscript compare-models.R --what cv --choice 04

# dependencies
.PHONY: depend
depend: 
	echo REMAKING dependencies
	Rscript make-dependencies.R --filename dependencies-in-R-sources.generated


#
# Output info about each rule and why it was executed
# ref: drdobbs.com/toools/debugging-makefiles/199703338?pgno=3
#OLD_SHELL := $(SHELL)
#SHELL := ($warning [$@ ($^) ($?)] $(OLD_SHELL)
