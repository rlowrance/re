// SGD.h
// stochastic gradient descent
// ref: https://github.com/koraykv/optim/blob/master/sgd.lua

#ifndef SGD_H
#define SGD_H

#include <stdio.h>

#include "Tensor.h"

#define T SGD_T

typedef struct T *T;

struct SGD_T {
  // construction parameters
  void (*f)(Tensor_T x, void *upValues, double *resultP, Tensor_T *dfdxP);
  void *upValues;

  double learningRate;
  double learningRateDecay;
  double weightDecay;
  double momentum;
  // other state variables
  unsigned evalCounter;
  double   lastFx;
  Tensor_T dfdx;
};

// allocating and freeing
extern T SGD_new(void f(Tensor_T  x,
                        void     *upValues,
                        double   *resultP,
                        Tensor_T *dfdxP),
                 void   *upValues,
                 double  learningRate,
                 double  learnigRateDecay,
                 double  weightDecay,
                 double  momentum);

extern void SGD_free(T *sgdP);

// iterate by taking one step from *xP, updating *xP and setting *fx)
extern void SGD_iterate(T self, Tensor_T *xP, double *fxP);

extern void SGD_print(T self, FILE *file);

#undef T
#endif
