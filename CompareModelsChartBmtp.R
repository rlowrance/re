# CompareModelsChartBmtp.R

BmtpGraphic <- function(data, x.label) {
    # return graphic, a scatterplot
    #cat('starting BmtpGraphic\n'); browser()
    gg <- ggplot( data
                 ,aes( x = median.price.increase
                      ,y = optimal.training.days
                      )
                 )

    g <-
        gg +
        geom_point(shape = 19) +
        geom_text( mapping = aes( x = median.price.increase
                                 ,y = optimal.training.days + 10
                                 ,label = period.name
                                 )
                   ,size = 2
                   ) +
        xlab(x.label) +
        theme_bw() +
        theme(panel.grid.major.x = element_blank(),
              panel.grid.minor.x = element_blank(),
              panel.grid.major.y = element_blank())  #  no horizontal grid lines

    g
}

BmtpChart <- function(control, median.prices, all.row) {
    # create and save scatter plot # training days (x) vs change in median price (y)
    # assemble the data frame, then call BmtpChartGraphic to produce the graphi
    #cat('starting BmptChart\n'); browser()
    display <- FALSE
    #display <- TRUE

    # determine median price increase starting 2008-jan through 2009-nov
    mp <- median.prices$median.price

    mp.offset.1 <- c(NA, mp[1: (length(mp) - 1)])
    mp.offset.4 <- c(NA, NA, NA, NA, mp[1: (length(mp) - 4)])

    one.month.median.price.increase <- mp / mp.offset.1
    four.month.median.price.increase <- mp / mp.offset.4

    month.str <- attr(median.prices$month, 'level')[median.prices$month]
    year <- as.numeric(substr(month.str, 1, 4))
    month <- as.numeric(substr(month.str, 6,7))

    price.increases.with.na <- data.frame( stringsAsFactors = FALSE
                                          ,one.month.median.price.increase = one.month.median.price.increase
                                          ,four.month.median.price.increase = four.month.median.price.increase
                                          ,year = year
                                          ,month = month
                                          )
    price.increases <- na.omit(price.increases.with.na)
    
    merged.all <- merge( x = price.increases
                        ,y = all.row
                        ,by = c('year', 'month')
                        )

    merged.unsorted <- subset( merged.all
                              ,select = c( 'year'
                                          ,'month'
                                          ,'one.month.median.price.increase'
                                          ,'four.month.median.price.increase'
                                          ,'training.days'
                                          )
                              )

    merged <- merged.unsorted[with(merged.unsorted, order(year, month)), ]
    period.name <- sprintf('%02d-%d', merged$year %% 1000, merged$month)

    CreateAndSave <- function(months.of.increase) {
        # create a graphic and save it to appropriate file
        #cat('starting CreateAndSave', months.of.increase, '\n'); browser()
        data <- data.frame( optimal.training.days = merged$training.days
                           ,median.price.increase = 
                               switch( months.of.increase  
                                      ,merged$one.month.median.price.increase
                                      ,NULL
                                      ,NULL
                                      ,merged$four.month.median.price.increase
                                      )
                           ,period.name = period.name
                           )

        x.label <- switch( months.of.increase
                          ,'one.month.increase.median.price'
                          ,'error'
                          ,'error'
                          ,'four.month.increase.median.price'
                          )
        g <- BmtpGraphic( data = data
                         ,x.label = x.label
                         )

        graphic.width <- 7  # inches
        graphic.height <- 5
        if (display) {
            X11( width = graphic.width
                ,height = graphic.height
                )
            print(g)
            # leave device open so that user can view the graphic
            #dev.off()  
        }

        path.out <- sprintf('%s%s-bmtp-assessor-chart-%d.pdf', 
                            control$dir.output, control$me, months.of.increase)



        pdf( path.out
            ,width = graphic.width
            ,height = graphic.height
            )
        print(g)
        dev.off()  # close pdf file
        g
    }

    g1 <- CreateAndSave(1)
    g4 <- CreateAndSave(4)
    result <- list(g1, g4)
    result
}


CompareModelsChartBmtp <- function(control) {
    # create scatter plot: change in median price vs. # training days
    #cat('starting CompareModelsChartBmpt', control$choice, '\n'); browser()

    ReadMedianPrices <- function(path) {
        #cat('starting ReadMedianPrices', path, '\n'); browser()
        an.result <- NULL
        variables.loaded <- load(path)
        stopifnot(!is.null(an.result))
        # pull out median prices and return them
        median.prices <- an.result$data
        median.prices
    }

    ReadAllRow <- function(path) {
        # return all.row data frame
        #cat('starting ReadAllRow', path, '\n'); browser()
        all.row <- NULL
        variables.loaded <- load(path)
        stopifnot(!is.null(all.row))
        all.row
    }


    path.an01 <- paste0(control$dir.output, 'compare-models-an-01.rsave')
    median.prices <- ReadMedianPrices(path.an01)

    path.bmtp <- paste0(control$dir.output, 'compare-models-bmtp-assessor.rsave')
    all.row <- ReadAllRow(path.bmtp)
    
    result <- BmtpChart(control, median.prices, all.row)
    result
}

