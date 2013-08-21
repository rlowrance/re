// Str-test.c
// unit tests of Str.c

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "Str.h"
#include "UnitTest.h"

////////////////////////////////////////////////////////////////////////////////
// testInt16
////////////////////////////////////////////////////////////////////////////////

static void testInt16()
{
  // test all APIs for type int16_t
  const unsigned trace = 0;
  Str_T s = Str_newFromInt16(27);
  EXPECT_NOT_NULL(s);
  char *cP = Str_str(s);
  EXPECT_NOT_NULL(cP);
  EXPECT_TRUE(strcmp("int16_t", s->valueTypeName) == 0);
  EXPECT_EQ_INT16(27, Str_valueInt16(s));
  if (trace) // "s as str should be funny"
    fprintf(stderr, "s as str: %s as int16: %d\n",
            Str_str(s), Str_valueInt16(s));
  Str_free(&s);
  EXPECT_NULL(s);
}

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int
main(int argc, char **argv)
{
  testInt16();

  UnitTest_report();
}
