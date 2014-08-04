# CompareModelsChartSfpLinear.R

SfpLinearChart01 <- function(all.rows, path.out.base) {
    # write csv file
    #cat('starting SpfLinearChart01\n'); browser()
    path.out <- paste0(path.out.base, '.csv')
    write.csv( all.rows
              ,file=path.out)
}

SfpLinearChart02 <- function(all.rows, path.out.base) {
    # scatterplot period x RMSE by scenario; for each model form
    # return NULL
    Graphic <- function(data, title) {
        # return graphic object, a ggplot instance
        #cat('starting Graphic\n'); browser()
        gg <- ggplot( data
                     ,aes( x = test.month
                          ,y = rmse
                          ,color = scenario)
                     )
        g <-
            gg +
            geom_point(position=position_jitter(width=0)) +
            ggtitle(title) +
            theme_bw() +
            theme(panel.grid.major.x = element_blank(),
                  panel.grid.minor.x = element_blank(),
                  panel.grid.major.y = element_blank()) # no horizontal grid lines
        g
    }

    BuildData <- function(all.rows, response.name, predictors.name) {
        # create data.frame containing just rows with indicated response.name and predictors.name
        #cat('starting BuildData\n'); browser()
        some <- all.rows[all.rows$response.name == response.name &
                         all.rows$predictors.name == predictors.name,
                         ]
        # return only needed columns
        result <- data.frame( test.month = some$testing.period.index
                             ,rmse = some$rmse
                             ,scenario = some$scenario.name
                             )

        result
    }

    DisplayGraphic <- function(g, graphic.width, graphic.height) {
        # display on X11 terminal
        X11( width = graphic.width
            ,height = graphic.height
            )
        print(g)
        # leave device open so that user can view the graphic
        #dev.off()   
    }

    WriteGraphic <- function(g, graphic.width, graphic.height, path.out) {
        # write to pdf file
        pdf ( path.out
             ,width = graphic.width
             ,height = graphic.height
             )
        print(g)
        dev.off()  # close pdf file
    }


    #cat('starting SfpLinearChart02\n'); browser()
    verbose <- FALSE
    if (verbose) print(str(all.rows))

    chart.index <- 0
    for (response.name in c('log', 'level')) {
         for (predictors.name in c('log', 'level')) {
             chart.index <- chart.index + 1 

             data <- BuildData(all.rows, response.name, predictors.name)
             title <- sprintf('RMSE vs. Prediction Month (1=Jan 2008)\nModel form: %s-%s',
                              response.name, predictors.name)
             g <- Graphic(data, title)

             graphic.width <- 7  # inches
             graphic.height <- 5
             if (verbose) DisplayGraphic(g, graphic.width, graphic.height)
             path.out <- sprintf('%s-%d.pdf', path.out.base, chart.index)
             WriteGraphic(g, graphic.width, graphic.height, path.out)
         }
    }
    NULL
}


SfpLinearChart03 <- function(all.rows, path.out.base) {
    # scatterplot: period x (best number training days) by scenario; for each model form

    Graphic <- function(data, title) {
        # return graphic object, a ggplot instance
        #cat('starting Graphic\n'); browser()
        gg <- ggplot( data
                     ,aes( x = test.month
                          ,y = best.num.training.days
                          ,color = scenario)
                     )
        g <-
            gg +
            geom_point(position=position_jitter(width=0)) +
            ggtitle(title) +
            theme_bw() +
            theme(panel.grid.major.x = element_blank(),
                  panel.grid.minor.x = element_blank(),
                  panel.grid.major.y = element_blank()) # no horizontal grid lines
        g
    }

    BuildData <- function(all.rows, response.name, predictors.name) {
        # create data.frame containing just rows with indicated response.name and predictors.name
        #cat('starting BuildData\n'); browser()
        some <- all.rows[all.rows$response.name == response.name &
                         all.rows$predictors.name == predictors.name,
                         ]
        # return only needed columns
        result <- data.frame( test.month = some$testing.period.index
                             ,best.num.training.days = some$best.num.training.days
                             ,scenario = some$scenario.name
                             )

        result
    }

    DisplayGraphic <- function(g, graphic.width, graphic.height) {
        # display on X11 terminal
        X11( width = graphic.width
            ,height = graphic.height
            )
        print(g)
        # leave device open so that user can view the graphic
        #dev.off()   
    }

    WriteGraphic <- function(g, graphic.width, graphic.height, path.out) {
        # write to pdf file
        pdf ( path.out
             ,width = graphic.width
             ,height = graphic.height
             )
        print(g)
        dev.off()  # close pdf file
    }


    #cat('starting SfpLinearChart03\n'); browser()
    verbose <- FALSE
    if (verbose) print(str(all.rows))

    chart.index <- 0
    for (response.name in c('log', 'level')) {
         for (predictors.name in c('log', 'level')) {
             chart.index <- chart.index + 1 

             data <- BuildData(all.rows, response.name, predictors.name)
             title <- sprintf('Best Num Training Days vs. Prediction Month (1=Jan 2008)\nModel form: %s-%s',
                              response.name, predictors.name)
             g <- Graphic(data, title)

             graphic.width <- 7  # inches
             graphic.height <- 5
             if (verbose) DisplayGraphic(g, graphic.width, graphic.height)
             path.out <- sprintf('%s-%d.pdf', path.out.base, chart.index)
             WriteGraphic(g, graphic.width, graphic.height, path.out)
         }
    }
    NULL
}

SfpLinearChart <- function(control, all.rows) {
    # write file OUTPUT/compare-models-chart-sfplinear-NN.KIND
    # where NN is control$choice

    path.out.base <- paste0(control$dir.output, control$me, '-sfplinear-combine-chart-', control$choice)
    switch( control$choice
           ,'01' = SfpLinearChart01(all.rows, path.out.base)
           ,'02' = SfpLinearChart02(all.rows, path.out.base)
           ,'03' = SfpLinearChart03(all.rows, path.out.base)
           ,stop('bad control$choice')
           )
}

CompareModelsChartSfpLinear <- function(control) {

    ReadAllRows <- function(path) {
        # return all.rows data frame in saved file
        #cat('starting ReadAllRows', path, '\n'); browser()
        variables.loaded <- load(path)
        stopifnot(length(variables.loaded) == 1)
        stopifnot(variables.loaded[[1]] == 'all.rows')
        all.rows
    }


    #cat('starting CompareModelsChartSfpLinear\n'); browser()

    verbose <- FALSE
    path.combine <- paste0(control$dir.output, 'compare-models-sfplinear-combine.rsave')
    all.rows <- ReadAllRows(path.combine)
    if (verbose) {
        print(str(all.rows))
    }
    result <- SfpLinearChart(control, all.rows)
    result
}

