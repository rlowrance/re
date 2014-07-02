CompareModelsAn01 <- function(data, verbose=FALSE) {
    # determine median price by month
    # RETURN ggplot2 object
    cat('starting CompareModelsAn01', nrow(data), '\n'); browser()

    MedianPrice <- function(year, month) {
        # TODO: select columns and rows; compute median price
        #cat('starting MedianPrice\n', year, month, '\n'); browser()
        selected <- data$sale.year == year & data$sale.month == month
        price <- data[selected, 'price']
        median.price <- median(price)
        median.price
    }

    all.median.price <- NULL
    all.date <- NULL
    all.date.str <- NULL
    all.some.date.str <- NULL

    for (year in 2006:2009) {
        last.month <- ifelse(year == 2009, 11, 12)
        for (month in 1:last.month) {
            median.price <- MedianPrice(year, month)

            date.chr <- sprintf('%02d-%02d-01', year, month)
            date <- as.Date(date.chr, '%Y-%m-%d')
            date.str <- sprintf('%04d-%02d', year, month)

            all.median.price <- c(all.median.price, median.price)
            all.date <- c(all.date, date)
            all.date.str <- c(all.date.str, date.str)
            all.some.date.str <- c(all.some.date.str, ifelse(month==1, date.str, ' '))
        }
    }

    cat('starting analysis\n'); browser()
    analysis <- data.frame(date = all.date,
                           median.price = all.median.price)

    analysis <- data.frame(stringsAsFactors = TRUE, 
                           date = all.date.str,  # will be converted to factor
                           median.price = all.median.price)

#    analysis <- data.frame(date = all.some.date.str,
#                           median.price = all.median.price)

    # assume ggplot2 is available
    # make Cleveland dot plot
    assumed.max.median.price <- 800000
    stopifnot(max(analysis$median.price) <= assumed.max.median.price)
    gg <- ggplot(analysis,
                aes(x = median.price, y = date))
    g <- gg + geom_point(size = 3) + xlim(0, assumed.max.median.price)

    if (FALSE) {
        gg <- ggplot(analysis,
                     aes(x = rev(date), y = median.price))
        g <- gg + geom_bar(stat='identity') + geom_text(aes(label = date), vjust = -0.2)
    }
    if (verbose) {
        X11()
        print(g)
    }

    g
}

