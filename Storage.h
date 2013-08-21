// Storage.h

#ifndef STORAGE_H
#define STORAGE_H

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define T Storage_T

typedef struct T *T;

struct Storage_T {
  uint32_t  size;
  uint32_t  nReferences;
  double   *arrayP;
};

// allocation and freeing
extern T    Storage_new(uint32_t size);
//extern T    Storage_newFromFile(char * filePath, char *mode);
extern T    Storage_newCopy(T existing);  // deep copy, share nothing 

extern void Storage_free(T *selfP); // free; requires nReferences == 1

// maintain reference counts
extern void  Storage_increment(T self);
extern void  Storage_decrement(T self); // free if no longer referenced

// access components
extern uint32_t  Storage_size(T self);
extern uint32_t  Storage_nReferences(T self);
extern double   *Storage_arrayP(T self);

// mutate; returned mutated self
extern T Storage_apply(T self, double f(double, void *uv), void *uv);
extern T Storage_fill(T self, double value); // return self
extern T Storage_resize(T self, unsigned newSize); // preserve existing values

// getters and setters for elements in the array
inline static double Storage_get(T self, uint32_t index) 
{
  assert(self);
  assert(index < self->size);
  return self->arrayP[index];
}

inline static void Storage_set(T self, uint32_t index, double value) 
{
  assert(self);
  assert(index < self->size);
  self->arrayP[index] = value;
}

extern void Storage_print(T self, FILE *file);
extern void Storage__print_header(T self, FILE *file); // protected

#undef T
#endif
