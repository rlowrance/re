# Makefile
# create OUTPUT/transactions-subset1.csv.gz and its predecessors
# create OUTPUT/transactions-subset1-SPLIT.rsave files

OUTPUT=../data/v6/output

CENSUS=$(OUTPUT)/census.csv
DEEDS=$(OUTPUT)/deeds-al.csv.gz
PARCELS=$(OUTPUT)/parcels-sfr.csv.gz
PARCELS_DERIVED_FEATURES=$(OUTPUT)/parcels-derived-features-zip5.csv
TRANSACTIONS=$(OUTPUT)/transactions-al-sfr.csv.gz
SUBSET1=$(OUTPUT)/transactions-subset1.csv.gz
SPLIT_EXAMPLE=$(OUTPUT)/transactions-subset1-apn.rsave
 
# These rules come from
# https://github.com/yihui/knitr/blob/master/inst/doc/Makefile

%.pdf: %.Rnw
	RScript -e "if (getRversion() < '3.0.0') knitr::knit2pdf('$*.Rnw') else tools::texi2pdf('$*.tex')"

%.html: %.Rmd
	Rscript -e "if (getRversion() < '3.0.0') knitr::knit2html('$*.Rmd')"

.PHONY: all
all: $(CENSUS) $(DEEDS) $(PARCELS) $(PARCELSDERIVEDFEATURES) $(SUBSET1) $(TRANSACTIONS) $(SPLIT_EXAMPLE)
$(CENSUS): census.R InitializeR.R
	Rscript census.R

$(DEEDS): deeds-al.R InitializeR.R PRICATCODE.R Printf.R
	Rscript deeds-al.R

$(PARCELS): parcels-sfr.R InitializeR.R LUSEI.R Printf.R
	Rscript parcels-sfr.R

$(PARCELS_DERIVED_FEATURES): parcels-derived-features.R LUSEI.R PROPN.R Printf.F
	Rscript parcels-derived-features.R

$(SUBSET1): transactions-subset1.R \
	InitializeR.R DEEDC.R LUSEI.R PRICATCODE.R PROPN.R SCODE.R SLMLT.R TRNTP.R \
	$(TRANSACTIONS)
	Rscript transactions-subset1.R

$(TRANSACTIONS): transactions-al-sfr.R \
	InitializeR.R BestApns.R \
	$(CENSUS) $(DEEDS) $(PARCELS) $(PARCELSDERIVEDFEATURES)
	Rscript transactions-al-sfr.R

$(SPLIT_EXAMPLE): transactions-subset1-SPLIT.R $(SUBSET1)
	Rscript transactions-subset1-SPLIT.R
