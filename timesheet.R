# timesheet.R
# produce time used reports from timesheet file

control <- list()
control$me <- 'timesheet'
control$path.input <- '~/Dropbox/todo/timesheet.org'

Main <- function(control) {
}

Trim <- function(str) {
    # remove leading and trailing whitespace
    gsub('^[[:space:]]+|[[:space:]]+$', '', str)
}

IsNumeric <- function(strings) {
    # check if string contains only digits
    suppressWarnings(!is.na(as.numeric(strings)))
}
    

ExtractYear <- function(line) {
    as.numeric(substring(line, 3))
}

ExtractMonth <- function(line) {
    as.numeric(substring(line, 4))
}

ExtractDay <- function(line) {
    as.numeric(substring(line, 5))
}

JustNumber <- function(line) {
    is.numeric <- IsNumeric(line)
    all(is.numeric) & length(line) == 1 
}

ExtractStart <- function(line) {
    as.numeric(line)
}

ExtractJobFinish <- function(line) {
    verbose <- FALSE
    if (FALSE) {
        cat('ExtractJobFinish\n')
        str(line)
    }
    pieces <- strsplit(Trim(line), ' ', fixed = TRUE)[[1]]
    first <- NA
    last <- NA
    for (piece in pieces) {
        if (piece != '') {
            if (is.na(first))
                first <- piece
            else
                last <- piece
        }
    }
    list(job = first,
         finish = as.numeric(last))
}

AppendRecord <- function(df, year, month, day, job, start, finish) {
    # return data.frame with one record appended
    new.row <- data.frame(year = year,
                          month = month,
                          day = day,
                          job = job,
                          start = start,
                          finish = finish)
    rbind(df, new.row)
}

MakeDataframe <- function(lines) {
    # convert list of input lines to dataframe with these columns
    # year, month, day, job, start, finish
    #cat('starting MakeDataframe\n'); browser()
    verbose <- FALSE
    df <- data.frame(year = numeric(0),
                     month = numeric(0),
                     day = numeric(0),
                     job = character(0),
                     start = numeric(0),
                     finish = numeric(0),
                     stringsAsFactors = FALSE)
    year <- 0
    month <- 0
    day <- 0
    job <- ''
    start <- 0
    line.number <- 0
    for (line in lines) {
        line.number <- line.number + 1 
        if (verbose) cat('line', line, '\n')
        line <- Trim(line)
        if (substr(line, 1, 1) == '#') {
            # skip comment lines
        }
        else if (substr(line,1,2) == '* ') {
            year <- ExtractYear(line)
        }
        else if (substr(line, 1, 3) == '** ') {
            month <- ExtractMonth(line)
        }
        else if (substr(line, 1, 4) == '*** ') {
            day <- ExtractDay(line)
            stopifnot(day > 0 & day <= 31)
        }
        else if (JustNumber(line)) {
            start <- ExtractStart(line)
            #cat('start', start, '\n'); browser()
        }
        else {
            #cat('found job', year, month, day, start, '\n'); browser()
            results <- ExtractJobFinish(line)
            if (is.na(results$finish)) {
                cat('no finish time for line', line.number, line, '\n')
            } else {
                if (year > 0 & month > 0 & day > 0) {
                    df <- AppendRecord(df, year, month, day, results$job, start, results$finish)
                }
                start <- results$finish
            }

        }
    }
    df
}

MakeDate <- function(df) {
    # return Date vector
    s <- sprintf('%d-%d-%d', df$year, df$month, df$day)
    as.Date(s)
}

AsMinutesPastMidnight <- function(hour.minute) {
    hour <- floor(hour.minute / 100)
    minute <- hour.minute - 100 * hour
    minutes.past.midnight <- hour * 60 + minute
    minutes.past.midnight
}

stopifnot(590 == AsMinutesPastMidnight(950))

SumByJob <- function(df) {
    # return data.frame with columns: job, total.minutes
    TotalElapsedMinutes <- function(job) {
        #cat('starting TotalElapsedMinutes', job, '\n'); browser()
        elapsed.minutes <- df[df$job == job, 'elapsed.minutes']
        total.elapsed.minutes <- sum(elapsed.minutes)
        total.elapsed.minutes
    }
    
    unique.jobs <- unique(df$job)
    total.elapsed.minutes <- lapply(unique.jobs, TotalElapsedMinutes)
    result <- NULL
    i <- 0
    for (job in unique.jobs) {
        i <- i + 1
        next.row <- data.frame(job = job,
                           total.elapsed.minutes = total.elapsed.minutes[[i]])
        result <- rbind(result, next.row)
    }
    result
}


TimeByJob <- function(message, df, first.date, last.date, skipBreak = TRUE) {
    #cat('starting TimeByJob', message, first.date, last.date, '\n'); browser()
    if (FALSE && message == 'last 7 days') {
        cat('starting TimeByJob', message, first.date, last.date, '\n')
        browser()
    }
        
    selected.rows <- (first.date <= df$date) & (df$date <= last.date)
    if (sum(selected.rows) == 0) {
        cat('no work done from', first.date, 'through', last.date, '\n')
        return()
    }   

    selected <- df[selected.rows, ]
    sums <- SumByJob(selected)
    elapsed.days <- last.date - first.date + 1
    if (FALSE) {
        cat('sum for period', message, '\n')
        print(sums)
    }
    cat('average per day for period', message, '\n')
    per.day <- 
        data.frame(job = sums$job,
                   hours.per.day = (sums$total.elapsed.minutes / 60 / as.numeric(elapsed.days)))
    if (skipBreak) {
        per.day <- subset(per.day,
                          subset = job != 'break')
    }
    print(per.day)
    #cat('ending TimeByJob\n'); browser()
}

Main <- function(control) {
    lines <- readLines(control$path.input)
    df <- MakeDataframe(lines)
    if (FALSE) {
        str(df)
        print(summary(df))
    }

    #cat('inMain creating elapsed.minutes\n'); browser()
    df$date <- MakeDate(df)
    df$start.minute <- AsMinutesPastMidnight(df$start)
    df$finish.minute <- AsMinutesPastMidnight(df$finish)
    df$elapsed.minutes <- df$finish.minute - df$start.minute

    current.date <- Sys.Date()

    #cat('in Main creating reports\n'); browser()

    TimeByJob('today', df, current.date, current.date)
    TimeByJob('yesterday', df, current.date -1, current.date -1)
    TimeByJob('last 7 days', df, current.date - 7, current.date)
    TimeByJob('last 30 days', df, current.date - 29, current.date)

    #stop('review df; perform analysis')
}

Main(control)
