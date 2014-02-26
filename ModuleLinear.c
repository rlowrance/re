// ModuleLinear.c
// TODO
// 1. Rework to use GSL vectors and matrices and the gsl library for outer product, mantrix multipliation.
// 2. Maybe create type Tensor that holds either a gsl vector or a gsl matrix.
// 3. Maybe extend input type from vector to vector or matrix.

#include "ModuleLinear.h"

// calloc
ModuleLinear* ModuleLinear_calloc(
        int inputSize,
        int outputSize
        ) {
    // check args
    assert(inputSize > 0);
    assert(outputSize > 0);

    ModuleLinear* self = calloc(sizeof(ModuleLinear));
    assert(self != NULL);

    self -> inputSize = inputSize;
    self -> outputSize = outputSize;
    self -> gradientSize = outputSize * (inputSize + 1);

    self -> bBias = Vector_calloc(outputSize);
    self -> bWeight = Matrix_calloc(outputSize, inputSize);
    self -> pOutput = Matrix_calloc(outputSize, inputSize);
    self -> pGradBias = Vector_calloc(outputSize);
    self -> pGradWeight = Vector_calloc(outputSize, inputSize);

    return self;
}

// updateOutput
// nn.Linear.updateOutput(input) --> output
void ModuleLinear_updateOutput(
        ModuleLinear* pSelf,          // in
        Vector*       pInput,         // in
        Vector*       pOutput) {      // out
    // check args
    assert(pSelf != NULL);
    assert(pInput != NULL);
    assert(pOutput != NULL);
    
    assert(pInput -> nElements == pSelf -> inputSize);
    assert(pOutput -> nElements == 1);


    // output scalar = bias + \sum_d input[d] * weight[d]
    // self.output:resize(nframe, nunit)
    // self.output:zero();addr(1, input.new(nframe):fill(1), self.bias)
    Vector* pOnes = Vector_alloc(outputSize);
    Vector_fill(pOnes, 1.0);
    Vector_addr(1, pOnes, pSelf -> pBias, pSelf -> pVectorOutput);

    // self.output:addmv(1, self.weight, input)
    Matrix_addmv(1, pWeight, pInput, pSelf -> pOutput);

    // return self.output
    pOutput = pSelf -> pOutput;
}

// updateGradInput 
// nn.Linear.updateGradInput(input, gradOutput) --> gradInput
void ModuleLinear_updateGradInput(
        ModuleLinear* pSelf,           // in
        Vector*       pInput,          // in
        Vector*       pGradInput) {    // out
    // check args
    assert(pSelf != NULL);
    assert(pInput != NULL);
    assert(pGradOutput != NULL);

    int inputSize = pSelf -> inputSize;
    int outputSize = pSelf -> outputSize;
    assert(pInput -> nElements = inputSize);
    assert(pGradOutput -> nElements == outputSize);
    
    // self.gradInput:addmv(0, 1, self.weight:t(), gradOutput)
    Matrix* pWeightT;
    Matrix_transpose(self->pWeight, pWeightT);  // weightT = weight:t()
    Matrix_addmv(1, pWeightT, pGradOutput, pSelf -> pGradInput); 
    Matrix_free(pWeightT);

    // return self.gradInput
    pGradInput = self -> pGradInput;
}

// accGradParameters
// nn.Linear.accGradParameters(input, gradOutput, scale) --> nil (but update state)
void ModuleLinear_accGradParameters(
        ModuleLinear* pSelf,         // in
        Vector*       pInput,        // in
        Vector*       pGradOutput,   // in
        double        scale) {       // in
    // check args
    assert(pSelf != NULL);
    assert(pInput != NULL);
    assert(pGradOutput != NULL);

    int inputSize = pSelf -> inputSize;
    int outputSize = pSelf -> outputSize;
    int gradientSize = pSelf -> gradientSize;
    assert(pInput -> nElements == inputSize);
    assert(pGradOutput -> nElements == gradientSize);

    // self.gradWeight:addr(scale, gradOutput, input)
    Vector_addr(scale, pSelf->gradOutput, pInput, pSelf -> pGradWeight);

    // self.gradBias:add(scale, gradOutput)
    Vector_add(scale, pSelf -> gradOutput, pSelf -> gradBias, pSelf -> gradBias);

    // return nil
    return;
}

// getGradParameters
// return copy of {self.gradBias, self.gradWeight}
void ModuleLinear_getGradParameters(
    ModuleLinear* pSelf,                              // in
    Vector*       pGradParameters) {                  // out
    // check args
    assert(pSelf != NULL);
    assert(pGradParameters != NULL);

    int gradientSize = pSelf -> gradientSize;
    assert(pGradParameters -> nElements == gradientSize);

    int outputSize = pSelf -> outputSize;
    int inputSize = pSelf -> inputSize;

    // copy grad bias and grad weight values to output
    int cursor = 0;
    for (int classIndex = 0; classIndex < outputSize; classIndex++) {
        Vector_set(pGradParameters, cursor, Vector_get(pSelf -> pGradBias, 
                                                       classIndex));
        cursor++;
        for (int featureIndex = 0; featureIndex < inputSize; featureIndex++) {
            Vector_set(pGradParameters, cursor, Matrix_get(pSelf -> pGradWeight,
                                                           featureIndex,
                                                           classIndex));
            cursor++;
    }
}



// getFlatParameters
// return copy of {self.bias, self.weight}
void ModuleLinear_getFlatParameters(
        ModuleLinear* pSelf,                          // in
        Vector*       pFlatParameters) {              // out
    // check args
    assert(pSelf != NULL);
    assert(pFlatParameters != NULL);

    int gradientSize = pSelf -> gradientSize;
    assert(pFlatParameters -> nElements == gradientSize);

    int outputSize = pSelf -> outputSize;
    int inputSize = pSelf -> inputSize;

    // copy bias and weights to output
    int cursor = 0;
    for (int classIndex = 0; classIndex < outputSize; classIndex++) {
        Vector_set(pFlatParmaters,
                   cursor,
                   Vector_get(pSelf -> pBias,
                              classIndex));
        cursor++;
        for (int featureIndex = 0; featureIndex < inputSize; featureIndex++) {
            Vector_set(pFlatParameters,
                       cursor,
                       Matrix_get(pSelf -> pGradWeight,
                                  featureIndex,
                                  classIndex));
            cursor++;
        }
    }
}


// setFlatParameters
// mutate self.bias and self.weight
void ModuleLinear_setFlatParameters(
        ModuleLinear* pSelf,                 // in
        Vector*       pFlatParameters) {     // in
    // check args
    assert(pSelf != NULL);
    assert(pFlatParameters != NULL);

    int gradientSize = pSelf -> gradientSize;
    assert(pFlatParameters -> nElement == gradientSize);

    // copy flat parameters into grad and weight
    int cursor = 0;
    for (int classIndex = 0; classIndex < outputSize; classIndex++) {
        Vector_set(self -> pBias,
                   classIndex,
                   Vector_get(pFlatParamaters,
                              cursor));
        cursor++;
        for (int featureIndex = 0; featureIndex < inputSize; featureIndex++) {
            Vector_set(self -> pWeight,
                       featureIndex,
                       classIndex,
                       Vector_get(pFlatParameters,
                                  cursor));
            cursor++;
        }
    }
}
