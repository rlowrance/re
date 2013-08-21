package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

import com.roylowrance.util.Log;

// functor to implement Gaussian kernel
// ref: Bishop p. 296
public class KernelGaussian implements Kernel {

	// return Guassian kernel-weighted distance between two points using the
	// distance function
	// hyperparmeter contains SIGMA value to use (called bandwidth)
	@Override
	public double apply(Distance distance, Tensor queryPoint, Tensor samplePoint, Hp hp) {
		final boolean logging = false;
		Log log = new Log("KernelGaussian.weight", logging);
		if (queryPoint == null)
			throw new IllegalArgumentException("queryPoint is null");
		if (samplePoint == null)
			throw new IllegalArgumentException("samplePoint is null");
		if (hp == null)
			throw new IllegalArgumentException("hp is null");

		final Double varianceTimes2 = hp.getBandwidth();
		if (varianceTimes2 == null)
			throw new IllegalArgumentException(
					"value of hyperparameter bandwidth is null");

		final double d = distance.apply(queryPoint, samplePoint, hp);
		double result = Math.exp(-(d * d) / varianceTimes2);
		if (logging) {
			log.println("a:" + queryPoint);
			log.println("b:" + samplePoint);
			log.println("distance:" + distance + " variance:" + varianceTimes2 + " weight:" + result);
		}
		return result;
	}
	
	// return smoothed distance between two rows in an idx2
	public double apply(Distance distance, Tensor tensor2D, int i, int j, Hp hp) {
	    final boolean logging = false;
	    Log log = new Log("KernelGaussian.apply", logging);
	    
	    // validate tensor2D
	    if (tensor2D == null)
	        throw new IllegalArgumentException("tensor2D is null; tensor2D=" + tensor2D);
	    if (tensor2D.getNDimensions() != 2)
	        throw new IllegalArgumentException("tensor2D must have 2 dimensions; tensor2D=" + tensor2D);
	    
	    // validate i and j
	    final int numberRows = tensor2D.getSize(0);
	    if (i < 0)
	        throw new IllegalArgumentException("i is negative");
	    if (i >= numberRows)
	        throw new IllegalArgumentException("i (" + i + ") not less than numberRows(" + numberRows +")");
	    if (j < 0)
	        throw new IllegalArgumentException("j is negative");
	    if (j >= numberRows)
	        throw new IllegalArgumentException("j (" + j + ") not less than numberRows(" + numberRows +")");
	    
	    final Double varianceTimes2 = hp.getBandwidth();
	    if (varianceTimes2 == null)
	        throw new IllegalArgumentException("bandwidth is null");
	    
	    final double d = distance.apply(tensor2D, i, j);
	    final double result = Math.exp(- (d * d) / varianceTimes2);
	    
	    if (logging)
	        log.println("d:" + d + " weight:" + result);
	    return result;
	}
}
