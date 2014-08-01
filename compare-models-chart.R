# compare-model-chart.R
# Main program to create charts from the results of running compare-models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM   -->  (OLD)
#   produce file OUTPUT/compare-models-cv-chart-chart-NUM.pdf
# Rscript compare-models-chart.R --what XXX -- choice YYY -->
#   produce file OUTPUT/compare-models-chart-XXX-YYY.pdf

library(ggplot2)

source('Require.R')  # read function definition file if function does not exist

Require('CommandArgs')

Require('CompareModelsChartCv')

Require('InitializeR')
Require('ParseCommandLine')
Require('Printf')

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLine\n'); browser()
    result <- ParseCommandLine( cl
                               ,keywords = c('what', 'choice')
                               ,ignoreUnexpected = TRUE
                               ,verbose = TRUE
                               )
    result
}

AugmentControlVariables <- function(control) {
    # add additional control variables to list of control variables
    #cat('starting AugmentControlVariables\n'); browser()
    result <- control
    result$me <- 'compare-models-chart'

    # input/output
    result$dir.output <- '../data/v6/output/'
    
    Prefix <- function(program.name) {
        paste0(result$dir.output,
               program.name,
               '-', control$what,
               '-', control$choice)
    }

    prefix.in <- Prefix('compare-models')
    prefix.out <-Prefix(result$me)

    result$path.in.driver.result <- paste0(prefix.in, '.rsave')

    result$path.out.log <- paste0(prefix.out, '-log.txt')
    result$path.out.chart1 <- paste0(prefix.out, '-chart-1.pdf')

    # control variables for all the experiments

    result$testing <- TRUE
    result$testing <- FALSE
    result
}


AllSame <- function(values) {
    #cat('starting AllSame\n'); browser()
    result <- all(values == values[[1]])
    result
}

Varying <- function(descriptions) {
    # return chr vector of varying portions of names
    #cat('starting Varying\n'); browser()

    # pull out each field
    scenario <- lapply(descriptions, function(x) x$scenario)
    testing.period.first.date <- lapply(descriptions, function(x) x$testing.period$first.date)
    testing.period.last.date <- lapply(descriptions, function(x) x$testing.period$last.date)
    training.period <- lapply(descriptions, function(x) x$training.period)
    model <- lapply(descriptions, function(x) x$model)
    response <- lapply(descriptions, function(x) x$response)
    predictors <- lapply(descriptions, function(x) x$predictors)

    varying.values <- NULL
    varying.names <- NULL

    MaybeAppend <- function(name, values) {
        #cat('starting MaybeAppend\n'); browser()
        if (!AllSame(values)) {
            #cat('not all same'); browser()
            n <- length(values)
            if (is.null(varying.values)) {
                lapply(1:n, function(i) varying.values[[i]] <<- values[[i]])
            } else {
                lapply(1:n, function(i) varying.values[[i]] <<- paste(varying.values[[i]], values[[i]]))
            }
            varying.names <<- paste(varying.names, name)
            if (FALSE) {
                print('varying.values'); print(varying.values)
                print('varying.names'); print(varying.names)
            }
        }
    }

    # build up varying and varying.names to be just the fields that are not all the same
    MaybeAppend('scenario', scenario)
    MaybeAppend('testing.period.first.date', testing.period.first.date)
    MaybeAppend('testing.period.last.date', testing.period.last.date)
    MaybeAppend('training.period', training.period)
    MaybeAppend('model', model)
    MaybeAppend('response', response)
    MaybeAppend('predictors', predictors)

    result <- list(values = varying.values, names = varying.names)
    result
}




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
    display <- TRUE

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


Bmtp <- function(control) {
    # create scatter plot: change in median price vs. # training days
    #cat('starting Bmpt', control$choice, '\n'); browser()

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

SfpLinearChart01 <- function(all.rows, path.out.base) {
    # write csv file
    cat('starting SpfLinearChart01\n'); browser()
    path.out <- paste0(path.out.base, '.csv')
    write.csv( all.rows
              ,file=path.out)
}

SfpLinearChart <- function(control, all.rows) {
    # write file OUTPUT/compare-models-chart-sfplinear-NN.KIND
    # where NN is control$choice

    path.out.base <- paste0(control$dir.output, control$me, '-sfplinear-', control$choice)
    switch( control$choice
           ,'01' = SfpLinearChart01(all.rows, path.out.base)
           ,stop('bad control$choice')
           )
}

SfpLinear <- function(control) {
    ReadAllRows <- function(path) {
        # return all.rows data frame in saved file
        #cat('starting ReadAllRows', path, '\n'); browser()
        variables.loaded <- load(path)
        stopifnot(length(variables.loaded) == 1)
        stopifnot(variables.loaded[[1]] == 'all.rows')
        all.rows
    }

    cat('starting SfpLinear\n'); browser()
    verbose <- TRUE
    path.combine <- paste0(control$dir.output, 'compare-models-sfplinear-combine.rsave')
    all.rows <- ReadAllRows(path.combine)
    if (verbose) {
        print(str(all.rows))
    }
    result <- SfpLinearChart(control, all.rows)
    result
}



Main <- function(control) {
    # execute one command, return NULL
    #cat('starting Main', control$what, '\n'); browser()

    driver <- switch( control$what
                     ,cv = CompareModelsChartCv
                     ,bmtp = Bmtp
                     ,sfpLinear = SfpLinear
                     ,stop('bad control$what')
                     )
    driver(control)
}


###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
command.args <- CommandArgs(defaultArgs = list('--what', 'cv', '--choice', '01'))
#command.args <- CommandArgs(defaultArgs = list('--what', 'bmtp', '--choice', 'assessor'))
#command.args <- CommandArgs(defaultArgs = list('--what', 'sfpLinear', '--choice', '01'))

control <- AugmentControlVariables(ParseCommandLineArguments(command.args))

# initilize R
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.out.log)

# do the work
Main(control)

cat('control variables\n')
str(control)

if (control$testing) {
    cat('DISCARD RESULTS: TESTING\n')
}

cat('done\n')
