// Matrix.h

#ifndef MATRIX_H
#define MATRIX_H

typedef struct T *T;

struct Matrix_T {
  unsigned nRows;
  unsigned nCols;
  double element[nRows][nCols];
};

extern T Matrix_new(unsigned nRows, unsigned nCols);
extern void Matrix_free(T *matrixP);

extern double Matrix_get(T matrix, unsigned row, unsigned col);
extern void Matrix_set(T matrix, unsigned row, unsigned col, double value);

extern void Matrix_apply(T matrix, double f(double));
extern void Matrix_map(T self, 
                       T other, double f(double, double));
extern void Matrix_map2(Tself, 
                        T other1, T other2, double f(double, double, double));

extern unsigned Matrix_nRows(T matrix);
extern unsigned Matrix_nCols(T matrix);

extern T Matrix_narrow(T matrix, unsigned dim, unsigned index, unsigned size);
extern T Matrix_select(T matrix, unsigned dim, unsigned index);
extern T Matrix_transpose(T matrix);

#undef T
#endif
