package com.roylowrance.thesis;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.TreeMap;

import com.roylowrance.util.Tensor;
import com.roylowrance.util.Log;
import com.roylowrance.util.RandomGenerate;
import com.roylowrance.util.Report;
import com.roylowrance.util.Tuple2;

/**
 * Functor to estimate a real value using kernel-weighted average
 * 
 * See Hastie-01 pp 165-168 for details on one-dimension kernel smoothers
 * 
 * @author roy
 * 
 */
public class LocalLinearRegression {

	/**
	 * Return yHat, the estimated y, the results of a local linear regression.
	 * 
	 * b(x)^T = (1,x) B is N x 2 regression matrix with ith row b(x_i)^T W is N
	 * x N diagonal matrix with ith element K_lambda(x0,x1)
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
	 * @return yHat := b(x)^T (B^T W B)^-1 B^T W y = b(x)^T betaHat
	 */
	public static double apply(Distance distance, Kernel kernel, Hp hp, // use
																		// whatever
																		// the
																		// Distance
																		// and
																		// Kernel
																		// use,
																		// nothing
																		// more
			Tensor locations, Tensor queryLocation, Tensor ys) {
		final boolean logging = true;
		Log log = new Log("LocalLinearRegression.apply", logging);
		if (locations.getNDimensions() != 2)
		    throw new IllegalArgumentException("locations must be 2D; locations=" + locations);
		if (queryLocation.getNDimensions() != 1)
		    throw new IllegalArgumentException("queryLocation must be 1D; queryLocation=" + queryLocation);
		if (ys.getNDimensions() != 1)
		    throw new IllegalArgumentException("ys must be 1D; ys=" + ys);

		final int n = locations.getSize(0);
		final int d = locations.getSize(1);
		final int dp1 = d + 1;

		// initial the diagonal matrix w that contains the weights
		// since the off-diagonal entries are 0, store it in an idx1
		// TODO: use Idx2DoubleDiagonal
		Idx2Diagonal weights = new Idx2Diagonal(n, n);
		for (int index = 0; index < n; index++) {
			weights.set(
					index,
					index,
					kernel.apply(distance, queryLocation,
							locations.selectRow(index), hp));
		}
		if (logging && false) {
			log.println("weights:" + weights);
		}

		// build B
		// the ith row of B is [1, x^i]
		Tensor b = new Tensor(n, dp1);
		for (int rowIndex = 0; rowIndex < b.getSize(0); rowIndex++) {
			b.set(rowIndex, 0, 1.0);
			for (int columnIndex = 1; columnIndex < b.getSize(1); columnIndex++)
				b.set(rowIndex, columnIndex,
						locations.get(rowIndex, columnIndex - 1));
		}
		if (logging) {
			for (int rowIndex = 0; rowIndex < n; rowIndex++)
				log.println("B[" + rowIndex + ",:]=" + b.selectRow(rowIndex));
		}

		// develop B^t W B
		Tensor bTranspose = b.transpose();
		if (logging) {
			for (int rowIndex = 0; rowIndex < n; rowIndex++)
				log.println("bTranspose[" + rowIndex + ",:]="
						+ bTranspose.selectRow(rowIndex));
		}

		Tensor btw = new Tensor(dp1, n);
		// TODO: replace with call to IdxOps.multiply
		// ((B^t W))_ij = ((B^t))_ij * weight_j
		for (int rowIndex = 0; rowIndex < bTranspose.getSize(0); rowIndex++)
			for (int columnIndex = 0; columnIndex < bTranspose.getSize(1); columnIndex++) {
				log.println("bTranspose[" + rowIndex + "," + columnIndex + "]="
						+ bTranspose.get(rowIndex, columnIndex));
				log.println("weights:" + weights.get(columnIndex, columnIndex));
				btw.set(rowIndex,
						columnIndex,
						bTranspose.get(rowIndex, columnIndex)
								* weights.get(columnIndex, columnIndex));
			}
		if (logging) {
			for (int rowIndex = 0; rowIndex < n; rowIndex++)
				log.println("bTransposeWeight[" + rowIndex + ",:]="
						+ btw.selectRow(rowIndex));
		}

		Tensor btwb = IdxOps.matrixMultiply(btw, b);
		if (logging) {
			for (int rowIndex = 0; rowIndex < n; rowIndex++)
				log.println("btwb[" + rowIndex + ",:]="
						+ btwb.selectRow(rowIndex));
		}

		// Develop B^T W y using the existing B^T W
		// Idx1Double btwy = IdxOps.matrixMultiply(btw, locations);
		if (true)
			throw new RuntimeException("code matrixMultiply");

		// Dev
		Tensor bq = new Tensor(dp1);
		bq.set(0, 1.0);
		for (int index = 0; index < bq.size(); index++)
			bq.set(index, (double) queryLocation.get(index));

		Tensor bqbt = IdxOps.matrixMultiply(bq, bTranspose);

		Tensor bqbtw = new Tensor(n);
		for (int index = 0; index < n; index++)
			bqbtw.set(index, weights.get(index, index) * bqbt.get(index));

		// build B^T W
		// row 1 = [w1 w2 ... wN]
		// row 2 = [w1x^1_1 w2x^2_1 ... wNX^N_1
		// row d+1 = [w1x^1_d w2x^2_d

		// OLD CODE BELOW ME
		double sumWeights = 0;
		double sumWeightedYs = 0;
		for (int rowIndex = 0; rowIndex < locations.getNumberRows(); rowIndex++) {
			Tensor trainingLocation = selectRow(locations, rowIndex);
			double weight = kernel.apply(distance, trainingLocation,
					queryLocation, hp);
			log.println("trainingLocation:" + trainingLocation + " weight:"
					+ weight);
			sumWeights += weight;
			sumWeightedYs += weight * ys.get(rowIndex);
		}
		return sumWeightedYs / sumWeights;
	}

	// return as idx1 the index'ed row
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
