# Center.R
# center values in a vector
Center <- function(v) {
 (v - mean(v, na.rm=TRUE)) / sd(v, na.rm=TRUE)
}

CenterTest <- function() {
  centered = Center(c(1,2,3))
  stopifnot(centered[1] == -1)
  stopifnot(centered[2] == 0)
  stopifnot(centered[3] == 1)
}

CenterTest()

