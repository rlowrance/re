// Function-test.c

#include <stddef.h>

#include "Function.h"
#include "UnitTest.h"

//////////////////////////////////////// testFunctionConstant

static void testFunctionConstant()
{
  double zero = 0.0;
  EXPECT_EQ_DOUBLE(0.0, Function_constant(123.0, &zero), 0.0);
  
  double one = 1.0;
  EXPECT_EQ_DOUBLE(1.0, Function_constant(27.0, &one), 0.0);
}

//////////////////////////////////////// testFunctionZero

static void testFunctionZero()
{
  EXPECT_EQ_DOUBLE(0.0, Function_zero(27.0, NULL), 0.0);
		   }

//////////////////////////////////////// main

int main(int argc, char **argv)
{
  testFunctionConstant();
  testFunctionZero();

  UnitTest_report();
}
