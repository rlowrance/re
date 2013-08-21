// Tensor-test.c

#include <stdio.h>

#include "Tensor.h"
#include "UnitTest.h"

//////////////////////////////////////// testAdd

// nElements must agree
static void testAdd()
{
  // add to self
  Tensor_T d1A = Tensor_newLinSpace(1, 6, 6);
  Tensor_add(d1A, 2, d1A);
  for (unsigned i = 0; i < 6; i++) {
    EXPECT_EQ_DOUBLE((i + 1) * 3, Tensor_get1(d1A, i), 0);
  }

  // add to another
  Tensor_T d1B = Tensor_newLinSpace(1, 3, 3);
  Tensor_T d1C = Tensor_newLinSpace(4, 6, 3);
  Tensor_add(d1B, 3, d1C);
  EXPECT_EQ_DOUBLE(1 + 3 * 4, Tensor_get1(d1B, 0), 0);
  EXPECT_EQ_DOUBLE(2 + 3 * 5, Tensor_get1(d1B, 1), 0);
  EXPECT_EQ_DOUBLE(3 + 3 * 6, Tensor_get1(d1B, 2), 0);

  // different shapes
  Tensor_T d1D = Tensor_newLinSpace(1, 6, 6);
  Tensor_T d2 = Tensor_new2(2, 3);
  double count = 0;
  for (unsigned i = 0; i < 2; i++)
    for (unsigned j = 0; j < 3; j++) {
      count++;
      Tensor_set2(d2, i, j, count);
    }
  Tensor_add(d2, 2, d1D);
  EXPECT_EQ_DOUBLE(3, Tensor_get2(d2, 0, 0), 0);
  EXPECT_EQ_DOUBLE(6, Tensor_get2(d2, 0, 1), 0);
  EXPECT_EQ_DOUBLE(9, Tensor_get2(d2, 0, 2), 0);
  EXPECT_EQ_DOUBLE(12, Tensor_get2(d2, 1, 0), 0);
  EXPECT_EQ_DOUBLE(15, Tensor_get2(d2, 1, 1), 0);
  EXPECT_EQ_DOUBLE(18, Tensor_get2(d2, 1, 2), 0);
}

//////////////////////////////////////// testDot

static void testDot()
{
  const unsigned trace = 1;

  Tensor_T d1Size1 = Tensor_new1(1);
  Tensor_fill(d1Size1, 2);

  Tensor_T d1Size6 = Tensor_new1(6);
  Tensor_fill(d1Size6, 2);

  Tensor_T d2Size1 = Tensor_new2(1, 1);
  Tensor_fill(d2Size1, 3);

  Tensor_T d2Size6 = Tensor_new2(2, 3);
  Tensor_fill(d2Size6, 3);

  Tensor_T d2Size6t = Tensor_new2(3, 2);
  Tensor_fill(d2Size6t, 4);

  // 1d . 1d size 1
  EXPECT_EQ_DOUBLE(4, Tensor_dot(d1Size1, d1Size1), 0);

  // 1d . 1d size 6
  EXPECT_EQ_DOUBLE(24, Tensor_dot(d1Size6, d1Size6), 0);

  // 2d . 2d size 1
  EXPECT_EQ_DOUBLE(9, Tensor_dot(d2Size1, d2Size1), 0);

  // 2d . 2d size 6
  if (trace)
    fprintf(stderr, "testDot: sizes d2Size6 %u %u\n", 
	    Tensor_size0(d2Size6), Tensor_size1(d2Size6));
  EXPECT_EQ_DOUBLE(54, Tensor_dot(d2Size6, d2Size6), 0);
  EXPECT_EQ_DOUBLE(72, Tensor_dot(d2Size6, d2Size6t), 0);

  // 1d . 2d size 1
  EXPECT_EQ_DOUBLE(6, Tensor_dot(d1Size1, d2Size1), 0);

  // 2d . 1d size 1
  EXPECT_EQ_DOUBLE(6, Tensor_dot(d2Size1, d1Size1), 0);

  // 1d . 2d size 6
  EXPECT_EQ_DOUBLE(36, Tensor_dot(d1Size6, d2Size6), 0);

  // 2d . 1d size 6
  EXPECT_EQ_DOUBLE(36, Tensor_dot(d2Size6, d1Size6), 0);
}

//////////////////////////////////////// testFill

static void testFill() {
  // case 1d isEachStorage
  Tensor_T t1 = Tensor_new1(4);
  EXPECT_EQ_UNSIGNED(1, Tensor_isEachStorage(t1));
  Tensor_fill(t1, 27.0);
  for (unsigned i = 0; i < 3; i++)
    EXPECT_EQ_DOUBLE(27, Tensor_get1(t1, i), 0);

  // case 1d not isEachStorage
  Tensor_T t1Not = Tensor_new1FromStorage(Tensor_storage(t1), 1, 2, 2);
  EXPECT_EQ_UNSIGNED(0, Tensor_isEachStorage(t1Not));
  Tensor_fill(t1Not, 101.0);
  EXPECT_EQ_DOUBLE(101.0, Tensor_get1(t1Not, 0), 0);
  EXPECT_EQ_DOUBLE(101.0, Tensor_get1(t1Not, 1), 0);

  Tensor_T t2 = Tensor_new2(2, 3);
  Tensor_fill(t2, 27.0);
  for (unsigned i = 0; i < 2; i++)
    for (unsigned j = 0; j < 3; j++)
      EXPECT_EQ_DOUBLE(27.0, Tensor_get2(t2, i, j), 0.0);

  // TODO: If implement Tensor_new2FromStorage, test fill on 2D not isEachStorage
}

//////////////////////////////////////// testFree

static void testFree()
{
  Tensor_T t1 = Tensor_new1(3);
  Tensor_free(&t1);
  EXPECT_NULL(t1);

  Tensor_T t2 = Tensor_new2(2, 3);
  Tensor_free(&t2);
  EXPECT_NULL(t2);
}

//////////////////////////////////////// testGetSet

static void testGetSet()
{
  Tensor_T t1 = Tensor_new1(3);
  Tensor_set1(t1, 0, 10.0);
  Tensor_set1(t1, 1, 11.0);
  Tensor_set1(t1, 2, 12.0);
  EXPECT_EQ_DOUBLE(10.0, Tensor_get1(t1, 0), 0);
  EXPECT_EQ_DOUBLE(11.0, Tensor_get1(t1, 1), 0);
  EXPECT_EQ_DOUBLE(12.0, Tensor_get1(t1, 2), 0);

  Tensor_T t2 = Tensor_new2(2, 3);
  Tensor_set2(t2, 0, 0, 10.0);
  Tensor_set2(t2, 0, 1, 11.0);
  Tensor_set2(t2, 0, 2, 12.0);
  Tensor_set2(t2, 1, 0, 20.0);
  Tensor_set2(t2, 1, 1, 21.0);
  Tensor_set2(t2, 1, 2, 22.0);
  EXPECT_EQ_DOUBLE(10.0, Tensor_get2(t2, 0, 0), 0);
  EXPECT_EQ_DOUBLE(11.0, Tensor_get2(t2, 0, 1), 0);
  EXPECT_EQ_DOUBLE(12.0, Tensor_get2(t2, 0, 2), 0);
  EXPECT_EQ_DOUBLE(20.0, Tensor_get2(t2, 1, 0), 0);
  EXPECT_EQ_DOUBLE(21.0, Tensor_get2(t2, 1, 1), 0);
  EXPECT_EQ_DOUBLE(22.0, Tensor_get2(t2, 1, 2), 0);
}

//////////////////////////////////////// testMul

static void testMul()
{
  // 1d
  Tensor_T d1 = Tensor_newLinSpace(1, 6, 6);
  Tensor_mul(d1, 2);
  for (unsigned i = 0; i < 6; i++) {
    EXPECT_EQ_DOUBLE((i + 1) * 2, Tensor_get1(d1, i), 0);
  }

  // 2d
  Tensor_T d2 = Tensor_new2(2, 3);
  double count = 0;
  for (unsigned i = 0; i < 2; i++)
    for (unsigned j = 0; j < 3; j++) {
      count++;
      Tensor_set2(d2, i, j, count);
    }
  Tensor_mul(d2, 3);
  EXPECT_EQ_DOUBLE(3, Tensor_get2(d2, 0, 0), 0);
  EXPECT_EQ_DOUBLE(6, Tensor_get2(d2, 0, 1), 0);
  EXPECT_EQ_DOUBLE(9, Tensor_get2(d2, 0, 2), 0);
  EXPECT_EQ_DOUBLE(12, Tensor_get2(d2, 1, 0), 0);
  EXPECT_EQ_DOUBLE(15, Tensor_get2(d2, 1, 1), 0);
  EXPECT_EQ_DOUBLE(18, Tensor_get2(d2, 1, 2), 0);
}

//////////////////////////////////////// testNElements

static void
testNElements()
{
  Tensor_T t1 = Tensor_new1(6);
  EXPECT_EQ_UINT32(6, Tensor_nElements(t1));
  Tensor_free(&t1);

  Tensor_T t2 = Tensor_new2(2, 3);
  EXPECT_EQ_UINT32(6, Tensor_nElements(t2));
  Tensor_free(&t2);
}

//////////////////////////////////////// testNew 

static void
testNew()
{
  // new1
  Tensor_T t1 = Tensor_new1(4);
  EXPECT_EQ_UINT8(1, Tensor_isEachStorage(t1));
  EXPECT_EQ_UINT32(1, Tensor_nDimensions(t1));
  EXPECT_EQ_UINT32(4, Tensor_size0(t1));
  EXPECT_EQ_UINT32(1, Tensor_stride0(t1));

  // new1FromStorage
  Storage_T s1 = Tensor_storage(t1);
  Tensor_T t1Shared = Tensor_new1FromStorage(s1, 1, 2, 2);
  EXPECT_EQ_UINT8(0, Tensor_isEachStorage(t1Shared));
  EXPECT_EQ_UINT32(1, Tensor_nDimensions(t1Shared));
  EXPECT_EQ_UINT32(2, Tensor_size0(t1Shared));
  EXPECT_EQ_UINT32(2, Tensor_stride0(t1Shared));

  //  check that mutating t1 also changes certain parts of t1Shared
  for (uint32_t i = 0; i < 4; i++) {
    Tensor_set1(t1, i, i * 1.0);
    EXPECT_EQ_DOUBLE(i * 1.0, Tensor_get1(t1, i), 0);
  }
  EXPECT_EQ_DOUBLE(1.0, Tensor_get1(t1, 1), 0);
  EXPECT_EQ_DOUBLE(1.0, Tensor_get1(t1Shared, 0), 0);
  EXPECT_EQ_DOUBLE(3.0, Tensor_get1(t1, 3), 0);
  EXPECT_EQ_DOUBLE(3.0, Tensor_get1(t1Shared, 1), 0);
  
  // check that mutating t1Shared also changes certain parts of t1
  Tensor_set1(t1Shared, 0, 27.0);
  Tensor_set1(t1Shared, 1, 71.0);
  EXPECT_EQ_DOUBLE(0.0, Tensor_get1(t1, 0), 0);
  EXPECT_EQ_DOUBLE(27.0, Tensor_get1(t1, 1), 0);
  EXPECT_EQ_DOUBLE(2.0, Tensor_get1(t1, 2), 0);
  EXPECT_EQ_DOUBLE(71.0, Tensor_get1(t1, 3), 0);

  Tensor_T t2 = Tensor_new2(2, 3);
  EXPECT_EQ_UINT8(1, Tensor_isEachStorage(t2));
  EXPECT_EQ_UINT32(2, Tensor_nDimensions(t2));
  EXPECT_EQ_UINT32(2, Tensor_size0(t2));
  EXPECT_EQ_UINT32(3, Tensor_size1(t2));
  EXPECT_EQ_UINT32(3, Tensor_stride0(t2));
  EXPECT_EQ_UINT32(1, Tensor_stride1(t2));
}

//////////////////////////////////////// testNewDeepCopy

void testNewDeepCopy()
{
  Tensor_T t = Tensor_new1(1);
  Tensor_fill(t, 27.0);

  Tensor_T s = Tensor_newDeepCopy(t);
  // same values but shares nothing
  EXPECT_EQ_DOUBLE(Tensor_get1(t, 0), Tensor_get1(s, 0), 0);
  EXPECT_EQ_UNSIGNED(Tensor_nDimensions(t), Tensor_nDimensions(s));
  EXPECT_EQ_UINT32(Tensor_offset(t), Tensor_offset(s));
  EXPECT_EQ_UINT32(Tensor_size0(t), Tensor_size0(s));

  EXPECT_NE_POINTER(Tensor_storage(t), Tensor_storage(s));
}
//////////////////////////////////////// testNewLinSpace

void testNewLinSpace()
{
  Tensor_T t = Tensor_newLinSpace(1.0, 10.0, 10); // 10 points 1, 2, ... 10
  for (unsigned i = 0; i < 10; i++) {
    EXPECT_EQ_DOUBLE(i + 1, Tensor_get1(t, i), 0);
  }

  // 3 points
  t = Tensor_newLinSpace(1.0, 10.0, 3);
  EXPECT_EQ_DOUBLE(1.0, Tensor_get1(t, 0), 0);
  EXPECT_EQ_DOUBLE(5.5, Tensor_get1(t, 1), 0);
  EXPECT_EQ_DOUBLE(10.0, Tensor_get1(t, 2), 0);

  // 2 points
  t = Tensor_newLinSpace(1.0, 10.0, 2);
  EXPECT_EQ_DOUBLE(1.0, Tensor_get1(t, 0), 0);
  EXPECT_EQ_DOUBLE(10.0, Tensor_get1(t, 1), 0);  


}

//////////////////////////////////////// testOffset

void testOffset()
{
  Storage_T s = Storage_new(6);
  Tensor_T t1 = Tensor_new1FromStorage(s, 2, 1, 1);
  EXPECT_EQ_UNSIGNED(2, Tensor_offset(t1));

  Tensor_T t2 = Tensor_new2(2, 3);
  EXPECT_EQ_UNSIGNED(0, Tensor_offset(t2));
}

//////////////////////////////////////// testPrint

void testPrint()
{
  const unsigned verbose = 0;
  FILE *file;
  if (verbose)
    file = stderr;
  else {
    file = fopen("/dev/null", "w");  // DOES NOT WORK
    if (file == NULL)
      perror("Unable to open /dev/null"), assert(0);
  }
  Tensor_T d1 = Tensor_newLinSpace(1.0, 10.0, 10);
  fprintf(file, "expect 1d 1, 2, ..., 10\n");
  Tensor_print(d1, file);

  Tensor_T d1shared = Tensor_new1FromStorage(Tensor_storage(d1),
                                             1,
                                             2,
                                             4);
  fprintf(file, "expect 1d 2 6 with storage shared with first Tensor\n");
  Tensor_print(d1shared, file);

  Tensor_T d2 = Tensor_new2(2, 3);
  unsigned count = 0;
  for (unsigned row = 0; row < 2; row++)
    for (unsigned col = 0; col < 3; col++) {
      count++;
      Tensor_set2(d2, row, col, count);
    }
  fprintf(file, " expect 2 x 3 with 1, 2, ..., 6");
  Tensor_print(d2, file);

  Tensor_free(&d1);
  Tensor_free(&d1shared);
  Tensor_free(&d2);
}

//////////////////////////////////////// testRavel

void testRavel()
{
  // ravel 1d
  Tensor_T t1 = Tensor_new1(6);
  Storage_T s1 = Tensor_storage(t1);
  Tensor_fill(t1, 27.0);

  Tensor_T t1Ravel = Tensor_ravel(t1);
  // must share storage
  EXPECT_EQ_POINTER(Tensor_storage(t1), Tensor_storage(t1Ravel));
  EXPECT_EQ_UNSIGNED(1, Tensor_nDimensions(t1Ravel));
  EXPECT_EQ_UNSIGNED(6, Tensor_size0(t1Ravel));
  EXPECT_EQ_UNSIGNED(6, Tensor_nElements(t1Ravel));
  
  for (unsigned i = 0; i < 6; i++)
    EXPECT_EQ_DOUBLE(27.0, Tensor_get1(t1Ravel, i), 0);

  Tensor_free(&t1Ravel);
  EXPECT_NULL(t1Ravel);
  EXPECT_NOT_NULL(t1);
  EXPECT_EQ_POINTER(s1, Tensor_storage(t1));
  
  // ravel 2d
  Tensor_T t2 = Tensor_new2(2, 3);
  Storage_T s2 = Tensor_storage(t2);
  Tensor_fill(t2, 101.0);

  Tensor_T t2Ravel = Tensor_ravel(t2);
  // must share storage
  EXPECT_EQ_POINTER(Tensor_storage(t2), Tensor_storage(t2Ravel));
  EXPECT_EQ_UNSIGNED(1, Tensor_nDimensions(t2Ravel));
  EXPECT_EQ_UNSIGNED(6, Tensor_size0(t2Ravel));
  EXPECT_EQ_UNSIGNED(6, Tensor_nElements(t2Ravel));
  
  for (unsigned i = 0; i < 6; i++)
    EXPECT_EQ_DOUBLE(101.0, Tensor_get1(t2Ravel, i), 0);

  Tensor_free(&t2Ravel);
  EXPECT_NULL(t2Ravel);
  EXPECT_NOT_NULL(t2);
  EXPECT_EQ_POINTER(s2, Tensor_storage(t2));

  // bug: after ravel, things have changed
  Tensor_T t = Tensor_newLinSpace(1.0, 6.0, 6);
  for (unsigned i = 0; i < 6; i++)
    EXPECT_EQ_DOUBLE(1 + i, Tensor_get1(t, i), 0);

  Tensor_T r = Tensor_ravel(t);
  for (unsigned i = 0; i < 6; i++)
    EXPECT_EQ_DOUBLE(1 + i, Tensor_get1(r, i), 0);


}

//////////////////////////////////////// testSelect

void testSelect()
{
  const unsigned trace = 1;
  // 1d
  {
    Tensor_T t = Tensor_newLinSpace(1, 3, 3);
    Tensor_T s = Tensor_select(t, 0, 0);
    EXPECT_EQ_POINTER(Tensor_storage(t), Tensor_storage(s));
    EXPECT_EQ_UNSIGNED(1, Tensor_nDimensions(s));
    EXPECT_EQ_UNSIGNED(3, Tensor_size0(s));
    EXPECT_EQ_DOUBLE(1.0, Tensor_get1(s, 0), 0);
    EXPECT_EQ_DOUBLE(2.0, Tensor_get1(s, 1), 0);
    EXPECT_EQ_DOUBLE(3.0, Tensor_get1(s, 2), 0);

    // test freeing
    Tensor_free(&s);
    EXPECT_NULL(s);
    EXPECT_NOT_NULL(Tensor_storage(t));

    Tensor_free(&t);
    EXPECT_NULL(t);
  }
  // 2d: example from torch documentation (augmented)
  {
    Tensor_T x = Tensor_new2(5,6);
    Tensor_fill(x, 0);
    
    Tensor_T y = Tensor_select(x, 0, 1);
    Tensor_fill(y, 2);
    if (trace) {
      fprintf(stderr, "y");
      Tensor_print(y, stderr);
      fprintf(stderr, "x after setting y");
      Tensor_print(x, stderr);
    }
    Tensor_T y2 = Tensor_select(x, 0, 4);
    Tensor_fill(y2, 3);
    if (trace) {
      fprintf(stderr, "x after setting y2");
      Tensor_print(x, stderr);
    }

    EXPECT_EQ_POINTER(Tensor_storage(x), Tensor_storage(y));
    EXPECT_EQ_UNSIGNED(3, Storage_nReferences(Tensor_storage(x)));
    for (unsigned i = 0; i < 5; i++) {
      for (unsigned j = 0; j < 6; j++) {
        EXPECT_EQ_DOUBLE(i == 1 ? 2.0 : (i == 4 ? 3 : 0), 
                         Tensor_get2(x, i, j), 
                         0);
        EXPECT_EQ_DOUBLE(2.0, Tensor_get1(y, j), 0);
        EXPECT_EQ_DOUBLE(3.0, Tensor_get1(y2, j), 0);
      }
    }

    Tensor_T z = Tensor_select(x, 1, 3);
    Tensor_fill(z, 5);
    EXPECT_EQ_POINTER(Tensor_storage(x), Tensor_storage(z));
    EXPECT_EQ_UNSIGNED(4, Storage_nReferences(Tensor_storage(x)));
    if (trace) {
      fprintf(stderr, "x after setting z");
      Tensor_print(x, stderr);
    }
    for (unsigned i = 0; i < 5; i++) {
      EXPECT_EQ_DOUBLE(5.0, Tensor_get1(z, i), 0);
      for (unsigned j = 0; j < 6; j++) {
        const double value = Tensor_get2(x, i, j);
        if (i == 1) {
          if (j == 3)
            EXPECT_EQ_DOUBLE(5, value, 0);
          else
            EXPECT_EQ_DOUBLE(2, value, 0);
        }
        else if (i == 4) {
          if (j == 3)
            EXPECT_EQ_DOUBLE(5, value, 0);
          else
            EXPECT_EQ_DOUBLE(3, value, 0);
        }
        else {
          if (j == 3)
            EXPECT_EQ_DOUBLE(5, value, 0);
          else
            EXPECT_EQ_DOUBLE(0, value, 0);
        }
      }
    }


    // test freeing
    Tensor_free(&z);
    EXPECT_NULL(z);
    EXPECT_NOT_NULL(Tensor_storage(x));

    Tensor_free(&x);
    EXPECT_NULL(x);

    Tensor_free(&y);
    EXPECT_NULL(y);

    Tensor_free(&y2);
    EXPECT_NULL(y2);

  }
}
//////////////////////////////////////// testTensorStorage

void testTensorStorage()
{
  Tensor_T t2 = Tensor_new2(2, 3);
  Storage_T s = Tensor_storage(t2);
  EXPECT_NOT_NULL(s);
  EXPECT_EQ_UNSIGNED(6, Storage_size(s));
  EXPECT_EQ_UNSIGNED(1, Storage_nReferences(s));
}

//////////////////////////////////////// main

int
main(int argc, char **argv)
{
  testAdd();
  testDot();
  testFill();
  testFree();
  testGetSet();
  testMul();
  testNElements();
  testNew();
  testNewDeepCopy();
  testNewLinSpace();
  testOffset();
  testPrint();
  testRavel();
  testSelect();
  testTensorStorage();
  
  UnitTest_report();
}

