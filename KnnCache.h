// KnnCache.h
// I/O-free cache: unsigned key -> unsigned array of neighbor indices

#ifndef KNNCACHE_H
#define KNNCACHE_H

#define T KnnCache_T
typedef struct T *T;

// for now, an array indexed by the queryIndex
struct KnnCache_T {
  unsigned  size;
  unsigned **neighborsP; // neighbors[size]
};

extern T         KnnCache_new(unsigned sizeHint);
extern void      KnnCache_free(T *knncacheP);

// return address of previously set values[nNeighbors]
// return NULL if not present
extern unsigned* KnnCache_get(T knnCache, 
                              const unsigned key);

// set cache key queryIndex to values[nNeighbors]
// raise exception if already set
// queryIndex in [0,sizeHint - 1]
extern void      KnnCache_set(T knnCache, 
                              const unsigned key,
                              const unsigned nNeighbors, 
                              const unsigned values[nNeighbors]);


#undef T
#endif
