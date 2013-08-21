// Str.h
// ADT to safely store C objects within char * strings

#ifndef STR_H
#define STR_H

#include <inttypes.h>

#define T Str_T
typedef struct T *T;

struct Str_T {
  char *valueTypeName;
  union value {
    int16_t  valueInt16;
    char     c;
  } value;
  char zero;
};

// constructors
extern T Str_newFromInt16(int16_t value);

// destructor
extern void Str_free(T *selfP);

// return char *
extern char *Str_str(T self);

// accessors: return the value after type-checking it
extern int16_t Str_valueInt16(T self);

#undef T

#endif


