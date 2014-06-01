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
    cat('ExtractJobFinish\n')
    str(line)
    pieces <- strsplit(Trim(line), ' ', fixed = TRUE)[[1]]
    list(job = pieces[1],
         finish = as.numeric(pieces[2]))
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
    for (line in lines) {
        cat('line', line, '\n')
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
        }
        else if (JustNumber(line)) {
            start <- ExtractStart(line)
            #cat('start', start, '\n'); browser()
        }
        else {
            #cat('found job', year, month, day, start, '\n'); browser()
            results <- ExtractJobFinish(line)
            df <- AppendRecord(df, year, month, day, results$job, start, results$finish)
            start <- results$finish
        }
    }
    df
}

Main <- function(control) {
    lines <- readLines(control$path.input)
    df <- MakeDataframe(lines)
    str(df)
    print(summary(df))
    stop('review df; perform analysis')
}

Main(control)
