// Matrix.h

#ifndef MATRIX_H
#define MATRIX_H

typedef struct {
    int nRows;
    int nCols;
    double m[];  // first element; dynamically allocated
} Matrix;

extern Matrix* Matrix_alloc(int nRows, int nCols);
extern void    Matrix_free(Matrix* pMatrix);
extern void    Matrix_set(Matrix* pMatrix, int row, int col, double value);
extern double  Matrix_get(Matrix* pMatrix, int row, int col);

#endif
