# an.makefile
# make file OUTPUT/an-NN.rsave
#                 /an-NN-chart*.rsave

# targets
OUTPUT=../data/v6/output
AN01=$(OUTPUT)/an-01.rsave
AN01CHART1=$(OUTPUT)/an-01-chart-1.pdf

TARGETS=$(AN01) $(AN01CHART1)

$(warning TARGETS is $(TARGETS))

# input files
TRANSACTIONS=$(OUTPUT)/transactions-subset1
PRICE=$(TRANSACTIONS)-price.rsave
SALE_YEAR=$(TRANSACTIONS)-sale.year.rsave
SALE_MONTH=$(TRANSACTIONS)-sale.month.rsave

$(warning TRANSACTIONS is $(TRANSACTIONS))
$(warning PRICE is $(PRICE))

.PHONY: all
all: $(TARGETS)

$(AN01): $(PRICE) $(SALE_YEAR) $(SALE_MONTH) an-01.R
	Rscript an-01.R

$(AN01CHART1): $(AN01) an-01-chart-1.R
	Rscript an-01-chart-1.R
