// MSECriterion.h

#ifndef MSECRITERION_H
#define MSECRITERION_H

#include "Tensor.h"

#define T MSECriterion_T

typedef struct T *T;

struct MSECriterion_T {
  char dummy;  // must have a member to avoid a warning
};

extern T MSECriterion_new();
extern void MSECriterion_free(T *selfP);

// return scalar: (1/n) sum_i (input_i - target_i)^2
extern double MSECriterion_forward(T self, Tensor_T input, Tensor_T target);

// return gradient wrt input
// return Tensor_i = (1/n) * 2 * (input_i - target_i) * input_i
extern Tensor_T MSECriterion_backward(T self, Tensor_T input, Tensor_T target);

#if 0
// these two methods in torch7 are not provided here
// because they make a copy of the previous provided values
// leading to a need to free these copies at the right time

// perhaps the method names should be
//  MSECriterion_newOutput
//  MSECriterion_newGradInput
extern Tensor_T MSECriterion_output(T self); // last result from forward
extern Tensor_T MSECriterion_gradInput(T self); // last result from backward
#endif

#undef T
#endif
