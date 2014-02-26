// ObjectivefunctionLogreg.h
// the objective function for Logreg without salience weighting and regularization

#ifndef OBJECTIVEFUNCTIONLOGREG_H
#define OBJECTIVEFUNCTIONLOGREG_H

#include "Matrix.h"
#include "Vector.h"

typedef struct {
    int nClasses;
    int nFeatures;
} ObjectivefunctionLogreg;

// construction

extern ObjectivefunctionLogreg* ObjectivefunctionLogreg_alloc(int nClasses, int nFeatures);

// predict (flatParameters : Vector) (newX : Vector) -> predictions : Vector
extern void         ObjectivefunctionLogreg_predict(ObjectivefunctionLogreg* pObjectivefunctionLogreg, 
                                        Vector*      pFlatParameters,
                                        Vector*      pNewX, 
                                        Vector*      pPredictions) ;

// lossGradient (flatParameters : Vector) (x : Vector) (y : double) --> loss : double, gradient : Vector
// accumulate the gradient so that mini-batches can be used
// if using mini batches, caller will want to sum up the losses and perhaps average
// the losses and gradients over the size of the batch
extern void         ObjectivefunctionLogreg_lossGradient(ObjectivefunctionLogreg* pObjectivefunction, 
                                             Vector*      pFlatParameters,
                                             Vector*      pX, 
                                             double       pY, 
                                             double*      pLoss,          // loss
                                             Vector*      pAccGradient);  // accumulate gradient here (for batch algos)

// flatParametersSize --> size : int
extern int          ObjectivefunctionLogreg_flatParametersSize(ObjectivefunctionLogreg* pObjectivefunction);


#endif
