// Knn-test.c
// Unit tests of Knn.h

#include <assert.h>
#include <math.h>
#include <stdio.h>

#include "Knn.h"
#include "KnnCache.h"
#include "UnitTest.h"

////////////////////////////////////////////////////////////////////////////////
// makeDate
////////////////////////////////////////////////////////////////////////////////

static void makeData(unsigned *nObsP, unsigned *nDimsP, double **inputsPP, double **targetsPP) {
  static unsigned nObs = 4;
  static unsigned nDims = 2;
  static double inputs[]  = {0,0, 1,1, 2,2, 3,3};
  static double targets[] = {0, 1, 2, 3};
  *nObsP = nObs;
  *nDimsP = nDims;
  *inputsPP = inputs;
  *targetsPP = targets;
}

////////////////////////////////////////////////////////////////////////////////
// testKnnNearestIndices
////////////////////////////////////////////////////////////////////////////////

static void testKnnNearestIndices() {
  unsigned nObs;
  unsigned nDims;
  double *inputsP;
  double *targetsP;
  makeData(&nObs, &nDims, &inputsP, &targetsP);
  const unsigned nNeighbors = 2;
  unsigned nnIndices[nNeighbors];

  // queryIndex == 0
  Knn_nearest_indices(nObs, nDims, inputsP, nNeighbors, nnIndices, 0);
  EXPECT_EQ_UNSIGNED(1, nnIndices[0]);
  EXPECT_EQ_UNSIGNED(2, nnIndices[1]);

  // queryIndex == 1
  Knn_nearest_indices(nObs, nDims, inputsP, nNeighbors, nnIndices, 1);
  EXPECT_EQ_UNSIGNED(0, nnIndices[0]);
  EXPECT_EQ_UNSIGNED(2, nnIndices[1]);

  // queryIndex == 2
  Knn_nearest_indices(nObs, nDims, inputsP, nNeighbors, nnIndices, 2);
  EXPECT_EQ_UNSIGNED(1, nnIndices[0]);
  EXPECT_EQ_UNSIGNED(3, nnIndices[1]);

  // queryIndex == 3
  Knn_nearest_indices(nObs, nDims, inputsP, nNeighbors, nnIndices, 3);
  EXPECT_EQ_UNSIGNED(2, nnIndices[0]);  // NOTE: order does not matter
  EXPECT_EQ_UNSIGNED(1, nnIndices[1]);
}

////////////////////////////////////////////////////////////////////////////////
// testKnnReestimateQueryIndex
////////////////////////////////////////////////////////////////////////////////

static void testKnnReestimateQueryIndex() {
  const int trace = 0;
  unsigned nObs;
  unsigned nDims;
  double *inputsP;
  double *targetsP;
  makeData(&nObs, &nDims, &inputsP, &targetsP);

  // buid the cache
  KnnCache_T cache = KnnCache_new(nObs);
  const unsigned nNeighbors = 3;
  unsigned nnIndices[nNeighbors];

  for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
    Knn_nearest_indices(nObs, nDims, inputsP, nNeighbors, nnIndices, queryIndex);
    KnnCache_set(cache, queryIndex, nNeighbors, nnIndices);
  }

  // re-estimate each target for k == 1
  {
    const unsigned k = 1;
    double expected[] = {1.0, 0.0, 1.0, 2.0}; // {1, 0 or 2, 1 or 3, 2}
    for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
      double estimate = 
        Knn_reestimate_queryIndex(nObs, nDims, 
                                  inputsP, targetsP, 
                                  k, queryIndex, 
                                  nNeighbors, cache);
      if (trace) printf("queryIndex=%u\n", queryIndex);
      EXPECT_EQ_DOUBLE(expected[queryIndex], estimate, 1e-10);
    }
  }
  // re-estimate each target for k == 2
  {
    const unsigned k = 2;
    double expected[] = {1.5, 1.0, 2.0, 1.5};
    for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
      double estimate = 
        Knn_reestimate_queryIndex(nObs, nDims, 
                                  inputsP, targetsP, 
                                  k, queryIndex, 
                                  nNeighbors, cache);
      if (trace) printf("queryIndex=%u\n", queryIndex);
      EXPECT_EQ_DOUBLE(expected[queryIndex], estimate, 1e-10);
    }
  }

  // re-estimate each target for k == 3
  {
    const unsigned k = 3;
    double expected[] = {2.0, 1.666666666667, 1.3333333333, 1.0};
    for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
      double estimate = 
        Knn_reestimate_queryIndex(nObs, nDims, 
                                  inputsP, targetsP, 
                                  k, queryIndex, 
                                  nNeighbors, cache);
      if (trace) printf("queryIndex=%u\n", queryIndex);
      EXPECT_EQ_DOUBLE(expected[queryIndex], estimate, 1e-10);
    }
  }


    
}


////////////////////////////////////////////////////////////////////////////////
// testKnnEstimateQuery
////////////////////////////////////////////////////////////////////////////////

static void testKnnEstimateQuery() {
  unsigned nObs;
  unsigned nDims;
  double *inputsP;
  double *targetsP;
  makeData(&nObs, &nDims, &inputsP, &targetsP);

  // query = [1 1]
  {
    double query[] = {1, 1};
    
    double estimate =
      Knn_estimate_query(nObs, nDims, inputsP, targetsP, 1, query);
    EXPECT_EQ_DOUBLE(1.0, estimate, 1e-10);
    
    estimate = Knn_estimate_query(nObs, nDims, inputsP, targetsP, 3, query);
    EXPECT_EQ_DOUBLE(1.0, estimate, 1e-10);
    
    estimate = Knn_estimate_query(nObs, nDims, inputsP, targetsP, 4, query);
    EXPECT_EQ_DOUBLE(1.5, estimate, 1e-10);
  }

  // query = [2 1]
  {
    double query[] = {1.5, 1};
    
    double estimate =
      Knn_estimate_query(nObs, nDims, inputsP, targetsP, 1, query);
    EXPECT_EQ_DOUBLE(1.0, estimate, 1e-10);
    
    estimate = Knn_estimate_query(nObs, nDims, inputsP, targetsP, 2, query);
    EXPECT_EQ_DOUBLE(1.5, estimate, 1e-10);
    
    estimate = Knn_estimate_query(nObs, nDims, inputsP, targetsP, 3, query);
    EXPECT_EQ_DOUBLE(1.0, estimate, 1e-10);

    estimate = Knn_estimate_query(nObs, nDims, inputsP, targetsP, 4, query);
    EXPECT_EQ_DOUBLE(1.5, estimate, 1e-10);
  }
}





////////////////////////////////////////////////////////////////////////////////
// testKnnSmooth
////////////////////////////////////////////////////////////////////////////////



static void testKnnSmooth() {
  const int trace = 0;
  unsigned nObs;
  unsigned nDims;
  double *inputsP;
  double *targetsP;
  makeData(&nObs, &nDims, &inputsP, &targetsP);

  // smooth each target for k == 1
  {
    const unsigned k = 1;
    double expected[] = {0.0, 1.0, 2.0, 3.0};
    for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
      double estimate = 
        Knn_smooth(nObs, nDims, 
                   inputsP, targetsP, 
                   k, queryIndex); 
      if (trace) printf("queryIndex=%u\n", queryIndex);
      EXPECT_EQ_DOUBLE(expected[queryIndex], estimate, 1e-10);
    }
  }

  // smooth each target for k == 2
  {
    const unsigned k = 2;
    double expected[] = {0.5, 0.5, 1.5, 2.5};
    for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
      double estimate = 
        Knn_smooth(nObs, nDims, 
                   inputsP, targetsP, 
                   k, queryIndex); 
      if (trace) printf("queryIndex=%u\n", queryIndex);
      EXPECT_EQ_DOUBLE(expected[queryIndex], estimate, 1e-10);
    }
  }

  // smooth each target for k == 3
  {
    const unsigned k = 3;
    double expected[] = {1.0, 1.0, 2.0, 2.0};
    for (unsigned queryIndex = 0; queryIndex < nObs; queryIndex++) {
      double estimate = 
        Knn_smooth(nObs, nDims, 
                   inputsP, targetsP, 
                   k, queryIndex); 
      if (trace) printf("queryIndex=%u\n", queryIndex);
      EXPECT_EQ_DOUBLE(expected[queryIndex], estimate, 1e-10);
    }
  }
}

////////////////////////////////////////////////////////////////////////////////
// main
////////////////////////////////////////////////////////////////////////////////

int
main(int argc, char** argv) {
  testKnnNearestIndices();
  testKnnReestimateQueryIndex();
  testKnnEstimateQuery();
  testKnnSmooth();

  UnitTest_report();
}
