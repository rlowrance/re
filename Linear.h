// Linear.h

#ifndef LINEAR_H
#define LINEAR_H

#include "Tensor.h"

#define T Linear_T

typedef struct T *T;

struct Linear_T {
  uint32_t outputSize;
  uint32_t inputSize;
  Tensor_T bias;
  Tensor_T weight;
  Tensor_T gradBias;
  Tensor_T gradWeight;
};

extern T Linear_new(uint32_t outputSize, uint32_t inputSize);

extern void Linear_free(T *selfP);

// return output Tensor
extern Tensor_T Linear_forward(T self, Tensor_T input);

// return gradInput
extern Tensor_T Linear_backward(T self, Tensor_T gradOutput);

// print to FILE
extern void Linear_print(T self, FILE *file);

#undef T
#endif
