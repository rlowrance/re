# SplitDate.R
# unit test of SplitData function
tests <- function() {
  split <- SplitDate(c('1111-22-33', '1929-06-02'))
  checkEqualsNumeric(split$year, c(1111, 1929))
  checkEqualsNumeric(split$month, c(22, 06))
  checkEqualsNumeric(split$day, c(33, 02))
}
