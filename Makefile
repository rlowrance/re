# Makefile
# create output files using R and Torch

OUTPUT=../data/v6/output

CENSUS=$(OUTPUT)/census.csv
DEEDS.AL=$(OUTPUT)/deeds-al.csv
PARCELS.SFR=$(OUTPUT)/parcels-sfr.csv
TRANSACTIONS=$(OUTPUT)/transactions-al-sfr.csv
SUBSET1=$(OUTPUT)/transactions-subset1.csv
TOIMPUTE=$(OUTPUT)/transactions-subset1-to-impute.csv
 
# These rules come from
# https://github.com/yihui/knitr/blob/master/inst/doc/Makefile

%.pdf: %.Rnw
	RScript -e "if (getRversion() < '3.0.0') knitr::knit2pdf('$*.Rnw') else tools::texi2pdf('$*.tex')"

%.html: %.Rmd
	Rscript -e "if (getRversion() < '3.0.0') knitr::knit2html('$*.Rmd')"

.PHONY: all
all: \
 $(CENSUS) $(DEEDS.AL) $(PARCELS.SFR) $(TRANSACTIONS) $(SUBSET1) $(TOIMPUTE) \
 $(OUTPUT)/parcels-sfr-geocoded.csv \
 $(OUTPUT)/geocoding-valid.csv \
 $(OUTPUT)/parcels-sfr-recoded.csv \
 $(OUTPUT)/parcels-missing-codes-analysis.csv \
 $(OUTPUT)/parcels-sfr-recoded.csv \
 $(OUTPUT)/parcels-sfr-geocoded.csv \
 $(OUTPUT)/parcels-HEATING.CODE-unknown.pairs

$(OUTPUT)/parcels-HEATING.CODE-unknown.pairs: \
 $(OUTPUT)/parcels-sfr-geocoded.csv \
 parcels-pairs.lua 
	torch parcels-pairs.lua --code HEATING.CODE
# also creates
# parcels-HEATING.CODE-known-test.pairs
# parcels-HEATING.CODE-known-val.pairs
# parcels-HEATING.CODE-known-train.pairs

$(OUTPUT)/parcels-missing-codes-analysis.csv: \
 parcels-missing-codes-analysis.lua \
 $(OUTPUT)/parcels-sfr-geocoded.csv
	torch parcels-missing-codes-analysis.lua

$(OUTPUT)/parcels-sfr-recoded.csv: \
 parcels-sfr-recoded.lua \
 $(OUTPUT)/parcels-sfr.csv
	torch parcels-sfr-recoded.lua

$(OUTPUT)/geocoding-valid.csv: geocoding-valid.lua
	torch geocoding-valid.lua

$(OUTPUT)/parcels-sfr-geocoded.csv: \
 parcels-sfr-geocoded.lua \
 $(OUTPUT)/geocoding-valid.csv \
 $(OUTPUT)/parcels-sfr-recoded.csv	
	torch parcels-sfr-geocoded.lua

$(CENSUS): census.Rmd
	Rscript -e "knitr::knit2html('census.Rmd')"
	mv census.html $(OUTPUT)/
	rm census.md

$(DEEDS.AL): deeds-al.Rmd
	Rscript -e "knitr::knit2html('deeds-al.Rmd')"
	mv deeds-al.html $(OUTPUT)/
	rm deeds-al.md

$(PARCELS.SFR): parcels-sfr.Rmd
	Rscript -e "knitr::knit2html('parcels-sfr.Rmd')"
	mv parcels-sfr.html $(OUTPUT)/
	rm parcels-sfr.md

$(TRANSACTIONS): transactions-al-sfr.Rmd $(CENSUS) $(DEEDS.AL) $(PARCELS.SFR)
	Rscript -e "knitr::knit2html('transactions-al-sfr.Rmd')"
	mv transactions-al-sfr.html $(OUTPUT)/
	rm transactions-al-sfr.md

# Creating $(SUBSET1) also creates
#  transactions-subset1-ranges.tex 
#  transactions-subset1-excluded.tex
$(SUBSET1): transactions-subset1.Rmd $(TRANSACTIONS)
	Rscript -e "knitr::knit2html('transactions-subset1.Rmd')"
	mv transactions-subset1.html $(OUTPUT)/
	rm transactions-subset1.md

# Creating $(TOIMPUTE) also creates
#  transactions-subset1-analyze-qualitative-features.tex
#  transactions-subset1-analyze-imputed-features.tex
$(TOIMPUTE): transactions-subset1-to-impute.Rmd $(SUBSET1)
	Rscript -e "knitr::knit2html('transactions-subset1-to-impute.Rmd')"
	mv transactions-subset1-to-impute.html $(OUTPUT)/
	rm transactions-subset1-to-impute.md


.PHONY: clean
clean:
	rm deeds-raw-analysis.html
	rm *.md
