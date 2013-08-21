// Atom.c
// implementation of Atom.h

#include <assert.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>

#include "Atom.h"

#define T Atom_T

#define NELEMS(x) ((sizeof (x)) / (sizeof ((x)[0])))

static unsigned long scatter[256];
static struct Atom_T *buckets[2048];

////////////////////////////////////////////////////////////////////////////////
// initScatter
////////////////////////////////////////////////////////////////////////////////

static void initScatter()
{
  for (unsigned i = 0; i < 256; i++) {
    // rand returns a non-negative int
    scatter[i] = rand();
  }
}

////////////////////////////////////////////////////////////////////////////////
// Atom_new
////////////////////////////////////////////////////////////////////////////////

T Atom_new(const char *str, size_t length)
{
  assert(str);
  assert(length > 0);
  
  static unsigned scatterInitialized = 0;
  if (!scatterInitialized) {
    initScatter();
    scatterInitialized = 1;
  }
 
  uint32_t h;
  int i;
  for (h = 0, i = 0; i < length; i++) {
    h = (h << 1) + scatter[(unsigned char) str[i]];
  }
  h &= NELEMS(buckets) - 1;

  // search for existing entry
  // if found, return it
  {
    struct Atom_T *p;
    for (p = buckets[h]; p; p = p->link) {
      if (length == p->length) {
        for (unsigned i = 0; i < length && p->str[i] == str[i];)
          i++;
        if (i == length)
          return p;  //found it, so return it
      }
    }
  }
                                                
  // allocate a new entry and return it
  size_t size = sizeof(T) + length;
  struct Atom_T *self = malloc(size);
  assert(self);
  self->length = length;
  memcpy(self->str, str, length);
  self->str[length + 1] = '\0';

  // insert on head of list
  self->link = buckets[h];
  buckets[h] = self;

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Atom_newFromInt64
////////////////////////////////////////////////////////////////////////////////

T Atom_newFromInt64(int64_t value)
{
  int64_t valueStack = value;
  return Atom_new((char *) &valueStack, sizeof value);
}


////////////////////////////////////////////////////////////////////////////////
// Atom_newFromString
////////////////////////////////////////////////////////////////////////////////

T Atom_newFromString(char * value)
{
  return Atom_new(value, strlen(value));
}

////////////////////////////////////////////////////////////////////////////////
// Atom_length
////////////////////////////////////////////////////////////////////////////////

size_t Atom_length(T self)
{
  assert(self);
  return self->length;
}

////////////////////////////////////////////////////////////////////////////////
// Atom_str
////////////////////////////////////////////////////////////////////////////////

char *Atom_str(T self)
{
  assert(self);
  return self->str;
}
