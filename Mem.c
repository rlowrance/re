// Mem.c
// production implementation of Mem.h
// NOTE: NOT FULLY IMPLEMENTED

#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include "mem.h"

////////////////////////////////////////////////////////////////////////////////
// Mem_alloc
////////////////////////////////////////////////////////////////////////////////

void *Mem_alloc(long nbytes,
                const char *fileName, int line)
{
  assert(nbytes > 0);
  void *p = malloc(nbytes);
  if (p == NULL) {
    if (fileName == NULL)
      fprintf("Mem_alloc: unable to allocate %d bytes", nbytes);
    else
      fprintf("Mem_alloc: unable to allocate %d bytes; function %s line %d\n", 
              nbytes, fileName, line);
  }
    
}
