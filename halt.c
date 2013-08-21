// halt.c

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "halt.h"

// print error message and halt with exit(2)
void
halt(char *format, ...) {
  va_list argptr;
  va_start(argptr, format);  // set argptr to first optional argument
  vfprintf(stderr, format, argptr);
  exit(1);
}
