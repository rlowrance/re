# simple-models.makefile
OUTPUT=../data/v6/output
TRANSACTIONS=$(OUTPUT)/transactions-subset1.csv
simple-models-cvall.txt: \
	simple-models.R Center.R CrossValidate2.R DuplexOutputTo.R \
	NumberFeaturesWithAnNA.R Printf.R ReadAndTransformTransactions.R SplitDate.R \
	$(TRANSACTIONS)
	Rscript simple-models.R cvall
