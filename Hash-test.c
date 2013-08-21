// Hash-test.c
// unit tests

#include <assert.h>
#include <inttypes.h>

#include "Str.h"
#include "UnitTest.h"

#include "Hash.h"

////////////////////////////////////////////////////////////////////////////////
// static functions
////////////////////////////////////////////////////////////////////////////////

uint32_t hashInt(void *keyP, uint32_t tableSize)
{
  assert(keyP);
  int *valueP = (int *) keyP;
  int result = (*valueP) / tableSize;
  if (result < 0)
    result += tableSize;
  return result;
}

int  compareInt(void *key1P, void *key2P) 
{
  assert(key1P);
  assert(key2P);

  int *value1P = (int *) key1P;
  int *value2P = (int *) key2P;

  if ((*value1P) == (*value2P))
    return 1;
  else
    return 0;
}

////////////////////////////////////////////////////////////////////////////////
// testFree
////////////////////////////////////////////////////////////////////////////////

static void testFree()
{
  Hash_T h0 = Hash_new(0);
  Hash_free(&h0);
  EXPECT_NULL(h0);

  Hash_T h1 = Hash_new(1);
  Hash_free(&h1);
  EXPECT_NULL(h1);

  Hash_T h2 = Hash_new(2);
  Hash_free(&h2);
  EXPECT_NULL(h2);
}

////////////////////////////////////////////////////////////////////////////////
// testInsert
////////////////////////////////////////////////////////////////////////////////

static void testInsert()
{
  // test general case
  Hash_T h0 = Hash_new(0);
  EXPECT_EQ_UINT32(0, h0->nElements);
  EXPECT_EQ_UINT32(0, h0->tableSize);

  int key1 = 123;
  char* value1 = "1";
  h0 = Hash_insert(h0, Atom_newFromInt64(key1), value1);
  EXPECT_NOT_NULL(h0);
  EXPECT_EQ_UINT32(1, h0->nElements);
  EXPECT_EQ_UINT32(1, h0->tableSize);

  int key2 = -27;
  char value2[] = "value2";
  h0 = Hash_insert(h0, Atom_newFromInt64(key2), value2);
  EXPECT_NOT_NULL(h0);
  EXPECT_EQ_UINT32(2, h0->nElements);
  EXPECT_EQ_UINT32(3, h0->tableSize);

  char * key3 = "abc";
  int16_t value3 = 1056;
  Str_T s = Str_newFromInt16(value3);
  h0 = Hash_insert(h0, Atom_newFromString(key3), Str_str(s));
  EXPECT_NOT_NULL(h0);
  EXPECT_EQ_UINT32(3, h0->nElements);
  EXPECT_EQ_UINT32(3, h0->tableSize);
  Str_free(&s);

  Hash_free(&h0);
  EXPECT_NULL(h0);
}

////////////////////////////////////////////////////////////////////////////////
// testNew
////////////////////////////////////////////////////////////////////////////////

static void testNew()
{
  Hash_T h0 = Hash_new(0);
  EXPECT_NOT_NULL(h0);

  Hash_T h1 = Hash_new(1);
  EXPECT_NOT_NULL(h1);

  Hash_T h2 = Hash_new(2);
  EXPECT_NOT_NULL(h2);
}

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int
main(int argc, char **argv)
{
  testNew();
  testFree();
  testInsert();

  UnitTest_report();
}

