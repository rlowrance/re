CompareModelsAn01 <- function(data, showGraph=FALSE) {
    # determine median price by month
    # RETURN ggplot2 object
    #cat('starting CompareModelsAn01', nrow(data), '\n'); browser()

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
    all.month.str <- NULL

    for (year in 2006:2009) {
        last.month <- ifelse(year == 2009, 11, 12)
        for (month in 1:last.month) {
            median.price <- MedianPrice(year, month)

            date.chr <- sprintf('%02d-%02d-01', year, month)
            date <- as.Date(date.chr, '%Y-%m-%d')

            month.str <- sprintf('%04d-%02d', year, month)

            all.median.price <- c(all.median.price, median.price)
            all.date <- c(all.date, date)
            all.month.str <- c(all.month.str, month.str)
        }
    }

    #cat('starting analysis\n'); browser()
    analysis <- data.frame(date = all.date,
                           median.price = all.median.price)

    month.factor <- factor(all.month.str, levels=sort(all.month.str, decreasing = TRUE))
    analysis <- data.frame(month = month.factor,
                           median.price = all.median.price)
    print('analysis')
    print(analysis)

#    analysis <- data.frame(date = all.some.date.str,
#                           median.price = all.median.price)

    # assume ggplot2 is available
    # make Cleveland dot plot
    assumed.max.median.price <- 800000
    stopifnot(max(analysis$median.price) <= assumed.max.median.price)
    gg <- ggplot(analysis,
                 aes(x = median.price, y = month))
    g <- 
        gg + 
        geom_point(size = 3) + 
        xlim(0, assumed.max.median.price) 
        theme_bw() +
        theme(panel.grid.major.x = element_blank(),
              panel.grid.minor.x = element_blank(),
              panel.grid.major.y = element_blank())  #  no horizontal grid lines

    if (showGraph) {
        X11(width = 14, height = 10)
        print(g)
    }

    g
}

