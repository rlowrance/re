// Function.c

#include <assert.h>
#include <stddef.h>

#include "Function.h"

double Function_constant(double value, void *doubleConstantP)
{
  assert(doubleConstantP);
  double *constantP = doubleConstantP;
  return *constantP;
}

double Function_zero(double value, void *nullP)
{
  assert(nullP == NULL);
  return 0.0;
}
