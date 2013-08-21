# logisticregression.R
# multinomial logistic regression
# ref:
# www.ats.ucls.edu/stat/r/dae/mlogit.htm

mydata <- read.csv("mlogit.csv")
table(mydata$brand)