# BestApns.R

BestApns <- function(apns.unformatted, apns.formatted) {
  # Return vector of best APN values
  #
  # Args:
  # apns.unformatted: character or num vector, possibly with NAs
  # apns.formatted: character vector, possibley with NAs
  #
  # Details:
  # 1. Use apns.unformatted where its all digits (if char) or a number.
  # 2. Otherwise, if apns.formatted after hyphens removes is a number, use it
  # 3. Otherwise, use NA
  #
  # Value:
  # num vector of best APNs, from mergine the two sources
  
  only.digits <- "^[0123456789]+$"
  # Remove the hyphens from the formatted APNs.
  # Note: Many of the formatted APNs have spaces. It is tempting to remove
  # the spaces and hyphens, then operate on the resulting number; however,
  # very often the resulting number has the wrong number of digits to be
  # a valid APN. For example, one with spaces is "201021 3" and "2010213" does
  # not have the 10 digits that an APN is supposed to have.
  apns.formatted.no.hyphens <- gsub("-", "", apns.formatted)
  
  if (is.character(apns.unformatted)) {
    # some of the supposedly unformatted APNs are actually formatted.
    # remove those hyphens
    apns.unformatted.no.hyphens <- gsub("-", "", apns.unformatted)
    # Prefer in order
    # 1. The unformatted APN, if its all digits
    # 2. The formatted APN, if its all digits
    # 3. The NA value otherwise.
    apns.recoded <- ifelse(grepl(only.digits, apns.unformatted.no.hyphens),
                           apns.unformatted.no.hyphens,
                           ifelse(grepl(only.digits, apns.formatted.no.hyphens),
                                  apns.formatted.no.hyphens,
                                  rep(NA, length(apns.unformatted))))
    return(as.numeric(apns.recoded))
  }
  else if (is.numeric(apns.unformatted)) {
    # Same preferences as before
    apns.recoded <- ifelse(!is.na(apns.unformatted),
                           apns.unformatted,
                           ifelse(grepl(only.digits, apns.formatted.no.hyphens),
                                  apns.formatted.no.hyphens,
                                  rep(NA, length(apns.unformatted))))
    return(as.numeric(apns.recoded))
  }
  else {
    print(apns.unformatted)
    cat('first arg', apns.unformatted, '\n')
    stop("first arg has invalid type")
  }
  
}

BestApns.test <- function() {
  # unit test
  verbose <- FALSE
  apn.unformatted.character <- c("123", "4-56", NA, "12x", "x56")
  apn.unformatted.numeric <- c(123, 456, NA, NA, NA)
  apn.formatted <- c("1-23", NA, "7-89", "1-23", NA)
  
  test <- function(result) {
    if (verbose) cat("result", result, "\n")
    if (result[1] != "123")
      stop(cat(1, result[1]))
    if (result[2] != "456")
      stop(cat(2, result[2]))
    if (result[3] != "789")
      stop(cat(3, result[3]))
    if (result[4] != "123")
      stop(cat(4, result[4]))
    if (!is.na(result[5]))
      stop(cat(5, result[5]))
  }
  t1 <- BestApns(apn.unformatted.character, apn.formatted)
  if (verbose) cat("t1", t1, "\n")
  test(t1)
  t2 <- BestApns(apn.unformatted.numeric, apn.formatted)
  if (verbose) cat("t2", t2, "\n")
  test(t2)
}

BestApns.test()
