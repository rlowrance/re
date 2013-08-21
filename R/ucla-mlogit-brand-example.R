# ucla-mlogit-brand-example.R

zz <- file('/home/roy/Dropbox/nyu-thesis-project/src.git/R/ucla-mlogit-brand-example.output','wt')
sink(zz, split=TRUE)  # write output to specified file and to console
mydata <- read.csv(url("http://www.ats.ucla.edu/stat/r/dae/mlogit.csv"))
attach(mydata)

names(mydata)
table(brand)
table(female)
summary(age)
sd(age)
xtabs(~ female + brand)

library(mlogit)

mydata[1:10,]

mydata$brand <- as.factor(mydata$brand)
mldata <- mlogit.data(mydata, varying=NULL, choice="brand", shape="wide")

mldata[1:10,]

mlogit.model <- mlogit(brand~1|female+age, data=mldata,reflevel="1")
summary(mlogit.model)

exp(coef(mlogit.model))

newdata <- data.frame(cbind(age=rep(24:38,2), female=c(rep(0,15), rep(1,15))))
logit1 <- rep(0,30)
logit2 <- -11.774655 + 0.523814*newdata$female + 0.368206*newdata$age
logit3 <- -22.721396 + 0.465941*newdata$female + 0.685908*newdata$age

logits <- cbind(logit1, logit2, logit3)
p.unscaled <- exp(logits)
p <- cbind(newdata, (p.unscaled / rowSums(p.unscaled)))
colnames(p) <- c("age", "female", "pred.1", "pred.2", "pred.3")

p
