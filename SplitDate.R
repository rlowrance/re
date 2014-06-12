# SplitDate.R
# Split date YYYY-MM-DD into YYYY, MM, DD
SplitDate <- function(date, format = 'YYYY-MM-DD') {
    # split a date into year, month, and day
    # ARGS:
    # date : character vector in format "YYYY-MM-DD"
    # format : scalar string, either 'YYYY-MM-DD' or 'YYYYMMDD'
    # RETURNS:
    # list with numeric vector elements $year, $month, $day
    if (format == 'YYYY-MM-DD') {
        list(day   = as.integer(substr(date, 9, 10)), 
             month = as.integer(substr(date, 6, 7)), 
             year  = as.integer(substr(date, 1, 4)))
    } else if (format == 'YYYYMMDD') {
        list(day   = as.integer(substr(date, 7, 8)),
             month = as.integer(substr(date, 5, 6)),
             year  = as.integer(substr(date, 1, 4)))
    } else {
        stop(paste('bad format', format))
    }
}
