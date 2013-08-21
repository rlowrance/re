# SetJITLevel.R

SetJITLevel <- function(jit.level) {
  # set the JIT (just-in-time) level for the R compiler
  # Args:
  # jit.level: scalar number passed to enableJIT, with these meaning:
  #   0 -- no JIT
  #   1 -- compile closures before first use
  #   2 -- compile closures before they are duplicated
  #   3 -- compile loops before they are executed
  #
  # Returns: NULL

  require("compiler")
  enableJIT(jit.level)

  NULL
}
