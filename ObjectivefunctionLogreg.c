// ObjectivefunctionLogreg.c
// stub version with all the calculations
// for use in timing tests
//

#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>

#include "Matrix.h"
#include "ObjectivefunctionLogreg.h"
#include "Vector.h"

// constructor
ObjectivefunctionLogreg* ObjectivefunctionLogreg_alloc(int nClasses, int nFeatures) {
    assert(nClasses > 1);
    assert(nFeatures > 0);

    ObjectivefunctionLogreg* self = malloc(sizeof(ObjectivefunctionLogreg));
    assert(self != NULL);

    return self;
}

// structure the flattened parameters
// allocate and set bias and weight
typedef struct {
    Vector* pBias;
    Matrix* pWeight;
} biasWeight;

biasWeight structure(ObjectivefunctionLogreg* pSelf, Vector* pFlatParameters) {
    int nClasses = pSelf -> nClasses;
    int nFeatures = pSelf -> nFeatures;

    Vector* pBias = Vector_alloc(nClasses);
    Matrix* pWeight = Matrix_alloc(nClasses, nFeatures);

    int cursor = 0;
    for (int classIndex = 0; classIndex < nClasses; classIndex++) {
        Vector_set(pBias, classIndex, Vector_get(pFlatParameters, cursor));
        cursor++;
        for (int featureIndex = 0; featureIndex < nFeatures; featureIndex++) {
            Matrix_set(pWeight, classIndex, featureIndex, Vector_get(pFlatParameters, cursor));
            cursor++;
        }
    }

    // build and return 2-field structure
    biasWeight bw;
    bw.pBias = pBias;
    bw.pWeight = pWeight;
    return bw;
}

// predict
void ObjectivefunctionLogreg_predict(ObjectivefunctionLogreg* pSelf, 
                                     Vector*                  pFlatParameters,
                                     Vector*                  pNew,
                                     Vector*                  pPrediction) {  // out
    assert(pSelf != NULL);
    assert(pFlatParameters != NULL);
    assert(pNew != NULL);
    assert(pPrediction != NULL);
    
    int nClasses = pSelf -> nClasses;
    int nFeatures = pSelf -> nFeatures;
    assert(pFlatParameters -> nElements == nClasses * (nFeatures + 1));
    assert(pNew -> nElements == nFeatures);
    assert(pPrediction -> nElements == nClasses);
    

    // structure flat parameters into vector of biases and matrix of weights
    biasWeight bw = structure(pSelf, pFlatParameters);
    Vector* pBias = bw.pBias;
    Matrix* pWeight = bw.pWeight;

    // compute unnormalized probabilities
    // MAYBE: by-pass vector_get and matrix_get by directly accessing elements
    for (int classIndex = 0; classIndex < nClasses; classIndex++) {
        double bias = Vector_get(pBias, classIndex);
        double dotProduct = 0.0;
        for (int featureIndex = 0; featureIndex < nFeatures; featureIndex++) {
            double left = Vector_get(pNew, featureIndex);
            double right = Matrix_get(pWeight, classIndex, featureIndex);
            dotProduct = dotProduct + left * right;
        }
        Vector_set(pPrediction, classIndex, bias + dotProduct);
    }
    
 
    // normalize the probabilities and take logs
    double sum = 0.0;
    for (int classIndex = 0; classIndex < nClasses; classIndex++) {
        sum = sum + Vector_get(pPrediction, classIndex);
    }

    for (int classIndex = 0; classIndex < nClasses; classIndex++) {
        double probability = Vector_get(pPrediction, classIndex) / sum;
        double logProbability = log(probability);
        Vector_set(pPrediction, classIndex, logProbability);
    }

    // free temporary memory
    Vector_free(pBias);
    Matrix_free(pWeight);
}

// lossGradient
void ObjectivefunctionLogreg_lossGradient(ObjectivefunctionLogreg* pObjectivefunction,
                                          Vector*                  pFlatparameters,
                                          Vector*                  pX,
                                          double                   y,
                                          double*                  pLoss,   // out
                                          Vector*                  pAccGradient) { // out

    assert(pObjectivefunction != NULL);
    assert(pFlatparameters != NULL);
    assert(pX != NULL);
    assert(pLoss != NULL);
    assert(pAccGradient != NULL);

    int nClasses = pObjectivefunction -> nClasses;
    int nFeatures = pObjectivefunction -> nFeatures;
    int gradientSize = nClasses * (nFeatures + 1);

    assert(pFlatparameters -> nElements == gradientSize);
    assert(pX -> nElements == nFeatures);
    assert(pAccGradient -> nElements == gradientSize);


    // structure flat parameters into vector of biases and matrix of weights
    biasWeight bw = structure(pObjectivefunction, pFlatparameters);
    Vector* pBias = bw.pBias;
    Matrix* pWeight = bw.pWeight;
    
    // make the prediction
    Vector* pPrediction = Vector_alloc(nClasses);
    ObjectivefunctionLogreg_predict(pObjectivefunction, pFlatparameters, pX, pPrediction);

    // determine the loss

    // dLoss_output
    // dNLL_output
    // gradientLinear_output

    // free temporary memory
    Vector_free(pBias);
    Matrix_free(pWeight);
    // free temporary memory
    Vector_free(pBias);
    Matrix_free(pWeight);
    Vector_free(pPrediction);
}
