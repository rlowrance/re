# e-dist-landsize.R
# main program to determine empirical distribution of land.size for transactions in 2007 and 2008
# perhaps fit a distribution and deduce its parameters

split.names <- c('land.square.footage', 'price', 'sale.year')  # makefile dependencies

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')
Help <- function(x) utils::help(x)

library(ggplot2)
library(MASS)

Lognormal <- function(data) {
    # fit lognormal distribution distname, produce comparative histograms
    # return list
    # $estimate : num, vector of estimated parameters for the fitted distribution
    # $plot: object than can be plotted

    cat('start Lognormal\n'); browser()

    fit <- fitdistr( x = data$land.square.footage
                    ,densfun = 'lognormal'
                    )
    fit.meanlog = fit$estimate[['meanlog']]
    fit.sdlog = fit$estimate[['sdlog']]
    cat('Fitted parameters from the lognormal distribution\n')
    cat(' meanlog', fit.meanlog)
    cat(' sdlog', fit.sdlog)

    # put both theoretic and empirical values in one data frame with a categorical
    # variable that specifies which
    values <- c( data$land.square.footage
                ,rlnorm(n = nrow(data), meanlog = fit.meanlog, sdlog = fit.sdlog)
                )
    kind <- c( rep('empirical', nrow(data))
              ,rep('lognormal', nrow(data))
              )
    data2 <- data.frame( values = values
                        ,kind = kind
                        )

    # ref chang p 121
    both <- 
        ggplot(data2, aes(x = values)) +
        geom_histogram(binwidth = 2000, fill = 'white', color = 'black') +
        facet_grid(kind ~ .)
    print(both)

    result <- list( estimate = fit$estimate
                   ,plot = both
                   )
    result
}

Gamma <- function(data) {
    # fit Gamma distribution distname, produce comparative histograms
    # return list
    # $estimate : num, vector of estimated parameters for the fitted distribution
    # $plot: object than can be plotted

    cat('start Gamma\n'); browser()

    fit <- fitdistr( x = data$land.square.footage
                    ,densfun = 'gamma'
                    )
    # above statement fails with this error message:
    # Error in stats::optim(...)
    #   non-finite finite-difference value
    fit.shape = fit$estimate[['shape']]
    fit.scale = fit$estimate[['scale']]
    cat('Fitted parameters from the weibull distribution\n')
    cat(' shape', fit.shape)
    cat(' scale', fit.scale)

    # put both theoretic and empirical values in one data frame with a categorical
    # variable that specifies which
    values <- c( data$land.square.footage
                ,rweibull(n = nrow(data), shape = fit.shape, scale = fit.scale)
                )
    kind <- c( rep('empirical', nrow(data))
              ,rep('weibull', nrow(data))
              )
    data2 <- data.frame( values = values
                        ,kind = kind
                        )

    # ref chang p 121
    cat('in Weibull\n'); browser()
    both <- 
        ggplot(data2, aes(x = values)) +
        geom_histogram(binwidth = 2000, fill = 'white', color = 'black') +
        facet_grid(kind ~ .)
    print(both)

    result <- list( estimate = fit$estimate
                   ,plot = both
                   )
    result
}
Weibull <- function(data) {
    # fit Weibull distribution distname, produce comparative histograms
    # return list
    # $estimate : num, vector of estimated parameters for the fitted distribution
    # $plot: object than can be plotted

    fit <- fitdistr( x = data$land.square.footage
                    ,densfun = 'weibull'
                    )
    fit.shape = fit$estimate[['shape']]
    fit.scale = fit$estimate[['scale']]
    cat('Fitted parameters from the weibull distribution\n')
    cat(' shape', fit.shape)
    cat(' scale', fit.scale)

    # put both theoretic and empirical values in one data frame with a categorical
    # variable that specifies which
    values <- c( data$land.square.footage
                ,rweibull(n = nrow(data), shape = fit.shape, scale = fit.scale)
                )
    kind <- c( rep('empirical', nrow(data))
              ,rep('weibull', nrow(data))
              )
    data2 <- data.frame( values = values
                        ,kind = kind
                        )

    # ref chang p 121
    cat('in Weibull\n'); browser()
    both <- 
        ggplot(data2, aes(x = values)) +
        geom_histogram(binwidth = 2000, fill = 'white', color = 'black') +
        facet_grid(kind ~ .)
    print(both)

    result <- list( estimate = fit$estimate
                   ,plot = both
                   )
    result
}

Empirical <- function(data) {
    # determine distribution of the empirical data
    # return list
    # $density: graphic object containing density plot
    # $histogram: graphic object containing histogram plot

    average.price.per.square.foot <- mean(data$price / data$land.square.footage)
    cat('average price per square foot', average.price.per.square.foot, '\n')
    
    # empirical density function; ref: chang p 123
    density <- ggplot(data, aes(x=land.square.footage)) + geom_density()
    print(density)

    # histogram; ref: chang p 118
    histogram <- 
        ggplot(data, aes(x=land.square.footage)) + 
        geom_histogram(binwidth = 1000, fill = 'white', color = 'black')
    print(histogram)

    result <- list( density = density
                   ,histogram = histogram
                   )
    result
}


Main <- function(split.names) {
    #cat('start Main'); browser()

    path.output = '../data/v6/output/'
    me <- 'e-dist-landsize' 
    control <- list( path.in.base = paste0(path.output, 'transactions-subset1')
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,path.out.save = paste0(path.output, me, '.rsave')
                    ,sample.period = list( first.date = as.Date('2008-01-01')
                                          ,last.date = as.Date('2008-12-31')
                                          )
                    ,split.names = split.names
                    ,random.seed = 123
                    )

    InitializeR( duplex.output.to = control$path.out.log
                ,random.seed = control$random.seed
                )
    print(control)

    data.all.years <- ReadTransactionSplits( path.in.base = control$path.in.base
                                            ,split.names = control$split.names
                                            ,verbose = TRUE
                                            )
    data <- data.all.years[data.all.years$sale.year == 2007 | data.all.years$sale.year == 2008,]

    print(str(data))
    print(summary(data))

    empirical <- Empirical(data)

    # test two distributions
    # NOTE: gamma distribution fails
    # don't convert warnings to errors, as some warning are expected
    options(warn = 1)  # print warnings as they occur

    #gamma <- Gamma(data)   # commented out, as fails
    lognormal <- Lognormal(data) # fit log normal distribution
    weibull <- Weibull(data)  # fit weibull distribution

    options(warn = 2)  # resume conversion of warning to errors

    # Roy thinks that lognormal has a better visual fit
    # MAYBE: run a statistical test of this, perhaps a Chi-squared test



    # fit density function

    save(empirical, lognormal, weibull, file = control$path.out.save)
    print(control)

}



Main(split.names)
cat('done\n')
