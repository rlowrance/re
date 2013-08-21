// Linear.c

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "Linear.h"
#include "Random.h"
#include "Tensor.h"

#define T Linear_T

////////////////////////////////////////////////////////////////////////////////
// static fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// static reset
////////////////////////////////////////////////////////////////////////////////

// follow the initialization in Linear.lua exactly
static void reset(T self, double *stdvP)
{
  double std = stdvP 
    ? (*stdvP) * sqrt(3.0) 
    : (1.0 / sqrt(Tensor_size1(self->weight)));
       
  // set each weight and bias to Uniform(-std,+std)
  for (uint32_t i = 0; i < Tensor_size0(self->weight); i++)
    for (uint32_t j = 0; j < Tensor_size1(self->weight); j++) {
      double uWeight = Random_uniform(-std, std);
      Tensor_set2(self->weight, i, j, uWeight);
      double uBias = Random_uniform(-std, std);
      Tensor_set1(self->bias, i, uBias);
  }
}

////////////////////////////////////////////////////////////////////////////////
// Linear_new
////////////////////////////////////////////////////////////////////////////////

// return pointer to struct Log_T
T Linear_new(uint32_t inputSize, uint32_t outputSize) {
  assert(inputSize > 0);
  assert(outputSize > 0); 

  // allocate self
  T self = malloc(sizeof(struct T));
  if (!self) fail("Linear:new: unable to allocate memory");

  self->inputSize = inputSize;
  self->outputSize = outputSize;
  self->weight = Tensor_new2(outputSize, inputSize);
  self->bias = Tensor_new1(outputSize);
  self->gradWeight = Tensor_new2(outputSize, inputSize);
  self->gradBias = Tensor_new1(outputSize);

  reset(self, NULL);

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Linear_forward
////////////////////////////////////////////////////////////////////////////////

Tensor_T Linear_forward(T self, Tensor_T input)
{
  assert(self);

  const unsigned nDimensions = Tensor_nDimensions(input);
  assert(nDimensions== self->outputSize);

  if (nDimensions == 1) {
    double value = Tensor_get1(self->bias, 0) + Tensor_dot(self->weight, input);
    Tensor_T result = Tensor_new1(1); // 1D result
    Tensor_set1(result, 0, value);
    return result;
  }
  else if (nDimensions == 2) {
    unsigned size = Tensor_size1(input);
    Tensor_T result = Tensor_new2(size, 1);
    for (unsigned row = 0; row < size; row++) {
      double value = 
        Tensor_get1(self->bias, row) + 
        Tensor_dot(Tensor_select(self->weight, 0, row), input);
      Tensor_set1(result, row, value);
    }
    return result;
  }
  else
    assert(0); // cannot happen
}


////////////////////////////////////////////////////////////////////////////////
// Linear_free
////////////////////////////////////////////////////////////////////////////////

void Linear_free(T *selfP) {
  assert(selfP);
  assert(*selfP);

  // free the component tensors
  T self = *selfP;
  Tensor_free(&self->weight);
  Tensor_free(&self->bias);
  Tensor_free(&self->gradWeight);
  Tensor_free(&self->gradBias);

  // free self
  free(*selfP);

  // set argument to NULL pointer
  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// Linear print
////////////////////////////////////////////////////////////////////////////////

static void printTensor1(FILE* file, Tensor_T t, char *msg)
{
  fprintf(file,
         "      : %s = [",
         msg);
  for (unsigned i = 0; i < Tensor_size0(t) && i < 7; i++)
    fprintf(file, " %f", Tensor_get1(t, i));
  fprintf(file, "]\n");
}

static void printTensor2(FILE* file, Tensor_T t, char *msg)
{
  fprintf(file,
         "      : %s =\n",
         msg);
  for (unsigned i = 0; i < Tensor_size0(t) && i < 7; i++) {
    fprintf(file, "       [");
    for (unsigned j = 0; j < Tensor_size1(t) &&  j < 7; j++) {
      fprintf(file, "%f ", Tensor_get2(t, i, j));
    }
    fprintf(file, "]\n");
  }
}

void Linear_print(T self, FILE *file)
{
  assert(self);
  fprintf(file,
          "Linear: outputSize %u inputSize %u\n",
          self->outputSize, self->inputSize);
  printTensor1(file, self->bias, "bias");
  printTensor2(file, self->weight, "weight");
  printTensor1(file, self->gradBias, "gradBias");
  printTensor2(file, self->gradWeight, "gradWeight");
}

