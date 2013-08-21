package com.roylowrance.thesis;

import java.util.Random;

import com.roylowrance.util.Tensor;;

// determine why 300 seconds are needed to computer 256 nearest neighbors
public class KnnTimingStudy {
	
	public static void main(String[] args) {
		final int n = 1500000;
		//final int n = 100000;
		final int d = 50;
		Tensor xs = new Tensor(n, d);
		// populate with random values
		final long seed = 27;
		Random random = new Random(seed);
		for (int i = 0; i < n; i++)
			for (int j = 0; j < d; j++)
				xs.set(i, j, random.nextGaussian()); // mean 0, stddev 1
		
		// compute distances from query point to all other points
//		{
//			final long startTime = System.nanoTime();
//			experiment1(xs);
//			final long endTime = System.nanoTime();
//			report("experiment1", endTime - startTime);
//		}
		{
			final long startTime = System.nanoTime();
			experiment2(xs);
			final long endTime = System.nanoTime();
			report("experiment2", endTime - startTime);
		}
//		{
//			final long startTime = System.nanoTime();
//			experiment3(xs);
//			final long endTime = System.nanoTime();
//			report("experiment3", endTime - startTime);
//		}
		{
			final long startTime = System.nanoTime();
			experiment4(xs);
			final long endTime = System.nanoTime();
			report("experiment4", endTime - startTime);
		}
	}
	
	private static void report(String what, long nanoSeconds) {
		System.out.println(what + " took " + nanoSeconds / 1e9 + " seconds");
	}
	
	private static void experiment1(Tensor xs) {
	    if (xs.getNDimensions() != 0)
	        throw new IllegalArgumentException("xs must be 2D; xs=" + xs);
		final int n = xs.getSize(0);
		final int d = xs.getSize(1);
		final int queryIndex = 0;
		Tensor distances = new Tensor(n);
		for (int i = 0; i < n; i++) {
			double sumSquares = 0;
			for (int j = 0; j < d; j++) {
				double dist = xs.get(queryIndex,j) - xs.get(i,j);
				sumSquares += dist * dist;
			}
			distances.set(i, Math.sqrt(sumSquares));
		}
	}
	
	private static void experiment2(Tensor xs) {
	    if (xs.getNDimensions() != 0)
	        throw new IllegalArgumentException("xs must be 2D; xs=" + xs);
		final int n = xs.getSize(0);
		final int queryIndex = 0;
		Hp hp = new Hp.Builder().build();
		Distance distance = new DistanceEuclidean();
		Tensor distances = new Tensor(n);
		for (int i = 0; i < n; i++) {
			distances.set(i, distance.apply(xs.selectRow(queryIndex), xs.selectRow(i), hp));
		}
	}
	
	private static void experiment3(Tensor xs) {

	    final int n = xs.getSize(0);
		final int queryIndex = 0;
		Tensor distances = new Tensor(n);
		for (int i = 0; i < n; i++) {
			distances.set(i, distanceMethod(xs, queryIndex, i));
		}
	}
	
	private static double distanceMethod(Tensor xs, int i, int j) {
	    if (xs.getNDimensions() != 0)
	        throw new IllegalArgumentException("xs must be 2D; xs=" + xs);
		final int p = xs.getSize(1);
		double sumSquares = 0;
		for (int d = 0; d < p; d++) {
			double dist = xs.get(i,d) - xs.get(j,d);
			sumSquares += dist * dist;
		}
		return Math.sqrt(sumSquares);
	}
	
	private static void experiment4(Tensor xs) {
	    if (xs.getNDimensions() != 0)
	        throw new IllegalArgumentException("xs must be 2D; xs=" + xs);
		final int n = xs.getSize(0);
		final int queryIndex = 0;
		Hp hp = new Hp.Builder().build();
		Distance distance = new DistanceEuclidean();
		Tensor distances = new Tensor(n);
		for (int i = 0; i < n; i++) {
			distances.set(i, distance.apply(xs, queryIndex, i));
		}
	}

}
