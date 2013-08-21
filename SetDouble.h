// SetDouble.h
// a set of double values


#ifndef SETDOUBLE_H
#define SETDOUBLE_H

#include <inttypes.h>

#define T SetDouble_T

typedef struct T *T;

struct SetDouble_T {
  double  *elementsP;
  char    *elementFilledP;
  uint32_t nElements;
  uint32_t nInserted;
};


// constructing and destructing
extern T     SetDouble_new(uint32_t initSize);
extern void  SetDouble_free(T *selfP);

// inserting and checking presence
extern T        SetDouble_insert(T self, double value);
// return 0 (key is not present) or 1 (key is present)
extern unsigned SetDouble_contains(T self, double key);

// iterating through the elements
#define T_ITERATOR SetDoubleIterator_T
typedef struct T_ITERATOR *T_ITERATOR;
struct SetDoubleIterator_T {
  T        setDouble;
  uint32_t nextIndex;
};

extern T_ITERATOR SetDoubleIterator_new(T self); // construct
// return 1 if a next element (in which case, set *valueP)
// return 0 if no next element
extern unsigned   SetDoubleIterator_next(T_ITERATOR iterator, double *valueP); 
extern void       SetDoubleIterator_free(T_ITERATOR *iteratorP);

#undef T
#endif
