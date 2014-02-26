// ModuleLinear.h
// 1D implementation of nn.Linear.lua

#ifndef MODULELINEAR_H
#define MODULELINEAR_H

#include <stdlib.h>

#include "Matrix.h"
#include "Vector.h"

typedef {
    int     inputSize;
    int     outputSize;
    int     gradientSize;
    Vector* pBias;
    Matrix* pWeight;
    Matrix* pOutput;
    Vector* pGradBias;
    Matrix* pGradWeight;
    Vector* pGradInput;   // type?
} ModuleLinear;

// alloc and free
extern ModuleLinear* ModuleLinear_calloc(
        int inputSize,
        int outputSize);

extern void ModuleLinear_free(
        ModuleLinear* self);

// forward
extern void ModuleLinear_updateOutput(
        ModuleLinear* pSelf,
        Vector*       pInput,
        Vector*       pOutput);

// gradInput
extern void ModuleLinear_gradInput(
        ModuleLinear* pSelf,
        Vector*       pGradInput);

// accGradParameters
extern void ModuleLinear_accGradParameters(
        ModuleLinear* pSelf,
        Vector*       pInput,
        Vector*       pGradInput,
        double        scale);

#endif
