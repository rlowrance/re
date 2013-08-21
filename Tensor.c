// Tensor.c

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "Function.h"
#include "Storage.h"
#include "Tensor.h"

#define T Tensor_T

#define STORAGE_INDEX1(self, index0) \
  ((self)->offset + (self)->ss.d1.stride0 * (index0))

#define STORAGE_INDEX2(self, index0, index1) \
  ((self)->offset + \
   (self)->ss.d2.stride0 * (index0) + \
   (self)->ss.d2.stride1 * (index1))

////////////////////////////////////////////////////////////////////////////////
// fail
////////////////////////////////////////////////////////////////////////////////

static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_add
////////////////////////////////////////////////////////////////////////////////

void Tensor_add(T self, double x, T other)
{
  assert(self);
  assert(other);
  
  unsigned nDim = self->nDimensions;
  assert(nDim == 1 || nDim == 2);

  Tensor_T or = Tensor_ravel(other);
  if (nDim == 1) {
    const unsigned size0 = Tensor_size0(self);
    for (unsigned i = 0; i < size0; i++)
      Tensor_set1(self, i, Tensor_get1(self, i) + x * Tensor_get1(or, i));
    Tensor_free(&or);
  }
  else if (nDim == 2) {
    const unsigned size0 = Tensor_size0(self);
    const unsigned size1 = Tensor_size1(self);
    unsigned orIndex = 0;
    for (unsigned i = 0; i < size0; i++)
      for (unsigned j = 0; j < size1; j++) {
        Tensor_set2(self, i, j, 
                    Tensor_get2(self, i, j) + x * Tensor_get1(or, orIndex));
        orIndex++;
      }
    Tensor_free(&or);
  }
  else
    assert(0); // cannot happen
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_apply
////////////////////////////////////////////////////////////////////////////////

T Tensor_apply(T self, double function(double, void *uv), void *upValuesP)
{
  assert(self);
  assert(self->storageP);
  assert(function);
  assert(upValuesP);
  
  if (self->isEachStorage) {
    // every element of self->storageP is mutated, 
    // so just iterate on storage indices
    Storage_apply(self->storageP, function, upValuesP);
  }
  else {
    // mutate only selected items in storage
    assert(self->nDimensions ==1 || self->nDimensions == 2);
    if (self->nDimensions == 1) {
      // iterate over elements in 1D
      uint32_t size0 = self->ss.d1.size0;
      for (uint32_t i = 0; i < size0; i++) {
	uint32_t index = STORAGE_INDEX1(self, i);
	double newValue = function(Storage_get(self->storageP, index), 
				   upValuesP);
	Storage_set(self->storageP, index, newValue);
      }
    }
    else {
      // iterate over elements in 2D
      uint32_t size0 = self->ss.d2.size0;
      uint32_t size1 = self->ss.d2.size1;
      for (uint32_t i = 0; i < size0; i++) {
	for (uint32_t j = 0; j < size1; j++) {
	  uint32_t index = STORAGE_INDEX2(self, i, j);
	  double newValue = function(Storage_get(self->storageP, index),
				     upValuesP);
	  Storage_set(self->storageP, index, newValue);
	}
      }
    }
  }
  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_dot
////////////////////////////////////////////////////////////////////////////////

double Tensor_dot(T t1, T t2)
{
  const unsigned trace = 0;

  assert(t1);
  assert(t2);
  uint32_t n = Tensor_nElements(t1);
  assert(n == Tensor_nElements(t2));

  T t1Raveled = Tensor_ravel(t1);
  T t2Raveled = Tensor_ravel(t2);
  if (t1 == t2)
    assert(Tensor_storage(t1) == Tensor_storage(t2));
  if (trace)
    fprintf(stderr, "Tensor_dot: size t1Raveled %u size t2Raveled %u\n",
	    Tensor_size0(t1Raveled), Tensor_size0(t2Raveled));

  double result = 0;
  for (uint32_t i = 0; i < n; i++) {
    if (trace)
      fprintf(stderr, "Tensor_dot: i = %u\n", i);
    result += Tensor_get1(t1Raveled, i) * Tensor_get1(t2Raveled, i);
  }

  Tensor_free(&t1Raveled);
  Tensor_free(&t2Raveled);

  return result;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_nElements
////////////////////////////////////////////////////////////////////////////////

uint32_t Tensor_nElements(T self)
{
  assert(self);
  const uint32_t nDimensions = Tensor_nDimensions(self);
  assert(nDimensions == 1 || nDimensions == 2);

  if (nDimensions == 1)
    return Tensor_size0(self);

  return Tensor_size0(self) * Tensor_size1(self);
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_fill
////////////////////////////////////////////////////////////////////////////////

 
T Tensor_fill(T self, double value)
{
  assert(self);
  
  
  return Tensor_apply(self, Function_constant, &value);
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_free
////////////////////////////////////////////////////////////////////////////////

void Tensor_free(T *selfP)
{
  assert(selfP);
  assert(*selfP);

  T self = *selfP;

  Storage_decrement(self->storageP);

  assert(self->nDimensions == 1 || self->nDimensions == 2);
  // no need to free dn storages, since not allocated for nDimension in {1,2}

  free(*selfP);
  *selfP = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_get1
////////////////////////////////////////////////////////////////////////////////

double Tensor_get1(T self, uint32_t index0)
{
  const char trace = 0;
  assert(self);
  assert(self->nDimensions == 1);
  assert(index0 < self->ss.d1.size0);

  if (trace)
    fprintf(stderr, 
	    "Tensor_get1: STORAGE_INDEX1 %u\n", 
	    STORAGE_INDEX1(self, index0));
  return Storage_get(self->storageP,
		     STORAGE_INDEX1(self, index0));
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_get2
////////////////////////////////////////////////////////////////////////////////

double Tensor_get2(T self, uint32_t index0, uint32_t index1)
{
  assert(self);
  assert(self->nDimensions == 2);
  assert(index0 < self->ss.d2.size0);
  assert(index1 < self->ss.d2.size1);

  return Storage_get(self->storageP, 
		     STORAGE_INDEX2(self, index0, index1));
}


////////////////////////////////////////////////////////////////////////////////
// Tensor_isEachStorage
////////////////////////////////////////////////////////////////////////////////

uint8_t Tensor_isEachStorage(T self)
{
  assert(self);
  return self->isEachStorage;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_mul
////////////////////////////////////////////////////////////////////////////////

void Tensor_mul(T self, double x)
{
  assert(self);
  
  unsigned nDim = self->nDimensions;
  assert(nDim == 1 || nDim == 2);

  if (nDim == 1) {
    const unsigned size0 = Tensor_size0(self);
    for (unsigned i = 0; i < size0; i++)
      Tensor_set1(self, i, Tensor_get1(self, i) * x);
  }
  else if (nDim == 2) {
    const unsigned size0 = Tensor_size0(self);
    const unsigned size1 = Tensor_size1(self);
    for (unsigned i = 0; i < size0; i++)
      for (unsigned j = 0; j < size1; j++) {
        Tensor_set2(self, i, j, Tensor_get2(self, i, j) * x );
      }
  }
  else
    assert(0); // cannot happen
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_nDimensions
////////////////////////////////////////////////////////////////////////////////

uint8_t Tensor_nDimensions(T self)
{
  assert(self);
  return self->nDimensions;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_new1
////////////////////////////////////////////////////////////////////////////////

// new storage
T Tensor_new1(uint32_t size0)
{
  assert(size0 > 0);

  Storage_T storageP = Storage_new(size0);

  T self = malloc(sizeof(struct T));
  if (!self) fail("Tensor_new1: unable to allocate memory");

  self->nDimensions = 1;
  self->isEachStorage = 1;
  self->storageP = storageP;
  self->offset = 0;
  self->ss.d1.size0 = size0;
  self->ss.d1.stride0 = 1;

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_new1FromStorage
////////////////////////////////////////////////////////////////////////////////

T Tensor_new1FromStorage(Storage_T storage, 
			 uint32_t offset, 
			 uint32_t size0,
			 uint32_t stride0)
{
  assert(storage);
  uint32_t storageSize = Storage_size(storage);
  assert(offset < storageSize);
  assert(size0 <= storageSize);
  assert(stride0 > 0);
  assert(offset + (size0 - 1) * stride0 < storageSize);

  T self = malloc(sizeof(struct T));
  if (!self) fail("Tensor_new1fromStorage: unable to allocate memory");

  Storage_increment(storage);

  self->nDimensions = 1;
  self->isEachStorage = 0;
  self->storageP = storage;
  self->offset = offset;
  self->ss.d1.size0 = size0;
  self->ss.d1.stride0 = stride0;

  return self;
}



////////////////////////////////////////////////////////////////////////////////
// Tensor_new2
////////////////////////////////////////////////////////////////////////////////

// new storage
T Tensor_new2(uint32_t size0, uint32_t size1)
{
  assert(size0 > 0);
  assert(size1 > 0);

  Storage_T storageP = Storage_new(size0 * size1);

  T self = malloc(sizeof(struct T));
  if (!self) fail("Tensor_new2: unable to allocate memory");

  self->nDimensions = 2;
  self->isEachStorage = 1;
  self->storageP = storageP;
  self->offset = 0;
  self->ss.d2.size0 = size0;
  self->ss.d2.size1 = size1;
  self->ss.d2.stride0 = size1;
  self->ss.d2.stride1 = 1;

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_newDeepCopy
////////////////////////////////////////////////////////////////////////////////

T Tensor_newDeepCopy(T other)
{
  assert(other);
  
  uint8_t nDimensions = other->nDimensions;
  assert(nDimensions == 1 || nDimensions == 2);

  if (nDimensions == 1) {
    const unsigned size0 = other->ss.d1.size0;
    Tensor_T result = Tensor_new1(size0);
    for (unsigned i = 0; i < size0; i++) {
      Tensor_set1(result, 
                  i,
                  Tensor_get1(other, i));
    }
    return result;
  }
  else if (nDimensions == 2) {
    const unsigned size0 = other->ss.d2.size0;
    const unsigned size1 = other->ss.d2.size1;
    Tensor_T result = Tensor_new2(size0, size1);
    for (unsigned i = 0; i < size0; i++) {
      for (unsigned j = 0; j < size1; j++) {
        Tensor_set2(result,
                    i, j,
                    Tensor_get2(other, i, j));
      }
    }
    return result;
  }
  else
    assert(0); // cannot happen
  

}

////////////////////////////////////////////////////////////////////////////////
// Tensor_newLinSpace
////////////////////////////////////////////////////////////////////////////////

T Tensor_newLinSpace(double x1, double x2, uint32_t n)
{
  const char trace = 0;
  assert(n >= 2);

  Tensor_T self = Tensor_new1(n);
  assert(self);

  const double spacing = (x2 - x1) / (n - 1);
  if (trace)
    fprintf(stderr, "Tensor_newLinSpace: spacing %f\n", spacing);
  for (unsigned i = 0; i < n; i++) {
    double next = x1 + i * spacing;
    Tensor_set1(self, i, next);
  }

  return self;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_offset
////////////////////////////////////////////////////////////////////////////////

uint32_t Tensor_offset(T self)
{
  assert(self);
  return self->offset;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_print
////////////////////////////////////////////////////////////////////////////////

void Tensor_print(T self, FILE *file)
{
  assert(self);
  assert(file);

  fprintf(file, "Tensor@%p nDimensions %u isEachStorage %u offset %u",
          (void*) self, self->nDimensions, self->isEachStorage, self->offset);
  const unsigned nDimensions = self->nDimensions;

  if (nDimensions == 1)
    fprintf(file, " size0 %u stride0 %u\n", 
            self->ss.d1.size0, self->ss.d1.stride0);
  else
    fprintf(file, " size0 %u size1 %u stride0 %u stride1 %u\n",
            self->ss.d2.size0, self->ss.d2.size1, 
            self->ss.d2.stride0, self->ss.d2.stride1);
  
  // print the elements, not the storage
  Storage__print_header(self->storageP, file); // print storage header
  if (nDimensions == 1) {
    for (unsigned i = 0; i < 10 && i < self->ss.d1.size0; i++)
      fprintf(stderr, " [%u]=%f", i, Tensor_get1(self, i));
    if (self->ss.d1.size0 > 10)
      fprintf(stderr, " ...");
    fprintf(stderr, "\n");
  }
  else {
    for (unsigned row = 0; row < 10 && row < self->ss.d2.size0; row++) {
      for (unsigned col = 0; col < 10 && col < self->ss.d2.size1; col++) {
        fprintf(stderr, " [%u][%u]=%f", row, col, Tensor_get2(self, row, col));
      } 
      if (self->ss.d2.size0 > 10)
        fprintf(stderr, " ...");
      fprintf(stderr, "\n");
    }
    if (self->ss.d2.size1 > 10)
      fprintf(stderr, " ...");
  }

  fprintf(file, "\n");
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_ravel
////////////////////////////////////////////////////////////////////////////////

T Tensor_ravel(T self)
{
  assert(self);
  assert(Tensor_isEachStorage(self)); // for now, only handle this simple case

  uint8_t nDimensions = Tensor_nDimensions(self);
  assert(nDimensions == 1 || nDimensions == 2);

  if (nDimensions == 1) {
    T result = Tensor_new1FromStorage(Tensor_storage(self),
				      Tensor_offset(self),
				      Tensor_size0(self),
				      Tensor_stride0(self));
    return result;
  }

  // nDimensions == 2
  T result = Tensor_new1FromStorage(Tensor_storage(self),
				    Tensor_offset(self),
				    Tensor_size0(self) * Tensor_size1(self),
				    1); // stride == 1
  return result;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_select
////////////////////////////////////////////////////////////////////////////////

// reuse the storage
T Tensor_select(T self, uint8_t dim, uint32_t index)
{
  assert(self);
  const unsigned nDimensions = self->nDimensions;

  if (nDimensions == 1) {
    assert(dim == 0);
    assert(index == 0);
    return Tensor_new1FromStorage(Tensor_storage(self),
                                   Tensor_offset(self),
                                   Tensor_size0(self),
                                   Tensor_stride0(self));
  }
  else if (nDimensions == 2) {
    assert(dim == 0 || dim == 1);
    if (dim == 0) {
      return Tensor_new1FromStorage(Tensor_storage(self),
                                    Tensor_offset(self) + 
                                      index * Tensor_size1(self),
                                    Tensor_size1(self),
                                    Tensor_stride1(self));
    }
    else if (dim == 1) {
      return Tensor_new1FromStorage(Tensor_storage(self),
                                    Tensor_offset(self) + index,
                                    Tensor_size0(self),
                                    Tensor_size1(self));
    }
    else
      assert(NULL == "bad dim");
  }
  else
    assert(NULL == "bad nDimensions");
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_set1
////////////////////////////////////////////////////////////////////////////////

void Tensor_set1(T self, uint32_t index0, double value)
{
  assert(self);
  assert(self->nDimensions == 1);
  assert(index0 < self->ss.d1.size0);

  Storage_set(self->storageP, 
	      STORAGE_INDEX1(self, index0),
	      value);
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_set2
////////////////////////////////////////////////////////////////////////////////

void Tensor_set2(T self, uint32_t index0, uint32_t index1, double value)
{
  assert(self);
  assert(self->nDimensions == 2);
  assert(index0 < self->ss.d2.size0);
  assert(index1 < self->ss.d2.size1);

  Storage_set(self->storageP, 
	      STORAGE_INDEX2(self, index0, index1),
	      value);
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_size0
////////////////////////////////////////////////////////////////////////////////

uint32_t Tensor_size0(T self)
{
  assert(self);
  assert(self->nDimensions == 1 || self->nDimensions == 2);

  if (self->nDimensions == 1) 
    return self->ss.d1.size0;
  else
    return self->ss.d2.size0;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_size1
////////////////////////////////////////////////////////////////////////////////

uint32_t Tensor_size1(T self)
{
  assert(self);
  assert(self->nDimensions == 2);

  return self->ss.d2.size1;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_storage
////////////////////////////////////////////////////////////////////////////////

Storage_T Tensor_storage(T self)
{
  assert(self);
  return self->storageP;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_stride0
////////////////////////////////////////////////////////////////////////////////

uint32_t Tensor_stride0(T self)
{
  assert(self);
  assert(self->nDimensions == 1 || self->nDimensions == 2);

  if (self->nDimensions == 1) 
    return self->ss.d1.stride0;
  else
    return self->ss.d2.stride0;
}

////////////////////////////////////////////////////////////////////////////////
// Tensor_stride1
////////////////////////////////////////////////////////////////////////////////

uint32_t Tensor_stride1(T self)
{
  assert(self);
  assert(self->nDimensions == 2);

  return self->ss.d2.stride1;
}
