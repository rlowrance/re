# compare-model-chart.makefile
# create compare-modelds-chart-XXXXX
# create model-lienar-test-chartXXXX
	
OUTPUT=../data/v6/output



BMTP_ASSESSOR=$(OUTPUT)/compare-models-chart-bmtp-assessor-chart-1.pdf

CV01=$(OUTPUT)/compare-models-chart-cv-01-chart-1.pdf
CV02=$(OUTPUT)/compare-models-chart-cv-02-chart-1.pdf
CV03=$(OUTPUT)/compare-models-chart-cv-03-chart-1.pdf
CV04=$(OUTPUT)/compare-models-chart-cv-04-chart-1.pdf
CV05=$(OUTPUT)/compare-models-chart-cv-05-chart-1.pdf

SFPLINEAR_01=$(OUTPUT)/compare-models-chart-sfplinear-combine-chart-01.csv
SFPLINEAR_02=$(OUTPUT)/compare-models-chart-sfplinear-combine-chart-02-1.pdf
SFPLINEAR_03=$(OUTPUT)/compare-models-chart-sfplinear-combine-chart-03-1.pdf

SFPLINEAR=$(SFPLINEAR_01) $(SFPLINEAR_02) $(SFPLINEAR_03)

MODEL_LINEAR_TEST_CHART=$(OUTPUT)/model-linear-test-chart1.txt

TARGETS=$(BMTP_ASSESSOR) $(CV01) $(CV02) $(CV03) $(CV04) $(CV05)  $(SFPLINEAR) $(MODEL_LINEAR_TEST_CHART)

$(warning TARGETS is $(TARGETS))

.PHONY: all
all: $(TARGETS)

$(BMTP_ASSESSOR): CompareModelsChartBmtp.R \
	$(OUTPUT)/compare-models-an-01.rsave \
	$(OUTPUT)/compare-models-bmtp-assessor.rsave
	Rscript compare-models-chart.R --what bmtp --choice assessor

$(CV01): $(OUTPUT)/compare-models-cv-01.rsave CompareModelsChartCv.R
	Rscript compare-models-chart.R --what cv --choice 01

$(CV02): $(OUTPUT)/compare-models-cv-02.rsave CompareModelsChartCv.R
	Rscript compare-models-chart.R --what cv --choice 02

$(CV03): $(OUTPUT)/compare-models-cv-03.rsave CompareModelsChartCv.R
	Rscript compare-models-chart.R --what cv --choice 03

$(CV04): $(OUTPUT)/compare-models-cv-04.rsave CompareModelsChartCv.R
	Rscript compare-models-chart.R --what cv --choice 04

$(CV05): $(OUTPUT)/compare-models-cv-05.rsave CompareModelsChartCv.R
	Rscript compare-models-chart.R --what cv --choice 05

$(SFPLINEAR_01): $(OUTPUT)/compare-models-sfplinear-combine.rsave CompareModelsChartSfpLinear.R
	Rscript compare-models-chart.R --what sfpLinear --choice 01

$(SFPLINEAR_02): $(OUTPUT)/compare-models-sfplinear-combine.rsave CompareModelsChartSfpLinear.R
	Rscript compare-models-chart.R --what sfpLinear --choice 02

$(SFPLINEAR_03): $(OUTPUT)/compare-models-sfplinear-combine.rsave CompareModelsChartSfpLinear.R
	Rscript compare-models-chart.R --what sfpLinear --choice 03

$(MODEL_LINEAR_TEST_CHART): $(OUTPUT)/model-linear-test.rsave model-linear-test-chart.R
	Rscript model-linear-test-chart.R

$(OUTPUT)/model-linear-test.rsave: model-linear-test.R DataSynthetic.R
	Rscript model-linear-test.R
