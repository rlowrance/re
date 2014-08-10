ModelLinearTestPrintAllResults <- function(all.results, file='') {
    # write txt file using Printf()

    if (file != '') {
        connection <- file(file, 'w')
    }


    PrintTable <- function(all.results) {
        #cat('start PrintTable\n'); browser()

        format.header <- '%19s | %15s %15s %15s %15s\n'
        format.data <- '%19s | %15.0f %15.0f %15.0f %15.0f\n'

        P <- function(...) {
            if (file == '') {
                Printf(...) 
            } else {
                Printf(..., file = connection)  # append to cat file
            }
        }

        P('RMSE\n')
        P( format.header
          ,'scenario'
          ,'level-level'
          ,'level-log'
          ,'log-level'
          ,'log-log')

        Rmse <- function(scenario, response.name, predictors.name) {
            for (result in all.results) {
                if (result$scenario == scenario &&
                    result$response.name == response.name &&
                    result$predictors.name == predictors.name) {
                    return(result$rmse)
                }
            }
            cat('in Rmse; about to fail', scenario, response.name, predictors.name, '\n'); browser()
            stop('bad')
        }


        P( format.data
          ,'assessor'
          ,Rmse('assessor', 'level', 'level'), Rmse('assessor', 'level', 'log')
          ,Rmse('assessor', 'log', 'level'), Rmse('assessor', 'log', 'log')
          )
        P( format.data
          ,'avm w/o assessment'
          ,Rmse('avm', 'level', 'level'), Rmse('avm', 'level', 'log')
          ,Rmse('avm', 'log', 'level'), Rmse('avm', 'log', 'log')
          )
        P( format.data
          ,'avm w/ assessment'
          ,Rmse('avm', 'level', 'levelAssessment'), Rmse('avm', 'level', 'logAssessment')
          ,Rmse('avm', 'log', 'levelAssessment'), Rmse('avm', 'log', 'logAssessment')
          )
        P( format.data
          ,'mortgage'
          ,Rmse('mortgage', 'level', 'levelAssessment'), Rmse('mortgage', 'level', 'logAssessment')
          ,Rmse('mortgage', 'log', 'levelAssessment'), Rmse('mortgage', 'log', 'logAssessment')
          )
    }

    PrintTable(all.results)
    if (file != '') {
        close(connection)
    }
}
