// KnnCache-test.c
// unit test of KnnCache.h implementation

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "KnnCache.h"

static int verbose = 0;

static const unsigned sizeLarge = 1300000; // size of largest cache
static const unsigned sizeSmall = 2;       // for ease of testing

void testNew() {
  if (verbose) puts("starting testNew");
  KnnCache_T kcSmall = KnnCache_new(sizeSmall);
  assert(kcSmall);

  KnnCache_T kcLarge = KnnCache_new(sizeLarge);
  assert(kcLarge);
}

void testFree() {
  if (verbose) puts("starting testFree");
  KnnCache_T kcSmall = KnnCache_new(sizeSmall);
  KnnCache_free(&kcSmall);
  assert(!kcSmall);

  KnnCache_T kcLarge = KnnCache_new(sizeLarge);
  KnnCache_free(&kcLarge);
  assert(!kcLarge);
}

////////////////////////////////////////////////////////////////////////////////
// makeLarge
////////////////////////////////////////////////////////////////////////////////

const unsigned largeNExamples = 256000;
const unsigned largeNn = 256;
unsigned *largeExamplesP = NULL;

KnnCache_T makeLarge() {
  assert(largeNExamples < sizeLarge);

  // allocate example[nExamples,largeNn]
  largeExamplesP = (unsigned*) malloc(sizeof(unsigned) * largeNExamples * largeNn);
  assert(largeExamplesP);

  // randomly initialize the examples
  srand((unsigned) time(NULL));  // seed random number generator
  for (unsigned i = 0; i < largeNExamples; i++) {
    for (unsigned d = 0; d < largeNn; d++) {
      int r = rand();  // r in (0, 2^15 - 1)
      unsigned v = (unsigned) r;
      *(largeExamplesP + i * largeNn + d) = v;
    }
  }

  // set each example in the cache
  if (verbose) puts("starting set large");
  KnnCache_T kcLarge = KnnCache_new(sizeLarge);
  for (unsigned i = 0; i < largeNExamples; i++) {
    unsigned queryIndex = i;
    assert(queryIndex < sizeLarge);
    KnnCache_set(kcLarge, queryIndex, largeNn, largeExamplesP + i* largeNn);
  }

  return kcLarge;
}

////////////////////////////////////////////////////////////////////////////////
// makeSmall
///////////////////////////////////////////////////////////////////////////////

const unsigned smallNExamples = 2;
const unsigned smallNn = 3;

const unsigned smallValues0[] = {1,2,3};
const unsigned smallValues1[] = {11,12,13};

KnnCache_T makeSmall() {
  KnnCache_T kcSmall = KnnCache_new(sizeSmall);
  KnnCache_set(kcSmall, 0, smallNn, smallValues0);
  KnnCache_set(kcSmall, 1, smallNn, smallValues1);

  return kcSmall;
}

////////////////////////////////////////////////////////////////////////////////
// testGet
////////////////////////////////////////////////////////////////////////////////

void testGet() {
  const int debug = 0;
  if (verbose) puts("starting testGet");
  
  // test small
  KnnCache_T kcSmall = makeSmall();
  unsigned *rowP = NULL;

  rowP = KnnCache_get(kcSmall, 0);
  assert(rowP);
  if (debug) printf("rowP=%p\n", (void*)rowP);
  if (debug) printf("rowP[0]=%u\n", *(rowP + 0));
  assert(1 == *(rowP + 0));
  assert(2 == *(rowP + 1));
  assert(3 == *(rowP + 2));

  rowP = KnnCache_get(kcSmall, 1);
  assert(11 == *(rowP + 0));
  assert(12 == *(rowP + 1));
  assert(13 == *(rowP + 2));
 
  // TODO: test large

}

////////////////////////////////////////////////////////////////////////////////
// testSet
////////////////////////////////////////////////////////////////////////////////

void testSet() {
  if (verbose) puts("starting testSet");

  makeSmall();
  makeLarge();
}



int main(int argc, char ** argv) {
  testNew();
  testFree();
  testSet();
  testGet();
}

