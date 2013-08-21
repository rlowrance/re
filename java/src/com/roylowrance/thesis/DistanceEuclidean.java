package com.roylowrance.thesis;

import com.roylowrance.util.Tensor;

// functor to calculate Euclidean distance
public class DistanceEuclidean implements Distance {

	public DistanceEuclidean() {
		super();
	}

	// return Euclidean distance from points a and b
	// hyperparameters are not used
	@Override
	public double apply(Tensor t1a, Tensor t1b, Hp hp) {
	    if (t1a.getNDimensions() != 1)
	        throw new IllegalArgumentException("t1a must be 1D; a=" + t1a);
	    if (t1b.getNDimensions() != 1)
	        throw new IllegalArgumentException("t1b must be 1D; b=" + t1b);
	    
		final int aNElements= t1a.getNElements();
		if (aNElements != t1b.getNElements()) 
			throw new IllegalArgumentException("a and b must have same number of elements; a=" + t1a + " b=" + t1b);

		double sumSquaredDifferences = 0.0;
		for (int i = 0; i < aNElements; ++i) {
			final double d = t1a.get(i) - t1b.get(i);
			sumSquaredDifferences += d * d;
		}

		return Math.sqrt(sumSquaredDifferences);
	}
	
	// return Euclidean distance between two rows in idx2
	// this implementation is significantly faster than apply(Idx1,Idx2,Hp)
	@Override
	public double apply(Tensor t2, int i, int j) {
	    if (t2.getNDimensions() != 2)
	        throw new IllegalArgumentException("t2 must be 2D; t2=" + t2);
	    
		final int numberRows = t2.getSize(0);

		if (i < 0 || i >= numberRows)
			throw new IllegalArgumentException("i out of range; i=" + i + " t2=" + t2);
		if (j < 0 || j >= numberRows)
			throw new IllegalArgumentException("j out of range; j=" + j + " t2=" + t2);
		
		final int dimensions = t2.getSize(1);
		double sumSquaredDifferences = 0;
		for (int d = 0; d < dimensions; d++) {
			final double difference = t2.get(i,d) - t2.get(j,d);
			sumSquaredDifferences += difference * difference;
		}
		return Math.sqrt(sumSquaredDifferences);
	}
	
	// return Euclidean distance between a row in a tensor and a tensor
	@Override
	public double apply(Tensor xs, int rowIndex, Tensor query) {
	    IAE.notNull(xs, "xs");
	    IAE.nonNegative(rowIndex, "rowIndex");
	    IAE.lessEqual(rowIndex, xs.getSize(0), "rowIndex", "number of rows in xs");
	    IAE.notNull(query, "query");
	    IAE.equals(query.getSize(0), xs.getSize(1), "length of query = size of xs row", "query", "number column in xs");
	    
	    final int dimensions = xs.getSize(1);
	    double sumSquaredDifferences = 0;
	    for (int d = 0; d < dimensions; d++) {
	        final double difference = xs.get(rowIndex, d) - query.get(d);
	        sumSquaredDifferences += difference * difference;
	    }
	    return Math.sqrt(sumSquaredDifferences);
	}
}
