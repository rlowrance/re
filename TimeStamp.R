# TimeStamp.R

TimeStamp <- function() {
  # Determine current wall clock time
  #
  # Args: NONE
  #
  # Returns:
  #   scalar character containing date and time
  
  format(Sys.time(), "%a %b %d %X %Y")
}
