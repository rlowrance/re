package com.roylowrance.util;

import java.util.ArrayList;

// operations on ArrayLists
public class ArrayListOps {
	
	public static class StandardizeResult {
		private ArrayList<Float> values;
		double mean;
		double standardDeviation;
		
		// constructor
		public StandardizeResult(ArrayList<Float> values, double mean, double standardDeviation) {
			this.values = values;
			this.mean = mean;
			this.standardDeviation = standardDeviation;
		}
		
		// accessors
		public ArrayList<Float> getValues() {
			return values;
		}
		public double getMean() {
			return mean;
		}
		public double getStandardDeviation() {
			return standardDeviation;
		}
	}
	
	// standardize by subtracting mean and dividing by standard deviation
	// a standardized variable is also called a "standard score" or "z-score"
	// return: standardized vector, mean, standard deviation
	// throw if NaN results
	// - NaN will result if all values are the same, as then the stddev is 0
	public static StandardizeResult standardize(ArrayList<Float> vector) {
		final boolean logging = false;
		Log log = new Log("ArrayListOps.standardize", logging);
		Tuple2<Double,Double> tuple = meanStandardDeviation(vector);
		double mean = tuple.getElement1();
		double standardDeviation = tuple.getElement2();
		if (logging)
			log.println("mean:" + mean + " standardDeviation:" + standardDeviation);
		if (standardDeviation == 0.0) {
			throw new RuntimeException("attempting to standardize when standard deviation is zero; possible all values are equal");
		}
		
		ArrayList<Float> result = new ArrayList<Float>(vector.size());
		for (int i = 0; i < vector.size(); i++) {
			Double value = (vector.get(i) - mean) / standardDeviation;
			result.add(value.floatValue());
			if (logging)
				log.println("result[" + i + "]:" + value.floatValue());
		}
		
		return new StandardizeResult(result, mean, standardDeviation);
	}
	
	// determine mean and standard deviation
	// NOTE: keep the computations in double precision for accuracy
	private static Tuple2<Double,Double> meanStandardDeviation(ArrayList<Float> vector) {
		// this is a one-pass method as described in
		// http://en.wikipedia.org/wiki/Standard_deviation
		Double a = 0.0;
		Double q = 0.0;
		for (int n = 0; n < vector.size(); n++) {
			// A_n = A_{n-1} + (x(n) - A_{n-1})/n
			Double priorA = a;
			Double priorQ = q;
			Double xn = (double) vector.get(n);
			a = priorA + (xn - priorA)/ (n + 1.0);
			// Q_n = Q_{n-1} + (x(n) - a_{n-1})(x(n) - a_n)
			q = priorQ + (xn - priorA) * (xn - a);
		}
		Double mean = a;
		Double standardDeviation = Math.sqrt(q / vector.size());
		return new Tuple2<Double,Double>(mean, standardDeviation);
	}
	
	// determine natural logarithm
	public static ArrayList<Float> log(ArrayList<Float> vector) {
		ArrayList<Float> result = new ArrayList<Float>();
		for (Float number : vector){
			Double dLog = Math.log(Double.valueOf(number));
			Float fLog = dLog.floatValue();
			result.add(fLog);
		}
		return result;
	}
	
}
