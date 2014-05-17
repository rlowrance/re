# StartJIT.R
StartJIT <- function(start.JIT) {
    # turn on the JIT compiler
    # ARGS: None
    # RETURNS: NULL

    require("compiler")
    enableJIT(3)     # 3 ==> maximum JIT level
}
