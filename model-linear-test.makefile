# model-linear-test.makefile

PGM=model-linear-test
REPORT=ModelLinearTestMakeReport

OUTPUT=../data/v6/output
RSAVE=$(OUTPUT)/$(PGM).rsave
CHART1=$(OUTPUT)/$(PGM)-chart1.txt

TARGETS=$(RSAVE) $(CHART1)

$(warning TARGETS is $(TARGETS))

.PHONY: all
all: $(TARGETS)

$(RSAVE): $(PGM).R $(REPORT).R DataSynthetic.R
	Rscript $(PGM).R

$(CHART1): $(PGM)-chart.R $(REPORT).R $(RSAVE)
	Rscript $(PGM)-chart.R
