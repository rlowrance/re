// Knn.h
// k nearest neighbors

#ifndef KNN_H
#define KNN_H

#include "KnnCache.h"


// determine indices of nearest neighbors to inputs[queryIndex] in inputs[][]
// exclude query point from these indices
extern void Knn_nearest_indices(unsigned  nObs,
                                unsigned  nDims,
                                double   *inputsP, // inputs[nObs][nDims],
                                unsigned  nNeighbors,
                                unsigned *indicesP, // indices[nNeighbors]
                                unsigned  queryIndex);

// re-estimate an existing observation
// don't use the observation in the estimate
// return the estimate
// queryIndex must be in the cache
extern double Knn_reestimate_queryIndex(unsigned   nObs, 
					unsigned   nDims, 
					double    *inputsP, // inputs[nObs][nDims], 
					double    *targetsP, // targets[nObs], 
					unsigned   k,
					unsigned   queryIndex,
                                        unsigned   nNeighbors,
					KnnCache_T cache);

// estimate a new observation
// return the estimate
extern double Knn_estimate_query(unsigned  nObs, 
				 unsigned  nDims, 
				 double   *inputsP,  // inputs[nObs][nDims], 
				 double   *targetsP, // targets[nObs], 
				 unsigned  k,
				 double   *queryP);  // query[nDims]);


// re-estimate an existing observation
// use the observation in the estimate
extern double Knn_smooth(unsigned  nObs, 
			 unsigned  nDims, 
			 double   *inputsP, // inputs[nObs][nDims], 
			 double   *targetsP, // targets[nObs],
			 unsigned  k,
			 unsigned  queryIndex);

#undef T
#endif
