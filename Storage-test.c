// Storage-test.c
// unit test Storage.c

#include "UnitTest.h"

#include "Storage.h"

////////////////////////////////////////////////////////////////////////////////
// testApply
////////////////////////////////////////////////////////////////////////////////

static double doubleAddConstant(double value, void *constantP)
{
  assert(constantP);
  double *c = constantP;
  return 2 * value + *c;
}

static void
testApply()
{
  Storage_T s3 = Storage_new(3);
  Storage_set(s3, 0, 10);
  Storage_set(s3, 1, 20);
  Storage_set(s3, 2, 30);
  double constant = 1;
  Storage_apply(s3, doubleAddConstant, &constant);
  EXPECT_EQ_DOUBLE(21, Storage_get(s3, 0), 0);
  EXPECT_EQ_DOUBLE(41, Storage_get(s3, 1), 0);
  EXPECT_EQ_DOUBLE(61, Storage_get(s3, 2), 0);
}

////////////////////////////////////////////////////////////////////////////////
// testFill
////////////////////////////////////////////////////////////////////////////////

static void
testFill()
{
  Storage_T s3 = Storage_new(3);
  Storage_fill(s3, 27);
  EXPECT_EQ_DOUBLE(27.0, Storage_get(s3, 0), 0);
  EXPECT_EQ_DOUBLE(27.0, Storage_get(s3, 1), 0);
  EXPECT_EQ_DOUBLE(27.0, Storage_get(s3, 2), 0);
}

////////////////////////////////////////////////////////////////////////////////
// testFree
////////////////////////////////////////////////////////////////////////////////

static void
testFree()
{
  Storage_T s3 = Storage_new(3);
  Storage_free(&s3);
  EXPECT_NULL(s3);
}

////////////////////////////////////////////////////////////////////////////////
// testGetSet
////////////////////////////////////////////////////////////////////////////////

static void
testGetSet()
{
  Storage_T s3 = Storage_new(3);
  Storage_set(s3, 0, 10);
  Storage_set(s3, 1, 11);
  Storage_set(s3, 2, 12.0);
  EXPECT_EQ_DOUBLE(10.0, Storage_get(s3, 0), 0);
  EXPECT_EQ_DOUBLE(11.0, Storage_get(s3, 1), 0);
  EXPECT_EQ_DOUBLE(12.0, Storage_get(s3, 2), 0);
}

////////////////////////////////////////////////////////////////////////////////
// testIncrementDecrement
////////////////////////////////////////////////////////////////////////////////

static void
testIncrementDecrement()
{
  Storage_T s3 = Storage_new(3);
  EXPECT_EQ_UNSIGNED(1, Storage_nReferences(s3));
  Storage_increment(s3);
  EXPECT_EQ_UNSIGNED(2, Storage_nReferences(s3));
  Storage_decrement(s3);
  EXPECT_EQ_UNSIGNED(1, Storage_nReferences(s3));
  Storage_decrement(s3);
  EXPECT_NOT_NULL(s3);
}


////////////////////////////////////////////////////////////////////////////////
// testNew
////////////////////////////////////////////////////////////////////////////////

static void
testNew()
{
  Storage_T s0 = Storage_new(0);
  EXPECT_EQ_UNSIGNED(0, Storage_size(s0));
  EXPECT_EQ_UNSIGNED(1, Storage_nReferences(s0));

  Storage_T s3 = Storage_new(3);
  EXPECT_EQ_UNSIGNED(3, Storage_size(s3));
  EXPECT_EQ_UNSIGNED(1, Storage_nReferences(s3));

}

////////////////////////////////////////////////////////////////////////////////
// testNewCopy
////////////////////////////////////////////////////////////////////////////////

static void
testNewCopy()
{
  Storage_T s3 = Storage_new(3);
  Storage_set(s3, 0, 10.0);
  Storage_set(s3, 1, 11.0);
  Storage_set(s3, 2, 12.0);
  Storage_T c = Storage_newCopy(s3);  // the copy shares nothing
  Storage_free(&s3);
  EXPECT_EQ_UNSIGNED(3, Storage_size(c));
  EXPECT_EQ_UNSIGNED(1, Storage_nReferences(c));
  EXPECT_EQ_DOUBLE(10.0, Storage_get(c, 0), 0);
  EXPECT_EQ_DOUBLE(11.0, Storage_get(c, 1), 0);
  EXPECT_EQ_DOUBLE(12.0, Storage_get(c, 2), 0);
  Storage_free(&c);
}

////////////////////////////////////////////////////////////////////////////////
// testPrint
////////////////////////////////////////////////////////////////////////////////

static void testPrint()
{
  Storage_T s = Storage_new(12);
  Storage_increment(s);
  for (unsigned i = 0; i < 10; i++)
    Storage_set(s, i, i + 1);
  fprintf(stderr, "Check for first 10 elements 1, 2, ..., 10; ref count = 2\n");
  Storage_print(s, stderr);
  Storage_decrement(s);
  Storage_free(&s);
}

////////////////////////////////////////////////////////////////////////////////
// testPrintHeader
////////////////////////////////////////////////////////////////////////////////

static void testPrintHeader()
{
  Storage_T s = Storage_new(12);
  fprintf(stderr, "expect just storage header\n");
  Storage__print_header(s, stderr);
  Storage_free(&s);
}

////////////////////////////////////////////////////////////////////////////////
// testResize
////////////////////////////////////////////////////////////////////////////////

static void
testResize()
{
  Storage_T s3 = Storage_new(3);
  Storage_set(s3, 0, 10.0);
  Storage_set(s3, 1, 11.0);
  Storage_set(s3, 2, 12.0);

  Storage_T r1 = Storage_newCopy(s3);  // the copy shares nothing
  Storage_resize(r1, 1);
  EXPECT_EQ_UNSIGNED(1, Storage_size(r1));
  EXPECT_EQ_DOUBLE(10.0, Storage_get(r1, 0), 0);

  Storage_T r5 = Storage_newCopy(s3);  // the copy shares nothing
  Storage_resize(r5, 5);
  EXPECT_EQ_UNSIGNED(5, Storage_size(r5));
  EXPECT_EQ_DOUBLE(10.0, Storage_get(r5, 0), 0);
  EXPECT_EQ_DOUBLE(11.0, Storage_get(r5, 1), 0);
  EXPECT_EQ_DOUBLE(12.0, Storage_get(r5, 2), 0);
}

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int 
main(int argc, char **argv)
{
  testApply();
  testFree();
  testNew();
  testNewCopy();
  testFill();
  testGetSet();
  testIncrementDecrement();
  testPrint();
  testPrintHeader();
  testResize();

  UnitTest_report();
}
