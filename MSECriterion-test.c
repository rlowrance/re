// MSECriterion-test.c

#include "MSECriterion.h"
#include "UnitTest.h"

//////////////////////////////////////// testBackward

static void testBackward()
{
  MSECriterion_T mc = MSECriterion_new();
  
  Tensor_T input = Tensor_newLinSpace(1, 3, 3);
  
  Tensor_T target = Tensor_new1(3);
  Tensor_fill(target, 10.0);
  
  Tensor_T result = MSECriterion_backward(mc, input, target);
  EXPECT_EQ_UNSIGNED(1, Tensor_nDimensions(result));
  EXPECT_EQ_UNSIGNED(3, Tensor_size0(result));
  EXPECT_EQ_DOUBLE((2.0 / 3.0) * (1 - 10) * 1, Tensor_get1(result, 0), 0);
  EXPECT_EQ_DOUBLE((2.0 / 3.0) * (2 - 10) * 2, Tensor_get1(result, 1), 0);
  EXPECT_EQ_DOUBLE((2.0 / 3.0) * (3 - 10) * 3, Tensor_get1(result, 2), 0);
  
  // free
  MSECriterion_free(&mc);
  EXPECT_NULL(mc);

  Tensor_free(&result);
}

//////////////////////////////////////// testForward

static void testForward()
{
  // 1d size 1
  {
    MSECriterion_T mc = MSECriterion_new();
    
    Tensor_T input = Tensor_new1(1);
    Tensor_fill(input, 2);

    Tensor_T target = Tensor_new1(1);
    Tensor_fill(target, 3);

    double result = MSECriterion_forward(mc, input, target);
    EXPECT_EQ_DOUBLE(1.0, result, 0);

    // free
    MSECriterion_free(&mc);
    EXPECT_NULL(mc);
  }

  // TODO: size 6 and size 2 3
  {
    MSECriterion_T mc = MSECriterion_new();
    
    Tensor_T input = Tensor_newLinSpace(1.0, 6.0, 6);
    EXPECT_EQ_DOUBLE(1.0, Tensor_get1(input, 0), 0);

    Tensor_T target = Tensor_new2(2, 3);
    Tensor_fill(target, 3);

    double result = MSECriterion_forward(mc, input, target);
    EXPECT_EQ_DOUBLE(19.0 / 6.0, result, 0);

    // free
    MSECriterion_free(&mc);
    EXPECT_NULL(mc);
   
  }
  
  
}

//////////////////////////////////////// testFree

static void testFree()
{
  MSECriterion_T mc = MSECriterion_new();
  MSECriterion_free(&mc);
  EXPECT_NULL(mc);
}

//////////////////////////////////////// testNew

static void testNew()
{
  MSECriterion_T mc = MSECriterion_new();
  EXPECT_NOT_NULL(mc);
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
