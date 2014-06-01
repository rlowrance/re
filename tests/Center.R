# Center.R
# unit test
tests <- function() {
  centered = Center(c(1,2,3))
  checkEquals(centered[1], -1)
  checkEquals(centered[2], 0)
  checkEquals(centered[3], 1)
}
