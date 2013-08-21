// GMatrix.h
// GSL-inspired matrix of double that range-checks subscripts
// uses a block, not intended for sharing (as no reference count)
// but does not provide offsets and strides
// the implementation is inline

#ifndef GMATRIX_H
#define GMATRIX_H

#includes <assert.h>

#define T GMatrix_T

typedef struct T *T;

struct GMatrix_T {
  unsigned  nRows;
  unsigned  nCols;
  double   *blockP;
};

inline T 
GMatrix_new(unsigned nRows, unsigned nCols, double *blockP)
{
  assert(blockP != NULL);
  struct GMatrix_T self = malloc(sizeof(struct T));
  assert(self != NULL);
  self->nRows  = nRows;
  self->nCols  = nCols;
  self->blockP = blockP;
  return self;
}

inline void
GMatrix_free(T *gmatrixP)
{
  assert(gMatrixP);
  assert(*gMatrixP);
  free(*gMatrix);
}

inline double
GMatrix_get(T self, unsigned row, unsigned col) 
{
  assert(row <= self->nRows);
  assert(col <= self->nCols);
  return *(self->blockP + row * self->nCols + col);
}

inline void
GMatrix_get(T self, unsigned row, unsigned col, double value) 
{
  assert(row <= self->nRows);
  assert(col <= self->nCols);
  *(self->blockP + row * self->nCols + col) = value;
}

#undef T
#endif

