// Knn.c
// Not an ADT, but a collection of related functions

#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "KnnCache.h"
#include "halt.h"

#define T Knn_T    

////////////////////////////////////////////////////////////////////////////////
// types
////////////////////////////////////////////////////////////////////////////////

struct distanceIndex {
  double distance;
  unsigned index;
};

////////////////////////////////////////////////////////////////////////////////
// static functions
////////////////////////////////////////////////////////////////////////////////

/*
static void fail(char * msg) {
  fprintf(stderr, "%s\n", msg);
  exit(1);
}
*/
                               

static int sortCompareFunction(const void *a, const void *b)
{
  const int trace = 0;
  struct distanceIndex *diAPtr = (struct distanceIndex *) a;
  struct distanceIndex *diBPtr = (struct distanceIndex *) b;
  double distanceA = diAPtr -> distance;
  double distanceB = diBPtr -> distance;
  int result;
  if (distanceA < distanceB) result =  -1;
  else if (distanceA > distanceB) result = +1;
  else result =  0;
  if (trace) printf("sortCompareFunction: distances A %f B %f result %d\n",
		    distanceA, distanceB, result);
  return result;
}

// determine indices of neighbors, setting neigbhorsP[nNeighbors]
static void determineNeighbors(unsigned  nObs,
                               unsigned  nNeighbors,
                               unsigned *neighborsP,
                               double    distance(unsigned obsIndex, void *upValuesP),
                               void     *upValuesP) {
  struct distanceIndex di[nObs];
  for (unsigned obsIndex = 0; obsIndex < nObs; obsIndex++) {
    di[obsIndex].distance = distance(obsIndex, upValuesP);
    di[obsIndex].index = obsIndex;
  }

  qsort(di, nObs, sizeof(struct distanceIndex), sortCompareFunction);

  for (unsigned neighborIndex = 0; neighborIndex < nNeighbors; neighborIndex++) {
    *(neighborsP + neighborIndex) = di[neighborIndex].index;
  }
}

////////////////////////////////////////////////////////////////////////////////
// Knn_nearest_indices
////////////////////////////////////////////////////////////////////////////////

struct distanceKnnNearestNeighborsUpValues {
  double  *inputsP;
  unsigned nDims;
  unsigned queryIndex;
};

static double distanceKnnNearestNeighbors(unsigned obsIndex, void * upValuesPVoid) {
  struct distanceKnnNearestNeighborsUpValues *upValuesP = upValuesPVoid;
  const unsigned queryIndex = upValuesP->queryIndex;
  if (obsIndex == upValuesP->queryIndex)
    return DBL_MAX;

  const unsigned nDims = upValuesP->nDims;
  const double *inputsP = upValuesP->inputsP;

  double sumSquaredDistances = 0.0;
  for (unsigned dimIndex = 0; dimIndex < nDims; dimIndex++) {
    const double distance = 
      *(inputsP + obsIndex * nDims + dimIndex) -
      *(inputsP + queryIndex * nDims + dimIndex);
    sumSquaredDistances += distance * distance;
  }
  return sqrt(sumSquaredDistances);
}

// return indices of nearest neighbors to inputs[queryIndex] in input[][]
// exclude query point from these indices
void Knn_nearest_indices(unsigned  nObs,
                         unsigned  nDims,
                         double   *inputsP, // inputs[nObs][nDims],
                         unsigned  nNeighbors,
                         unsigned *indicesP, // indices[nNeighbors]
                         unsigned  queryIndex) {
  const int reportCpuTime = 0;
  
  assert(nNeighbors <= nObs);

  clock_t startClock = reportCpuTime ? clock() : 0;

  struct distanceKnnNearestNeighborsUpValues upValues;
  upValues.inputsP = inputsP;
  upValues.nDims = nDims;
  upValues.queryIndex = queryIndex;
 
  determineNeighbors(nObs, nNeighbors, indicesP, distanceKnnNearestNeighbors, &upValues);

  if (reportCpuTime) {
    clock_t elapsedTicks = clock() - startClock;
    fprintf(stderr, 
            "Knn_nearest_indices: Found %u nearest neighbor indices among %u in %f CPU secs\n",
            nNeighbors, nObs, (double)elapsedTicks / CLOCKS_PER_SEC);
  }
}

////////////////////////////////////////////////////////////////////////////////
// Knn_reestimate_queryIndex
////////////////////////////////////////////////////////////////////////////////

// return distance between two rows of inputs
double distance(unsigned nObs, unsigned nDims, double inputs[nObs][nDims], 
                unsigned obsIndex, unsigned queryIndex) {
  double sumSquaredDifferences = 0.0;
  for (unsigned i = 0; i < nDims; i++) {
    double diff = inputs[obsIndex][i] - inputs[queryIndex][i];
    sumSquaredDifferences += diff * diff;
  }
  return sqrt(sumSquaredDifferences / nDims);
}

// is the index in the cache?
int contains(unsigned nNeighbors, unsigned neighborsCache[nNeighbors], unsigned index) {
  for (unsigned i = 0; i < nNeighbors; i++) {
    if (index == neighborsCache[i]) return 1;
  }
  return 0;
}

// check that the neighbors of queryIndex are correctly computed
// only do this for 40 neighbors
void checkCache(unsigned nNeighbors, unsigned neighborsCache[nNeighbors],
                unsigned queryIndex,
                unsigned nObs, unsigned nDims, double inputs[nObs][nDims]) {
  if (queryIndex != 2) return;
  fprintf(stderr, "checkCache: nNeighbors %u queryIndex %u nObs %u nDims %u\n",
          nNeighbors, queryIndex, nObs, nDims);
  //struct distanceIndex di[nObs];
  unsigned underThreshold = 0;
  double threshold = 0.2813;
  fprintf(stderr, "threshold %f\n", threshold);
  for (unsigned obsIndex = 0; obsIndex < nObs; obsIndex++) {
    double d = distance(nObs, nDims, inputs, obsIndex, queryIndex);
    //di[obsIndex].index = obsIndex;
    if (d < threshold) {
      underThreshold++;
      if (contains(nNeighbors, neighborsCache, obsIndex)) 
        fprintf(stderr, "numUnderThreshold %u obsIndex %u is in neighborsCache\n",
                underThreshold, obsIndex);
    }
  }
  fprintf(stderr, "threshold %f generates %u under threshold\n", threshold, underThreshold);
  halt("check for 256 indices under Threshold");
}

// re-estimate an existing observation
// don't use the observation in the estimate
// return the estimate
// queryIndex must be in the cache
double Knn_reestimate_queryIndex(unsigned   nObs, 
                                 unsigned   nDims, 
                                 double     inputs[nObs][nDims], 
                                 double     targets[nObs], 
                                 unsigned   k,
                                 unsigned   queryIndex,
                                 unsigned   nNeighbors,
                                 KnnCache_T cache) {
  const int trace = 0;
  const int debug = 1;
  assert(queryIndex <= nObs);
  assert(k <= nNeighbors);

  if (trace) fprintf(stderr, "Knn_reestimate_queryIndex: queryIndex %u\n", queryIndex);

  //unsigned neighbors[nNeighbors] = KnnCache_get(cache, queryIndex);
  unsigned *neighbors = KnnCache_get(cache, queryIndex);
  if (neighbors == NULL)
    fprintf(stderr, "Knn_reestimate_queryIndex: queryIndex %u not in cache\n",
            queryIndex);
  assert(neighbors);
  if (trace) {
    fprintf(stderr, "Knn_reestimate_queryIndex: neighbors of %u are", queryIndex);
    for (unsigned neighborIndex = 0; neighborIndex < k; neighborIndex++) 
      fprintf(stderr, " %u",neighbors[neighborIndex]);
    fprintf(stderr, "\n");
  }

  if (debug) checkCache(nNeighbors, neighbors, queryIndex, nObs, nDims, inputs);

  double sumTargets = 0.0;
  for (unsigned neighborIndex = 0; neighborIndex < k; neighborIndex++) {
    sumTargets += targets[neighbors[neighborIndex]];
    if (trace)
      fprintf(stderr, "Knn_restimate_queryIndex: targets[%u]=%f\n",
            neighbors[neighborIndex], targets[neighbors[neighborIndex]]);

  }
  double result = sumTargets / k;
  if (trace)
    fprintf(stderr, "Knn_restimate_queryIndex: sumTargets %f k %u result %f\n",
            sumTargets, k, result);

  return result;
}

////////////////////////////////////////////////////////////////////////////////
// Knn_estimate_query
////////////////////////////////////////////////////////////////////////////////

struct distanceKnnEstimateQueryUpValues {
  double  *inputsP;
  unsigned nDims;
  double  *queryP;
};

static double distanceKnnEstimateQuery(unsigned  obsIndex, 
                                       void     *upValuesPVoid) {
  struct distanceKnnEstimateQueryUpValues *upValuesP = upValuesPVoid;

  double  *inputsP = upValuesP->inputsP;
  unsigned nDims = upValuesP->nDims;
  double  *queryP = upValuesP->queryP;

  double sumSquaredDistances = 0.0;
  for (unsigned dimIndex = 0; dimIndex < nDims; dimIndex++) {
    const double distance = 
      *(inputsP + obsIndex * nDims + dimIndex) -
      *(queryP + dimIndex);
    sumSquaredDistances += distance * distance;
  }
  return sqrt(sumSquaredDistances);
}

// estimate a new observation
// return the estimate
double Knn_estimate_query(unsigned nObs, 
                          unsigned nDims, 
                          double  *inputsP, // inputs[nObs][nDims], 
                          double   targets[nObs], 
                          unsigned k,
                          double  *queryP) { // query[nDims]
  const int trace = 0;
  assert(k <= nObs);
  unsigned *neighborsP = malloc(sizeof(unsigned) * k);
  
  struct distanceKnnEstimateQueryUpValues upValues;
  upValues.inputsP = inputsP;
  upValues.nDims = nDims;
  upValues.queryP = queryP;
  
  determineNeighbors(nObs, k, neighborsP, distanceKnnEstimateQuery, &upValues);

  double sumTargets = 0.0;
  for (unsigned neighborIndex = 0; neighborIndex < k; neighborIndex++) {
    sumTargets += targets[neighborsP[neighborIndex]];
    if (trace)
      fprintf(stderr, "Knn_estimate_query: target[%u]=%f\n",
              neighborsP[neighborIndex], targets[neighborsP[neighborIndex]]);
  }
  double result = sumTargets / k;

  free(neighborsP);

  return result;
}

////////////////////////////////////////////////////////////////////////////////
// Knn_smooth
////////////////////////////////////////////////////////////////////////////////

struct distanceKnnSmoothUpValues {
  double  *inputsP;
  unsigned nDims;
  unsigned queryIndex;
};

static double distanceKnnSmooth(unsigned obsIndex, void *upValuesPVoid) {
  struct distanceKnnSmoothUpValues *upValuesP = upValuesPVoid;

  double *inputsP = upValuesP->inputsP;
  unsigned nDims = upValuesP -> nDims;
  unsigned queryIndex = upValuesP->queryIndex;

  double sumSquaredDistances = 0.0;
  for (unsigned dimIndex = 0; dimIndex < nDims; dimIndex++) {
    const double distance = (obsIndex == upValuesP->queryIndex) ? DBL_MAX :
      *(inputsP + obsIndex * nDims + dimIndex) -
      *(inputsP + queryIndex * nDims + dimIndex);
    sumSquaredDistances += distance * distance;
  }
  double result = sqrt(sumSquaredDistances);
  return result;
}

// re-estimate an existing observation
// use the observation in the estimate
// sumTargets = targets[queryIndex] + targets[nn[0]] + ... + targets[nn[k-1]]
extern double Knn_smooth(unsigned nObs, 
			 unsigned nDims, 
			 double  *inputsP, //inputs[nObs][nDims], 
			 double   targets[nObs],
			 unsigned k,
			 unsigned queryIndex) {
  const int trace = 0;
  assert(k <= nObs);

  unsigned *neighborsP = malloc(sizeof(unsigned) * k);

  struct distanceKnnSmoothUpValues upValues;
  upValues.inputsP = inputsP;
  upValues.nDims = nDims;
  upValues.queryIndex = queryIndex;

  determineNeighbors(nObs, k, neighborsP, distanceKnnSmooth, &upValues);

  // include the queryIndex in the estimate
  double sumTargets = targets[queryIndex];
  if (trace) fprintf(stderr, "Knn_smooth: targets[%u]=%f\n", queryIndex, targets[queryIndex]);
  for (unsigned neighborIndex = 0; neighborIndex < k - 1; neighborIndex++) {
    if (trace)
      fprintf(stderr,
              "Knn_smooth: sumTargets %f targets[%u]=%f\n",
              sumTargets, neighborsP[neighborIndex], targets[neighborsP[neighborIndex]]); 
    sumTargets += targets[neighborsP[neighborIndex]];
  }
  double result = sumTargets / k;

  free(neighborsP);

  return result;
}

