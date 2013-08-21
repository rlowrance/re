package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// functor for the gradient of a loss function: weights x example --> directions
public interface LossGradient {
    
    // the user has setup a Tensor examples in which examples[i:] is the i-th 
    // example. Rather than construct a Tensor, this API passes the index i.
    public Tensor apply(Tensor weights, int exampleIndex);
    
}
