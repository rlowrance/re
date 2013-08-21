// SetDouble.c
// implementation of ADT SetDouble

// NOTE: re-implement using Hash.h

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>

#include "SetDouble.h"

#define T SetDouble_T
#define T_ITERATOR SetDoubleIterator_T


////////////////////////////////////////////////////////////////////////////////
// fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) 
{
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// hash
////////////////////////////////////////////////////////////////////////////////

uint32_t hash(double value)
{
  assert(sizeof(double) == 2 * sizeof(uint32_t));
  union u {
    double uValue; 

    uint32_t word[2];
  };
  union u valueUnion;
  valueUnion.uValue = value;
  return valueUnion.word[0] ^ valueUnion.word[1]; // xor
}


////////////////////////////////////////////////////////////////////////////////
// SetDouble_new
////////////////////////////////////////////////////////////////////////////////

T SetDouble_new(uint32_t initSize) 
{
  T self = malloc(sizeof(struct T));
  if (!self) fail("SetDouble_new: unable to allocate memory");

  self->elementsP = malloc(sizeof(double) * initSize);
  self->elementFilledP = malloc(sizeof(char) * initSize);
  self->nElements = initSize;
  self->nInserted = 0;

  // initially no elements are filled
  for (unsigned i = 0; i < initSize; i++) {
    self->elementFilledP[i] = 0;
  }

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// SetDouble_free
////////////////////////////////////////////////////////////////////////////////

void SetDouble_free(T *selfP)
{
  assert(selfP);
  assert(*selfP);

  T self = *selfP;
  free(self->elementsP);
  free(self);

  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// SetDouble_insert
////////////////////////////////////////////////////////////////////////////////

T SetDouble_insert(T self, double value) 
{
  assert(self);

  if (self->nInserted >= self->nElements) {
    // realloc the elements
    fail("write the reallocate code");
  }

  unsigned index = hash(value);
  while (self->elementFilledP[index] == 1) {
    index++;
    if (index == self->nElements)
      index = 0;
  }

  self->elementsP[index] = value;
  self->elementFilledP[index] = 1;

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// SetDouble_contains
////////////////////////////////////////////////////////////////////////////////

unsigned SetDouble_contains(T self, double value)
{
  assert(self);

  unsigned index = hash(value);
  while (self->elementFilledP[index] == 1) {
    if (self->elementsP[index] == value)
      return 1;
    index++;
    if (index == self->nElements)
      index = 0;
  }
  return 0;
}

////////////////////////////////////////////////////////////////////////////////
// SetDoubleIterator_new
////////////////////////////////////////////////////////////////////////////////

T_ITERATOR SetDoubleIterator_new(T setDouble)
{
  assert(setDouble);

  T_ITERATOR self = malloc(sizeof(struct T_ITERATOR));
  if (!self) fail("SetDoubleIterator_new: unable to allocate memory");

  self->setDouble = setDouble;
  self->nextIndex = 0;

  return self;
}


////////////////////////////////////////////////////////////////////////////////
// SetDoubleIterator_next
////////////////////////////////////////////////////////////////////////////////

unsigned SetDoubleIterator_next(T_ITERATOR self, double *valueP)
{
  assert(self);

  while (self->setDouble->elementFilledP[self->nextIndex] == 0) {
    self->nextIndex++;
    if (self->nextIndex == self->setDouble->nElements)
      return 0;
  }
  
  *valueP = self->setDouble->elementsP[self->nextIndex];
  self->nextIndex++;
  return 1;
}

////////////////////////////////////////////////////////////////////////////////
// SetDoubleIterator_free
////////////////////////////////////////////////////////////////////////////////

void SetDoubleIterator_free(T_ITERATOR *selfP)
{
  assert(selfP);
  assert(*selfP);

  T_ITERATOR self = *selfP;
  free(self);

  *selfP = NULL;
}
