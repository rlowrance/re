package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// functor to provide a kernel
// A kernel assigns a weight to each sample point such that the
// weights decrease as the distance from a query point increases
public interface Kernel {

	public double apply(Distance distance, Tensor queryPoint, Tensor samplePoint, Hp hp);
	public double apply(Distance distance, Tensor tensor2D, int i, int j, Hp hp); // smoothed distance from idx[i,:] to idx[j,:]

}
