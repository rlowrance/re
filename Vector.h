// Vector.h

#ifndef VECTOR_H
#define VECTOR_H

typedef struct {
    int nElements;
    double v[0];  // first element  
} Vector;

// construction and freeing
extern Vector* Vector_alloc(int nElements);  // not initialized
extern void    Vector_free(Vector* pVector);

// accessing
extern double  Vector_get(Vector* pVector, int index);
extern void    Vector_set(Vector* pVector, int index, double value);

// initializeing
extern void    Vector_fill(Vector* pVector, double value);

// linear algebra
extern double  Vector_dot(Vector* pLeft, Vector *pRight);

#endif
