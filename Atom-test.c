// Atom-test.c
// unit tests

#include <assert.h>
#include <inttypes.h>
#include <string.h>

#include "UnitTest.h"

#include "Atom.h"

////////////////////////////////////////////////////////////////////////////////
// testLength
////////////////////////////////////////////////////////////////////////////////

static void testLength()
{
  int valueA = 123;
  Atom_T a = Atom_new((char *) &valueA, sizeof(valueA));
  EXPECT_EQ_UNSIGNED(4, Atom_length(a));

  Atom_T b = Atom_newFromString("abc");
  EXPECT_EQ_UNSIGNED(3, Atom_length(b));

  Atom_T c = Atom_newFromInt64(123);
  EXPECT_EQ_UNSIGNED(8, Atom_length(c));
}


////////////////////////////////////////////////////////////////////////////////
// testNew
////////////////////////////////////////////////////////////////////////////////

static void testNew()
{
  int valueA = 123;
  Atom_T a = Atom_new((char *) &valueA, sizeof(valueA));
  EXPECT_NOT_NULL(a);

  Atom_T b = Atom_newFromString("abc");
  EXPECT_NOT_NULL(b);

  Atom_T c = Atom_newFromInt64(123);
  EXPECT_NOT_NULL(c);
}

////////////////////////////////////////////////////////////////////////////////
// testStr
////////////////////////////////////////////////////////////////////////////////

static void testStr()
{
  int valueA = 123;
  Atom_T a = Atom_new((char *) &valueA, sizeof(valueA));
  char *strA = Atom_str(a);
  EXPECT_EQ_UNSIGNED(1, strlen(strA)); //*strA = [123][0] ...
  EXPECT_EQ_UNSIGNED(123, strA[0]);
  EXPECT_EQ_UNSIGNED(0, strA[1]);  // assume little endian machine
  EXPECT_EQ_UNSIGNED(0, strA[2]);
  EXPECT_EQ_UNSIGNED(0, strA[3]);
  EXPECT_EQ_UNSIGNED(0, strA[4]);

  Atom_T b = Atom_newFromString("abc");
  char *strB = Atom_str(b);
  EXPECT_EQ_UNSIGNED(3, Atom_length(b));
  EXPECT_EQ_STR("abc", strB);

  Atom_T c = Atom_newFromInt64(123);
  char *strC = Atom_str(c);
  EXPECT_EQ_UNSIGNED(1, strlen(strC));
  EXPECT_EQ_UNSIGNED(123, strC[0]);
  EXPECT_EQ_UNSIGNED(0, strC[1]);
  EXPECT_EQ_UNSIGNED(0, strC[8]);
}

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int
main(int argc, char **argv)
{
  testLength();
  testNew();
  testStr();

  UnitTest_report();
}

