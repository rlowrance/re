// Tensor.h

#ifndef TENSOR_H
#define TENSOR_H

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "Storage.h"

#define T Tensor_T

typedef struct T *T;

struct Tensor_T {
  uint8_t   nDimensions;
  uint8_t   isEachStorage;  // every element is used; hence also contiguous
  Storage_T storageP;
  uint32_t  offset;         // if isEachStorage, then offset == 0
  union  {  // sizes and strides
    struct {uint32_t size0; uint32_t stride0;} d1;
    struct {uint32_t size0; uint32_t size1; 
               uint32_t stride0; uint32_t stride1;} d2;
    struct {Storage_T *sizesP; Storage_T *stridesP;} dn;
  } ss;
};

// allocation and freeingo
/*extern T  Tensor_new(Storage_T  storageP, 
		     uint32_t   offset, 
		     unsigned   nDimensions,
		     Storage_T *sizesP,
		     Storage_T *stridesP); */
extern T   Tensor_new1(uint32_t size0);  // new Storage with isEachStorage == 1

// reuse storage; hence increment storage's usage count
extern T   Tensor_new1FromStorage(Storage_T  storage,
				  uint32_t   offset,
				  uint32_t   size0,
				  uint32_t   stride0);

extern T   Tensor_new2(uint32_t size0, uint32_t size1); // isEachStorage == 1
/*
extern T   Tensor_new2FromStorage(Storage_T *storageP,
				  uint32_t   offset,
				  uint32_t   size0,
				  uint32_t   size1,
				  uint32_t   stride0,
				  uint32_t   stride1); */

// create a completely independent object with same values and new storage
extern T   Tensor_newDeepCopy(T existing);  // share storage, sizes, strides

extern T   Tensor_newContinguous(T existing); // share nothing, make continguous

// return 1D tensor with n elements equally spaced from x1 to x2
extern T   Tensor_newLinSpace(double x1, double x2, uint32_t n);

extern void Tensor_free(T *storageP);


// access components
extern Storage_T Tensor_storage(T self);
extern uint8_t   Tensor_isEachStorage(T self);
extern uint8_t   Tensor_nDimensions(T self);
extern uint32_t  Tensor_offset(T self);
extern uint32_t  Tensor_size0(T self);  // for 1D or 2D
extern uint32_t  Tensor_size1(T self);  // for only 2D
extern uint32_t  Tensor_stride0(T self); // for 1D or 2D
extern uint32_t  Tensor_stride1(T self); // for only 2D

extern uint32_t  Tensor_nElements(T self);
// getters and setters
/*
  extern double Tensor_get(T tensor, uint32_t index, ...); */
extern double Tensor_get1(T self, uint32_t index0);
extern double Tensor_get2(T self, uint32_t index0, uint32_t index1);

// extern void   Tensor_set(T tensor, uint32_t index, ...); // ... value 
extern void   Tensor_set1(T self, uint32_t index, double value);
extern void   Tensor_set2(T self, 
			  uint32_t index0, uint32_t index1, double value);

// resize
extern T     Tensor_resize_as(T self, T other);

extern T     Tensor_resize(T self, Storage_T *sizes);

// extract sub-tensors
extern T     Tensor_narrow(T        self,
                           uint8_t  dim,
                           uint32_t index,
                           uint32_t size);

// return view of same storage
extern T     Tensor_select(T        self,
                           uint8_t  dim,
                           uint32_t index);

// manipulate tensor view
extern T     Tensor_transpose(T       self,
                              uint8_t dim1,
                              uint8_t dim2);

extern T     Tensor_unfold(T        self,
                           uint8_t  dim,
                           uint32_t size,
                           uint32_t step);
extern T     Tensor_ravel(T self); // return 1D view of same storage

// mutate; return mutated self
extern T Tensor_fill(T self, double value);
extern T Tensor_zero(T self);
extern T Tensor_apply(T      self,
		      double function(double, void *uv),
		      void  *upValues);
extern T Tensor_map(T       self,
		    T       other,
		    double  function(double, double, void *uv),
		    void   *upValues);
extern T Tensor_map2(T self,
		     T other1,
		     T other2,
		     double function(double, double, double, void*),
		     void *upValues);

// basic operations on Tensors

// number elements must be equal, but shapes can be different
extern double Tensor_dot(T t1, T t2);

extern void Tensor_print(T self, FILE *file);

// math operations on Tensors

// self := self + x * other
// nElements must agree
// sizes may differ
extern void Tensor_add(T self, double x, T other);

// self := self * x
extern void Tensor_mul(T self, double x);

#undef T
#endif 
