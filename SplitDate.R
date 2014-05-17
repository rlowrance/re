# SplitDate.R
# Split date YYYY-MM-DD into YYYY, MM, DD
SplitDate <- function(date) {
  # split a date into year, month, and day
  # ARGS:
  # date : character vector in format "YYYY-MM-DD"
  # RETURNS:
  # list with numeric vector elements $year, $month, $day
  list(day=as.integer(substr(date, 9, 10)), 
       month=as.integer(substr(date, 6, 7)), 
       year=as.integer(substr(date, 1, 4)))
}
