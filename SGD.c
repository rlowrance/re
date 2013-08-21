// SGD.c

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>

#include "SGD.h"
#include "Tensor.h"

#define T SGD_T

////////////////////////////////////////////////////////////////////////////////
// fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// SGD_free
////////////////////////////////////////////////////////////////////////////////

void SGD_free(T *selfP)
{
  assert(selfP);
  assert(*selfP);

  // free components
  T self = *selfP;
  if (self->dfdx != NULL)
    Tensor_free(&self->dfdx);

  // free self
  free(*selfP);
  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// SGD_fx
////////////////////////////////////////////////////////////////////////////////

double SGD_lastFx(T self)
{
  assert(self);
  assert(self->lastFx);

  return self->lastFx;
}

////////////////////////////////////////////////////////////////////////////////
// SGD_iterate
////////////////////////////////////////////////////////////////////////////////

// return next x
void SGD_iterate(T self, Tensor_T *xP, double *fxP)
{
  const unsigned trace = 0;
  const char *me = "SGD_iterate";
  assert(self);
  assert(xP);

  // determine f(x) and df/dx
  double   fx   = 0;
  Tensor_T dfdx = NULL;
  self->f(*xP, self->upValues, &fx, &dfdx);
  *fxP = fx;
  if (trace) {
    fprintf(stderr, "%s: x=", me); Tensor_print(*xP, stderr);
    fprintf(stderr, "%s: fx=%f\n", me, fx);
    fprintf(stderr, "%s: dfdx=", me); Tensor_print(dfdx, stderr);
  }

  // apply momentum
  // dfdx = momentum * dfdx_previous + (1 - momentum) * dfdx_new
  if (self->momentum != 0) {
    if (self->dfdx == NULL) {
      self->dfdx = Tensor_newDeepCopy(dfdx);
    }
    else {
      Tensor_mul(self->dfdx, self->momentum); // mutate self->dfdx
      Tensor_add(self->dfdx, 1 - self->momentum, dfdx); // mutate self->dfdx
    }
  }
  if (trace) {
    fprintf(stderr, "%s: momentum dfdx=", me); Tensor_print(self->dfdx, stderr);
  }
    

  // apply weight decay
  if (self->weightDecay != 0) {
    Tensor_add(*xP, -self->weightDecay * self->learningRate, *xP);
  }
  if (trace) {
    fprintf(stderr, "%s: weight decay x=", me); Tensor_print(*xP, stderr);
  }

  // apply learning rate decay (annealing)
  const double currentLearningRate = 
    self->learningRate / (1 + self->evalCounter * self->learningRateDecay);

  // update parameters with single learning rate
  // NOTE: ref version allows multiple learning rates
  if (trace) {
    fprintf(stderr, "%s:\n", me);
    fprintf(stderr, " x="); Tensor_print(*xP, stderr);
    fprintf(stderr, 
            " currentLearningRate %f\n", 
            currentLearningRate);
  }
  Tensor_add(*xP, - currentLearningRate, dfdx);

  self->evalCounter++;

  self->lastFx = fx;
  Tensor_free(&dfdx);
}

////////////////////////////////////////////////////////////////////////////////
// SGD_new
////////////////////////////////////////////////////////////////////////////////

T SGD_new(void f(Tensor_T  x,
                 void     *upValues,
                 double   *resultP,
                 Tensor_T *dfdxP),
          void   *upValues,
          double  learningRate,
          double  learningRateDecay,
          double  weightDecay,
          double  momentum)
{
  assert(f);
  assert(learningRate > 0);
  assert(learningRateDecay >= 0);
  assert(weightDecay >= 0);
  assert(momentum >= 0);
  
  T self = malloc(sizeof(struct T));
  if (!self) fail("SGD_new: unable to allocate memory");

  self->f = f;
  self->upValues = upValues;
  self->learningRate = learningRate;
  self->learningRateDecay = learningRateDecay;
  self->weightDecay = weightDecay;
  self->momentum = momentum;

  self->evalCounter = 0;
  self->lastFx = 0;
  self->dfdx = NULL;

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// SGD_print
////////////////////////////////////////////////////////////////////////////////

void SGD_print(T self, FILE *file)
{
  assert(self);
  assert(file);

  fprintf(file, 
          "SGD@%p f@%p upValues@%p\n"
          "  learningRate %f learningRateDecay %f\n"
          "  weightDecay %f momentum %f\n"
          "  evalCount %u lastFx %f\n"
          "  dfdx@%p=",
          (void *) self,
          (void *) (size_t) self->f,
          self->upValues,
          self->learningRate,
          self->learningRateDecay,
          self->weightDecay,
          self->momentum,
          self->evalCounter,
          self->lastFx,
          (void *) self->dfdx);
  if (self->dfdx)
    Tensor_print(self->dfdx, file);
  fprintf(file, "\n");
}
