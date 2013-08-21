// ModuleLinear.h

#ifndef MODULELINEAR_H
#define MODULELINEAR_H

#define T ModuleLinear_T

typedef struct T *T;

struct ModuleLinear_T {

};

extern T    ModuleLinear_new();
extern void ModuleLinear_free(T *moduleLinearP);
extern T    ModuleLinear_clone(T module); // return deep copy

// return output given input
extern Tensor_T ModuleLinear_forward(T module, const Tensor_T input);


// compute gradients of the module wrt its own params and own inputs
// return gradInput
// set gradOutput
// accumulate the gradOutput
// NOTE: input must be the same as last call to forward
extern void ModuleLinear_backward(T module, 
                                  const Tensor_T input, 
                                  Tensor_T gradOutput);


extern void ModuleLinear_zeroGradParameters(T module);

// parameters = parameters - learningRate * gradients_wrt_parameters
extern void ModuleLinear_updateParameters(T module, double learningRate);

// share parameters of self with other modules
extern void ModuleLinear_share(T self, ...);

// return state variables
extern Tensor_T ModuleLinear_output(T module); // return last output
extern Tensor_T ModuleLinear_gradInput(T module);
extern Tensor_T ModuleLinear_weights(); // return weights
// return gradients of energy wrt learnable parameters
extern Tensor_T ModuleLinear_gradWeights(); 

#undef T
#endif
