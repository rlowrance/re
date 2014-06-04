# ReadCaseShiller.R
ReadCaseShiller <- function(area) {
    # return data.frame containing Case-Shiller indices for specified path
    # ARGS:
    # area : name of area, used to locate and read the file
    # RETURNS list with these named elements
    # $df       : data.frame with columns year, month, index
    # $Retrieve : function(year, month) returns index (number) or NA
    LA <- function(path) {
        df <- read.csv(file = path,
                       stringsAsFactor = FALSE,
                       skip = 6)
        names(df) <- c('date', 'index')
        good.observations <- !is.na(df$index)
        month.names <- substr(df$date, 1, 3)[good.observations]
        month.number <- sapply(month.names, function(month.name) {
            switch(month.name,
                Jan = 1,
                Feb = 2,
                Mar = 3,
                Apr = 4,
                May = 5, 
                Jun = 6,
                Jul = 7,
                Aug = 8,
                Sep = 9,
                Oct = 10,
                Nov = 11,
                Dec = 12)
                       })
        month <- as.vector(month.number)
        year <- as.numeric(substr(df$date[good.observations], 5, 8))
        df2 <- data.frame(year = year,
                          month = month,
                          index = df$index[good.observations])
        df2
    }

    df <- switch(area,
                 LosAngeles = LA('../data/raw/case-shiller/los-angeles.csv'))

    Retrieve <- function(year, month) {
        # return index (or NA) for the area in the year and month
        ok.year <- df$year == year
        ok.month <- df$month == month
        value <- df[ok.year & ok.month, 'index']
        ifelse(length(value) == 1, value, NA)
    }

    #browser()
    list(df = df,
         Retrieve = Retrieve)
}

ReadCaseShillerTest <- function() {
    options(warn = 2)

    result <- ReadCaseShiller('LosAngeles')
    df <- result$df
    Retrieve <- result$Retrieve

    stopifnot(is.data.frame(df))

    stopifnot(Retrieve(1980,1) == 41.67)
    stopifnot(is.na(Retrieve(1979,12)))
}

ReadCaseShillerTest()
