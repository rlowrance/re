# run the mlogit brand model on file mlogit.csv

mydata <- read.csv("mlogit.csv")

attach(mydata)
names(mydata)
table(mydata$brand)
table(mydata$female)
summary(mydata$age)
sd(mydata$age)
xtabs(~mydata$female + mydata$brand)

library(mlogit)
mydata[1:10,]

mydata$brand <- as.factor(mydata$brand)
mldata <- mlogit.data(mydata, varying=NULL, choice="brand", shape="wide")

mldata[1:10,]

mlogit.model <- mlogit(brand ~1|female+age, data=mldata, reflevel="1")
#sink("mlogit-summary.txt")
s <- summary(mlogit.model)
#sink(NULL)
capture.output(s, file="mlogit-summary.txt")

