// Hash.h
// an unordered_map in C++'s terminology

// This implementation follows 
// Weiss, Data Structures and Algorithm Analysis in C++, 3rd edition
// It uses open addressing with linear programming

// possible implementation is
// http://uthash.sourceforge.net/userguide.html

#ifndef HASH_H
#define HASH_H

#include <inttypes.h>

#include "Atom.h"

#define T Hash_T
typedef struct T *T;

struct Hash_T {
  Atom_T   *keysP;
  char    **valuesP;
  uint32_t  tableSize;
  uint32_t  nElements;
};

// General case: key is Atom_T; value is char *
extern T Hash_new(uint32_t initTableSizeHint);

extern void Hash_free(T *selfP);

// replace any current value
// return mutated self
extern T     Hash_insert(T self, Atom_T key, char *value);

// return pointer to value or NULL if key is not present
extern char *Hash_find(T self, Atom_T *key);

// iterating through the elements
#define T_ITERATOR Hash_Iterator_T
typedef struct T_ITERATOR *T_ITERATOR;
struct Hash_Iterator_T {
  T        hash;
  uint32_t nextIndex;
};
extern T_ITERATOR HashIterator_new(T self);
extern void       HashIterator_free(T_ITERATOR *selfP);
// return 1 if a next element, in which case set *valueP to point to the value
// return 0 if no next element, in which case set *valueP to NULL
extern unsigned   HashIterator_next(T_ITERATOR   iterator, 
                                    Atom_T     **keyP, 
                                    char       **valueP);

#undef T_ITERATOR
#undef T

#endif
