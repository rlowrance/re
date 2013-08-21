// Random-test.c
// unit tests

#include <stdio.h>

#include "UnitTest.h"
#include "Random.h"

static void testBernoulli()
{
  double p = 1e-16;
  EXPECT_EQ_UNSIGNED(0, Random_bernoulli(p));  

  EXPECT_EQ_UNSIGNED(1, Random_bernoulli(1 - p));
  
  p = .5;
  const unsigned n = 100;
  unsigned count0 = 0;
  unsigned count1 = 0;
  for (unsigned i = 0; i < n; i++) {
    const unsigned result = Random_bernoulli(p);
    if (result == 1)
      count1++;
    else if (result == 0)
      count0++;
    else
      EXPECT_FAIL("p not 1 or 0");
  }
  EXPECT_TRUE(count0 > 0 && count1 > 0);
}

static void testCauchy()
{
  EXPECT_TRUE(0 != Random_cauchy(0.0, 1.0));
}

static void testExponential()
{
  EXPECT_TRUE(1 != Random_exponential(3.0));
}

static void testGeometric()
{
  const unsigned trace = 0;
  const unsigned result = Random_geometric(0.5);
  if (trace)
    fprintf(stderr, "testGeometric: result = %u\n", result);
  EXPECT_TRUE(result > 0);
}

static void testInitialSeed()
{
  const unsigned trace = 0;

  const uint64_t seed = Random_initialSeed();
  if (trace)
    fprintf(stderr, "testInitialSeed: the_initial_seed = %lu\n", seed);
  EXPECT_TRUE(seed > 0);
}

void testLogNormal()
{
  const unsigned trace = 1;
  double result = Random_logNormal(0, 1);
  if (trace)
    fprintf(stderr,"testLogNormal: result = %f\n", result);
  EXPECT_TRUE(result > 0);
}

void testManualSeed()
{
  const uint64_t seed = 27;
  EXPECT_EQ_UINT64(seed, Random_manualSeed(seed));
}

void testNormal()
{
  double n1 = Random_normal(0, 1);
  double n2 = Random_normal(0, 1);
  EXPECT_NE_DOUBLE(n1, n2);
}

void testRandom()
{
  uint64_t n1 = Random_random();
  uint64_t n2 = Random_random();
  EXPECT_NE_UINT64(n1, n2);
}

void testSeed()
{
  unsigned long result = Random_seed();
  EXPECT_TRUE(result != 0);
}

void testUniform()
{
  const double low = 10;
  const double high = 10;
  const unsigned n = 10;
  for (unsigned i = 0; i < n; i++) {
    const double result = Random_uniform(low, high);
    EXPECT_TRUE(result >= low);
    EXPECT_TRUE(result <= high);
  }
}

int main(int argc, char ** argv)
{
  testBernoulli();
  testCauchy();
  testExponential();
  testGeometric();			       
  testInitialSeed();
  testLogNormal();
  testManualSeed();
  testNormal();
  testRandom();
  testSeed();
  testUniform();

  UnitTest_report();

}
