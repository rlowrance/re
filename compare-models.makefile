# compare-models.makefile
# USAGE
#

OUTPUT=../data/v6/output
TRANSACTIONS_SUBSET1=$(OUTPUT)/transactions-subset1.csv.gz
SUBSET1=$(OUTPUT)/transactions-subset1

# splits of subset1; use -anp as a proxy for all of them
SPLIT_APN=$(SUBSET1)-apn.rsave

# also produces ...compare-models-an-01.pdf
AN01=$(OUTPUT)/an-01.rsave

AVMVARIANTS=$(OUTPUT)/compare-models-avmvariants-loglevel10.rsave

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

SFPLINEAR_SHARD_01=$(OUTPUT)/compare-models-sfplinear-shard-01.rsave
SFPLINEAR_SHARD_02=$(OUTPUT)/compare-models-sfplinear-shard-02.rsave
SFPLINEAR_SHARD_03=$(OUTPUT)/compare-models-sfplinear-shard-03.rsave
SFPLINEAR_SHARD_04=$(OUTPUT)/compare-models-sfplinear-shard-04.rsave
SFPLINEAR_SHARD_05=$(OUTPUT)/compare-models-sfplinear-shard-05.rsave
SFPLINEAR_SHARD_06=$(OUTPUT)/compare-models-sfplinear-shard-06.rsave
SFPLINEAR_SHARD_07=$(OUTPUT)/compare-models-sfplinear-shard-07.rsave
SFPLINEAR_SHARD_08=$(OUTPUT)/compare-models-sfplinear-shard-08.rsave
SFPLINEAR_SHARD_09=$(OUTPUT)/compare-models-sfplinear-shard-09.rsave
SFPLINEAR_SHARD_10=$(OUTPUT)/compare-models-sfplinear-shard-10.rsave
SFPLINEAR_SHARD_11=$(OUTPUT)/compare-models-sfplinear-shard-11.rsave
SFPLINEAR_SHARD_12=$(OUTPUT)/compare-models-sfplinear-shard-12.rsave
SFPLINEAR_SHARD_13=$(OUTPUT)/compare-models-sfplinear-shard-13.rsave
SFPLINEAR_SHARD_14=$(OUTPUT)/compare-models-sfplinear-shard-14.rsave
SFPLINEAR_SHARD_15=$(OUTPUT)/compare-models-sfplinear-shard-15.rsave
SFPLINEAR_SHARD_16=$(OUTPUT)/compare-models-sfplinear-shard-16.rsave
SFPLINEAR_SHARD_17=$(OUTPUT)/compare-models-sfplinear-shard-17.rsave
SFPLINEAR_SHARD_18=$(OUTPUT)/compare-models-sfplinear-shard-18.rsave
SFPLINEAR_SHARD_19=$(OUTPUT)/compare-models-sfplinear-shard-19.rsave
SFPLINEAR_SHARD_20=$(OUTPUT)/compare-models-sfplinear-shard-20.rsave
SFPLINEAR_SHARD_21=$(OUTPUT)/compare-models-sfplinear-shard-21.rsave
SFPLINEAR_SHARD_22=$(OUTPUT)/compare-models-sfplinear-shard-22.rsave
SFPLINEAR_SHARD_23=$(OUTPUT)/compare-models-sfplinear-shard-23.rsave

SFPLINEAR_COMBINE=$(OUTPUT)/compare-models-sfplinear-combine.rsave

SFPLINEAR_SHARDS = \
  $(SFPLINEAR_SHARD_01) \
  $(SFPLINEAR_SHARD_02) \
  $(SFPLINEAR_SHARD_03) \
  $(SFPLINEAR_SHARD_04) \
  $(SFPLINEAR_SHARD_05) \
  $(SFPLINEAR_SHARD_06) \
  $(SFPLINEAR_SHARD_07) \
  $(SFPLINEAR_SHARD_08) \
  $(SFPLINEAR_SHARD_09) \
  $(SFPLINEAR_SHARD_10) \
  $(SFPLINEAR_SHARD_11) \
  $(SFPLINEAR_SHARD_12) \
  $(SFPLINEAR_SHARD_13) \
  $(SFPLINEAR_SHARD_14) \
  $(SFPLINEAR_SHARD_15) \
  $(SFPLINEAR_SHARD_16) \
  $(SFPLINEAR_SHARD_17) \
  $(SFPLINEAR_SHARD_18) \
  $(SFPLINEAR_SHARD_19) \
  $(SFPLINEAR_SHARD_20) \
  $(SFPLINEAR_SHARD_21) \
  $(SFPLINEAR_SHARD_22) \
  $(SFPLINEAR_SHARD_23) 

SFPLINEAR = $(SFPLINEAR_SHARDS) $(SFPLINEAR_COMBINE)

TARGETS=$(AN01) $(AVMVARIANTS) $(SPLIT_APN) $(SFPLINEAR)
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

$(AVMVARIANTS): CompareModelsAvmVariants.R $(SPLIT_APN)
	Rscript compare-models.R --what avmVariants --choice loglevel10

# sfplinear
$(SFPLINEAR_COMBINE): CompareModelsSfpLinearCombine.R $(SFPLINEAR_SHARDS)
	Rscript compare-models.R --what sfpLinear --choice combine 

$(SFPLINEAR_SHARD_01): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 01

$(SFPLINEAR_SHARD_02): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 02

$(SFPLINEAR_SHARD_03): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 03

$(SFPLINEAR_SHARD_04): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 04

$(SFPLINEAR_SHARD_05): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 05

$(SFPLINEAR_SHARD_06): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 06

$(SFPLINEAR_SHARD_07): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 07

$(SFPLINEAR_SHARD_08): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 08

$(SFPLINEAR_SHARD_09): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 09

$(SFPLINEAR_SHARD_10): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 10

$(SFPLINEAR_SHARD_11): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 11

$(SFPLINEAR_SHARD_12): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 12

$(SFPLINEAR_SHARD_13): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 13

$(SFPLINEAR_SHARD_14): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 14

$(SFPLINEAR_SHARD_15): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 15

$(SFPLINEAR_SHARD_16): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 16

$(SFPLINEAR_SHARD_17): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 17

$(SFPLINEAR_SHARD_18): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 18

$(SFPLINEAR_SHARD_19): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 19

$(SFPLINEAR_SHARD_20): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 20

$(SFPLINEAR_SHARD_21): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 21

$(SFPLINEAR_SHARD_22): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 22

$(SFPLINEAR_SHARD_23): CompareModelsSfpLinearShard.R
	Rscript compare-models.R --what sfpLinear --choice shard --index 23

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
