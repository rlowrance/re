package com.roylowrance.thesis;

import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

/**
 * Functor to estimate a real value using kernel-weighted average
 * 
 * See Hastie-01 pp 165-168 for details on one-dimension kernel smoothers
 * 
 * @author roy
 * 
 */
public class WeightedAverage {

	/**
	 * Return yHat, the estimated y, using the kernel to weight the observatins
	 * 
	 * @param distance
	 *            distance function which depends on the hyperparamters
	 * @param kernel
	 *            kernel function which depends on the hyperparameters
	 * @param hp
	 *            hyperparameters passed to kernel function (which passes them
	 *            to distance function)
	 * @param locations
	 *            locations of comparative transactions
	 * @param queryLocation
	 *            a vector, the location for which the query is done
	 * @param ys
	 *            parallel vector to locations, the y values that are known
	 * @return yHat := (sum_i kernel(locations[i], queryLocation) * y[i]) /
	 *         sum_i kernel(locations[i], queryLocation)
	 */
	public static double apply(
	        Distance distance, 
	        Kernel kernel, 
	        Hp hp, 
			Tensor locations, 
			int queryIndex, 
			Tensor ys) {
	    final boolean logging = false;
		Log log = new Log("WeightedAverage.apply", logging);

		// yHat = (sum_i kernel(x_i, q) y_i) / (sum_i kernel(x_i, q))

		double sumWeights = 0;
		double sumWeightedYs = 0;
		for (int rowIndex = 0; rowIndex < locations.getSize(0); rowIndex++) {
		    // avoid selecting a row, as this is expensive computationally
		    if (rowIndex == queryIndex)
		        continue; // don't compare to self
			double weight = kernel.apply(distance, locations, queryIndex, rowIndex, hp);
			if (logging)
			    log.println("rowIndex:" + rowIndex + " weight:" + weight+ " y x weight:" + ys.get(rowIndex) * weight);
			sumWeights += weight;
			sumWeightedYs += weight * ys.get(rowIndex);
		}
		if (logging)
		    log.println("sumWeightedYs:" + sumWeightedYs + " sumWeights:" + sumWeights);
		return sumWeightedYs / sumWeights;
	}

	// return as 1D tensor the index'ed row
	public static Tensor selectRow(Tensor x, int rowIndex) {
	    if (x.getNDimensions() != 2)
	        throw new IllegalArgumentException("x must be 2D; x=" + x);
		final int numberColumns = x.getSize(1);
		Tensor result = new Tensor(numberColumns);
		for (int columnIndex = 0; columnIndex < numberColumns; columnIndex++)
			result.set(columnIndex, x.get(rowIndex, columnIndex));
		return result;
	}

}
