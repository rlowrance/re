package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

import com.roylowrance.util.Log;

// functor to implement Epanechnikovkernel
// ref: Hastie-02 p 167
public class KernelEpanechnikov implements Kernel {

	// return Guassian kernel-weighted distance between two points using the
	// distance function
	// hyperparmeter contains bandwidth value to use (called lambda in hastie-02)
	@Override
	public double apply(Distance distance, Tensor a, Tensor b, Hp hp) {
		final boolean logging = false;
		Log log = new Log("KernelGaussian.weight", logging);
		if (a == null)
			throw new IllegalArgumentException("queryPoint is null");
		if (b == null)
			throw new IllegalArgumentException("samplePoint is null");
		
		if (hp == null)
			throw new IllegalArgumentException("hp is null");
		Double lambda = hp.getBandwidth();
		if (lambda == null)
		    throw new IllegalArgumentException("bandwidth is missing");

		double result = d(distance.apply(a, b, hp) / lambda);
		if (logging) {
			log.println("a:" + a);
			log.println("b:" + b);
			log.println("distance:" + distance + " lambda:" + lambda + " weight:" + result);
		}
		return result;
	}
	
	// return smoothed distance between two rows in an idx2
	public double apply(Distance distance, Tensor tensor2D, int i, int j, Hp hp) {
	    final boolean logging = false;
	    Log log = new Log("KernelGaussian.apply", logging);
	    if (tensor2D == null)
	        throw new IllegalArgumentException("idx is null");
	    if (tensor2D.getNDimensions() != 2)
	        throw new IllegalArgumentException("tensor2D must have 2 dimensions; tensor2D=" + tensor2D);
	    
	    final int numberRows = tensor2D.getSize(0);
	    if (i < 0)
	        throw new IllegalArgumentException("i is negative");
	    if (i >= numberRows)
	        throw new IllegalArgumentException("i (" + i + ") not less than numberRows(" + numberRows +")");
	    if (j < 0)
	        throw new IllegalArgumentException("j is negative");
	    if (j >= numberRows)
	        throw new IllegalArgumentException("j (" + j + ") not less than numberRows(" + numberRows +")");
	    
	    if (hp == null)
	        throw new IllegalArgumentException("hp is null");
	    Double lambda = hp.getBandwidth();
	    if (lambda == null)
	        throw new IllegalArgumentException("bandwidth is missing");

	    
	    final double result = d(distance.apply(tensor2D, i, j) / lambda);
	    
	    if (logging)
	        log.println("weight:" + result);
	    return result;
	}
	
	// see hastie-02 p 167
	private double d(double t) {
	    if (Math.abs(t) <= 1)
	        return 0.75 * (1 - t * t);
	    else
	        return 0;
	}
}
