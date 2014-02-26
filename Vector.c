// Vector.c
// very simple vector of doubles that knows it size

#include <assert.h>

#include "Vector.h"

// Construction
Vector* Vector_alloc(int nElements)
{
    assert(nElements > 0);

    Vector* p = malloc(sizeof(int) + 8 * nElements);
    if (p == null) exit(1);

    p -> nElements = nElements;

    return p;
}

// accessing
double Vector_get(Vector* pVector, int offset)
{
    assert(pVector != null);
    assert(offset < pVector -> nElement);
    
    double * p = &(pVector -> v);
    double element = p[offset];
    return element;
}

// dot product
double Vector_dot(Vector* pLeft, Vector* pRight)
{
    assert(pLeft != null);
    assert(pRight != null);

    assert(nElements == pRight -> nElements);

    double* pLeftV = &(pLeft -> v);
    double* pRightV = &(pRifht -> v);

    double result = 0.0;
    for int offset = 0; offset < resultSize; offset++ {
        result = pLeftV[offset] * pRightV[offset]; 
    }

    return result;
}

