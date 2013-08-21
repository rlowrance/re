// Linear-test.c
// unit test of Linear ADT

#include <stdio.h>

#include "Linear.h"
#include "UnitTest.h"

//////////////////////////////////////// testBackward

static void testBackward()
{
  EXPECT_FAIL("write me");
}

//////////////////////////////////////// testForward

static void testForward()
{
  const unsigned trace = 1;
  const unsigned nInputs = 3;
  const unsigned nOutputs = 1;
  Linear_T l = Linear_new(nInputs, nOutputs);
  if (trace) Linear_print(l, stderr);

  Tensor_T input = Tensor_newLinSpace(1, 3, 3);
  Linear_forward(l, input);
  if (trace) Linear_print(l, stderr);

  EXPECT_FAIL("write me");
}

//////////////////////////////////////// testFree

static void testFree()
{
  Linear_T l = Linear_new(1, 1);
  Linear_free(&l);
  EXPECT_NULL(l);
}

//////////////////////////////////////// testNew

static void testNew()
{
  Linear_T l = Linear_new(1, 1);
  EXPECT_NOT_NULL(l);
}


//////////////////////////////////////// main

int main(int argc, char **argv)
{
  testBackward();
  testForward();
  testFree();
  testNew();

  UnitTest_report();
}
