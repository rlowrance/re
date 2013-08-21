// KnnCache.c
// implementation of KnnCache.h
// stores the cached values in an array sized to hold every possible key

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include "KnnCache.h"

#define T KnnCache_T

////////////////////////////////////////////////////////////////////////////////
// static functions
////////////////////////////////////////////////////////////////////////////////

/*
static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}
*/

////////////////////////////////////////////////////////////////////////////////
// KnnCache_new
////////////////////////////////////////////////////////////////////////////////

// return pointer to struct KnnCache_T that can hold size entries
T KnnCache_new(unsigned size) {
  static int debug = 0;
  T knnCache = malloc(sizeof(struct T));
  assert(knnCache);

  // initialize field size
  knnCache->size = size;
  
  // initialize field neighborsP
  unsigned** vectorP = malloc(sizeof(unsigned *) * size);
  assert(vectorP);
  knnCache->neighborsP = vectorP;
  if (debug) printf("KnnCache_new: knnCache=%p\n", (void*)knnCache);
  if (debug) printf("KnnCache_new: knnCache->neighborsP=%p\n", 
                    (void*)knnCache->neighborsP);

  for (unsigned i = 0; i < size; i++) {
    vectorP[i] = NULL;
    if (debug) printf("knnCache_new: vectorP[%u]=%p\n", i, (void*)vectorP[i]);
  }

  return knnCache;
}

////////////////////////////////////////////////////////////////////////////////
// KnnCache_free
////////////////////////////////////////////////////////////////////////////////

// free the memory
void KnnCache_free(T *knnCacheP) {
  assert(knnCacheP);
  assert(*knnCacheP);

  T knnCache = *knnCacheP;

  // free any vectors of unsigned's
  unsigned **vectorP = knnCache->neighborsP;
  for (unsigned i = 0; i < knnCache->size; i++) {
    free(vectorP[i]);
  }

  free(vectorP);

  free(knnCache);

  // set argument to NULL
  *knnCacheP = NULL;
}


////////////////////////////////////////////////////////////////////////////////
// KnnCache_get
////////////////////////////////////////////////////////////////////////////////

// retrieve a value using key queryIndex
unsigned *KnnCache_get(T knnCache, 
                       const unsigned queryIndex) {
  const int debug = 0;
  assert(knnCache);
  assert(queryIndex < knnCache->size);
  if (debug) printf("queryIndex=%u\n", queryIndex);
  
  unsigned *result = knnCache->neighborsP[queryIndex];
  return result;
}

////////////////////////////////////////////////////////////////////////////////
// KnnCache_set
////////////////////////////////////////////////////////////////////////////////

// cache[key] = copy of values
void KnnCache_set(T knnCache, 
                  const unsigned key, 
                  const unsigned valuesSize, 
                  const unsigned values[valuesSize]) {
  const int debug = 0;
  const unsigned debugKey = 262712;
  if (debug && key == debugKey) printf("set values[0]=%u\n", values[0]);
  if (debug && key == debugKey) printf("set knnCache=%p\n", (void*)knnCache);
  assert(knnCache);
  assert(valuesSize > 0);
  assert(key < knnCache->size);

  unsigned *memP = malloc(sizeof(unsigned) * valuesSize);
  assert(memP);
  for (unsigned i = 0; i < valuesSize; i++) {
    if (debug) printf("values[%u]=%u\n", i, values[i]);
    memP[i] = values[i];
  }

  knnCache->neighborsP[key] = memP;
}
