package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// functor for the per-sample loss function
public interface LossFunction {
    
    // the user has setup a 2D Tensor examples such that
    // example[i:] is the i-th example
    public double apply(Tensor weights, int exampleIndex);

}
