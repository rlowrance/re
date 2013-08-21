// Hash.c
// implementation of Hash.h ADT

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Atom.h"
#include "Hash.h"

#define T Hash_T
#define T_ITERATOR HashIterator_T

////////////////////////////////////////////////////////////////////////////////
// fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) 
{
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// allocateKeysP
////////////////////////////////////////////////////////////////////////////////

static Atom_T *allocateKeysP(uint32_t size)
{
  Atom_T *result = malloc(sizeof(char *) * size);
  if (!result)
    fail("Hash_new: unable to allocate valuesP");
  for (unsigned i = 0; i < size; i++) {
    result[i] = NULL;
  }
  return result;
}

////////////////////////////////////////////////////////////////////////////////
// allocateValuesP
////////////////////////////////////////////////////////////////////////////////

static char **allocateValuesP(uint32_t size)
{
  char **result = malloc(sizeof(char *) * size);
  if (!result)
    fail("Hash_new: unable to allocate valuesP");
  for (unsigned i = 0; i < size; i++) {
    result[i] = NULL;
  }
  return result;
}



#if 0
////////////////////////////////////////////////////////////////////////////////
// doubleCompare
////////////////////////////////////////////////////////////////////////////////

static int doubleCompare(void *d1PVoid, void *d2PVoid)
{
  assert(d1PVoid);
  assert(d2PVoid);

  double v1 = (* (double *) d1PVoid);
  double v2 = (* (double *) d2PVoid);
  
  if (v1 < v2)
    return -1;
  else if (v1 > v2)
    return 1;
  else
    return 0;
}

////////////////////////////////////////////////////////////////////////////////
// hashCharP
////////////////////////////////////////////////////////////////////////////////

// Source: weiss, p. 188

static uint32_t hashCharP(void *keyPVoid, uint32_t tableSize)
{
  assert(tableSize > 0);
  int result = 0;
  
  char *keyP = (char *) keyPVoid;
  for (int i = 0; keyP[i] != '\0'; i++) {
    result = 37 * result + keyP[i];
  }

  result %= tableSize;
  if (result < 0)
    result += tableSize;

  return result;
}

////////////////////////////////////////////////////////////////////////////////
// hashDouble
////////////////////////////////////////////////////////////////////////////////

static uint32_t hashDouble(void *doublePVoid, uint32_t tableSize)
{
  assert(doublePVoid);

  assert(sizeof(double) == 2 * sizeof(uint32_t));
  union u {
    double uValue; 
    uint32_t word[2];
  };
  union u valueUnion;
  valueUnion.uValue = (* (double *) doublePVoid);
  return valueUnion.word[0] ^ valueUnion.word[1]; // xor

}

////////////////////////////////////////////////////////////////////////////////
// mystrcmp
////////////////////////////////////////////////////////////////////////////////

// like strcmp, but with void * args instead of char * args
static int mystrcmp(void *s1, void *s2) 
{
  assert(s1);
  assert(s2);
  return strcmp((char *) s1, (char *) s2);
}

#endif

////////////////////////////////////////////////////////////////////////////////
// Hash_free
////////////////////////////////////////////////////////////////////////////////

void Hash_free(T *selfP)
{
  assert(selfP);
  assert(*selfP);

  T self = *selfP;

  free(self->keysP); // don't try to free the key pointers, they are Atoms

  // free the values
  for (unsigned i = 0; i < self->tableSize; i++) {
    free(self->valuesP[i]);
  }
  free(self->valuesP);

  free(self);

  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// Hash_insert
////////////////////////////////////////////////////////////////////////////////

T Hash_insert(T self, Atom_T key, char *value)
{
  assert(self);
  assert(key);
  assert(value);

  if (self->nElements == self->tableSize) {
    // table is full 
    // reallocate the keysP and valuesP arrays and copy current elements to them
    uint32_t newSize = self->tableSize * 2 + 1;

    Atom_T *oldKeysP = self->keysP;
    self->keysP = allocateKeysP(newSize);
    
    char **oldValuesP = self->valuesP;
    self->valuesP = allocateValuesP(newSize);

    uint32_t oldSize = self->tableSize;
    self->tableSize = newSize;

    self->nElements = 0;

    // re-insert old keys and values
    for (unsigned index = 0; index < oldSize; index++) {
      if (oldKeysP[index] != NULL) {
        Hash_insert(self, oldKeysP[index], oldValuesP[index]);
      }
    }

    free(oldKeysP);
    free(oldValuesP);
  }

  // take advantage of the hashing already done to each Atom
  // each has a unique address
  assert(sizeof(Atom_T) == sizeof(int64_t));
  union {
    Atom_T  keyAddr;
    int64_t keyInt;
  } temp;

  temp.keyAddr = key;
  int64_t index = temp.keyInt % self->tableSize;
  if (index < 0)
    index += self->tableSize;

  // use open hashing, so find next free entry starting at index
  while (self->keysP[index] != NULL) {
    index++;
    if (index >= self->tableSize)
      index = 0;
  }

  // insert key
  self->keysP[index] = key;

  // copy and insert value
  char * valueCopy = malloc(strlen(value));
  if (!valueCopy)
    fail("Hash_insert: unable to allocate copy of value");
  strcpy(valueCopy, value);
  self->valuesP[index] = valueCopy;

  self->nElements++;

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Hash_new
////////////////////////////////////////////////////////////////////////////////

T Hash_new(uint32_t initTableSizeHint)
{
  T self = malloc(sizeof(struct T));
  if (!self)
    fail("Hash_new: unable to allocate self");

  // initialize keysP and valuesP
  self->keysP = allocateKeysP(initTableSizeHint);
  self->valuesP = allocateValuesP(initTableSizeHint);
  
  // initialize other instance variables
  self->tableSize = initTableSizeHint;
  self->nElements = 0;

  return self;
}

