# Printf.R
Printf <- function(..., file = '') {
    cat(sprintf(...), file = file)
}
