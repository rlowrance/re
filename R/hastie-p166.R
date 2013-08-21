# recreating hastie-02 p 166
dir <- "/home/roy/Dropbox/nyu-thesis-project/data/generated-v4/tests/"
path <- paste(dir,"HastieKernelSmoothingExample-KNearestNeighbors.csv",sep="")
ds <- read.csv(path, sep="|")
plot(ds$x, ds$y, pch=0)       
points(ds$x, ds$yHat, pch=1)
