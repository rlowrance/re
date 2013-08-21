package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// functor to compute distance
public interface Distance {
    
    // The second two version exist as optimizations designed to avoid construction of a Tensor
    // Perhaps this was not wise
    // On 2012-04-02 it seems that only the 3rd interface is used, so maybe delete the other two

	public double apply(Tensor a, Tensor b, Hp hp);
	public double apply(Tensor idx, int i, int j); // distance from idx[i,:] to idx[j,:]
	public double apply(Tensor xs, int rowIndex, Tensor query); // distance from xs[rowIndex,:] to query

}
