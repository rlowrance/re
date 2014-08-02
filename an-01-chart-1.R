# main program to produce charts for from an-01.rsave
# input file  OUTPUT/an-01.rsave
# write files OUTPUT/an-01-chart-1.pdf
#                    an-01-chart-log.txt

source('FileInput.R')
source('FileOutput.R')
source('InitializeR.R')
source('LoadColumns.R')

library(ggplot2)

# declare input and output files
# NOTE: these declarations are used in part to form the makefile
control <- list( testing = FALSE
                ,show.graph = FALSE
                ,path.in         = FileInput ('../data/v6/output/an-01.rsave')
                ,path.out.result = FileOutput('../data/v6/output/an-01-chart-1.pdf')
                ,path.out.log    =            '../data/v6/output/an-01-chart-log.txt'
                )

InitializeR(duplex.output.to = control$path.out.log)

print('control variables')
print(control)


Main <- function(control) {
    #cat('starting Main\n'); browser()

    loaded.vars <- load(control$path.in)
    stopifnot(length(loaded.vars) == 1)
    stopifnot(loaded.vars[[1]] == 'analysis')

    # make a Cleveland dot plot (see R Graphics Cookbook p 44)
   
    month.str <- sprintf('%04d-%02d', analysis$sale.year, analysis$sale.month)
    month.factor <- factor( month.str
                           ,levels = sort(month.str, decreasing = TRUE)
                           )

    data <- data.frame( median.price = analysis$median.price
                       ,month = month.factor
                       )

    gg <- ggplot( data
                 ,aes(x = median.price, y = month))

    assumed.max.median.price = 800000
    g <- 
        gg +
        geom_point(size = 3) +
        xlim(0, assumed.max.median.price) +
        theme_bw() +
        theme( panel.grid.major.x = element_blank()
              ,panel.grid.minor.x = element_blank()
              ,panel.grid.major.y = element_blank()
              )

    width <- 14
    height <- 10

    if (control$show.graph) {
        X11(width = width, height = height)
        print(g)
    }

    pdf( file = control$path.out.result
        ,width = width
        ,height = height
        )
    print(g)
    dev.off()

    NULL
}

Main(control)

print('control variables')
print(control)

cat('done\n')
