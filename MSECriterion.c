// MSECriterion.c

#include <assert.h>
#include <stdio.h>

#include "MSECriterion.h"
#include "Tensor.h"

#define T MSECriterion_T

////////////////////////////////////////////////////////////////////////////////
// static fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}


////////////////////////////////////////////////////////////////////////////////
// MSECriterion_new
////////////////////////////////////////////////////////////////////////////////

T MSECriterion_new()
{
  T self = malloc(sizeof(struct T));
  if (!self) fail("MSECriterion_new: unable to allocate memory");

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// MSECriterion_backward
////////////////////////////////////////////////////////////////////////////////

// return gradient wrt input
// return Tensor_i = (1/n) * 2 * (input_i - target_i) * input_i
Tensor_T MSECriterion_backward(T self, Tensor_T input, Tensor_T target)
{
  assert(self);
  assert(input);
  assert(target);

  const unsigned n = Tensor_nElements(input);
  assert(n == Tensor_nElements(target));

  Tensor_T inputRaveled = Tensor_ravel(input);
  Tensor_T targetRaveled = Tensor_ravel(target);

  Tensor_T result = Tensor_new1(n);
  const double overN = 1.0 / n;
  for (unsigned i = 0;  i < n; i++) {
    const double inputElement = Tensor_get1(inputRaveled, i);
    const double targetElement = Tensor_get1(targetRaveled, i);
    const double element = 
      overN * 2.0 * (inputElement - targetElement) * inputElement;
    Tensor_set1(result, i, element);
  }

  Tensor_free(&inputRaveled);
  Tensor_free(&targetRaveled);

  return result;
}

////////////////////////////////////////////////////////////////////////////////
// MSECriterion_forward
////////////////////////////////////////////////////////////////////////////////

// return scalar: (1/n) sum_i (input_i - target_i)^2
double MSECriterion_forward(T self, Tensor_T input, Tensor_T target)
{
  const unsigned trace = 0;

  assert(self);
  assert(input);
  assert(target);

  const unsigned n = Tensor_nElements(input);
  if (trace)
    fprintf(stderr, "MSECriterion_forward: n %u\n", n);
  assert(n == Tensor_nElements(target));

  // compute sum of squared differences in elements
  Tensor_T inputRaveled = Tensor_ravel(input);
  Tensor_T targetRaveled = Tensor_ravel(target);
  double sumSquaredDifferences = 0;
  for (unsigned i = 0;  i < n; i++) {
    const double diff = 
      Tensor_get1(inputRaveled, i) - Tensor_get1(targetRaveled, i);
    if (trace)
      fprintf(stderr, "MSECriterion_forward: x %f y %f diff %f\n", 
              Tensor_get1(inputRaveled, i), 
              Tensor_get1(targetRaveled, i), 
              diff);
    sumSquaredDifferences += diff * diff;
  }

  const double result = sumSquaredDifferences / n;

  Tensor_free(&inputRaveled);
  Tensor_free(&targetRaveled);

  return result;
}
////////////////////////////////////////////////////////////////////////////////
// MSECriterion_free
////////////////////////////////////////////////////////////////////////////////

void MSECriterion_free(T *selfP)
{
  assert(selfP);
  assert(*selfP);

  // free components (there are none)

  // free self
  free(*selfP);
  
  // set argument pointer to NULL
  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// MSECriterion_output
////////////////////////////////////////////////////////////////////////////////

#if 0
// not implemented because it would return a copy
// and then deciding when to free it would be a problem
Tensor_T MSECriterion_output(T self)
{
  assert(self);
  assert(self->output);

  return self->output;
}
#endif
