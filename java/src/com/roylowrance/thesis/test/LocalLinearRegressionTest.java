package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Tensor;

import com.roylowrance.thesis.DistanceEuclidean;
import com.roylowrance.thesis.KernelGaussian;
import com.roylowrance.thesis.Hp;
import com.roylowrance.thesis.LocalLinearRegression;

public class LocalLinearRegressionTest {

	@Before
	public void setUp() throws Exception {
	}

	@Test
	public void testApply() {
		// test d = 3
		final int d = 3;
		final int n = 4;

		double[] queryLocationArray = { 1, 2, 3 };
		Tensor queryLocation = new Tensor(queryLocationArray);

		double[][] locationsArray = { { 1, 2, 6 }, { 1, 0, 3 }, { 0, 2, 3 },
				{ 2, 1, 4 } };
		Tensor locations = Tensor.newInstanceFromArray(locationsArray);

		double[] ysArray = { 0, 24, 9, 14, 15 };
		Tensor ys = Tensor.newInstanceFromArray(ysArray);

		double answer = LocalLinearRegression.apply(new DistanceEuclidean(),
				new KernelGaussian(), new Hp.Builder().bandwidth(1.0).build(),
				locations, queryLocation, ys);
	}
}
