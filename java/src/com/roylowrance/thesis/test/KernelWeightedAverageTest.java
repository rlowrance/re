package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import java.util.ArrayList;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.Distance;
import com.roylowrance.thesis.DistanceEuclidean;
import com.roylowrance.thesis.Kernel;
import com.roylowrance.thesis.KernelGaussian;
import com.roylowrance.thesis.WeightedAverage;
import com.roylowrance.thesis.Hp;

import com.roylowrance.util.Tensor;

public class KernelWeightedAverageTest {
	Tensor locations;
	Tensor query1;
	Tensor query2;
	Tensor ys;

	private Tensor makeIdx(Double... values) {
		Tensor result = new Tensor(values.length);
		for (int index = 0; index < values.length; index++)
			result.set(index, values[index]);
		return result;
	}

	private void setRow(Tensor inout, int rowIndex, Tensor in) {
		for (int columnIndex = 0; columnIndex < in.getSize(0); columnIndex++)
			inout.set(rowIndex, columnIndex, in.get(columnIndex));
	}

	@Before
	public void setUp() throws Exception {
		// setup points at the corners of the 2D unit square
		{
			Tensor idx = new Tensor(5, 2);
			setRow(idx, 0, makeIdx(0.0, 0.0));
			setRow(idx, 1, makeIdx(0.0, 1.0));
			setRow(idx, 2, makeIdx(1.0, 0.0));
			setRow(idx, 3, makeIdx(1.0, 1.0));
			setRow(idx, 4, makeIdx(0.0, 0.0));
			locations = idx;
		}

		// setup ys
		{
			Tensor idx = new Tensor(5);
			idx.set(0, 1.0);
			idx.set(1, 2.0);
			idx.set(2, 3.0);
			idx.set(3, 4.0);
			idx.set(4, 0.0); // 0 value, so no effect on outcome
			ys = idx;
		}
	}

	// test kernel weight relative to origin
	private void runKernelGaussianWavg(double expected, Tensor query,	double bandwidth) {
	    final int queryIndex = 4;
	    setRow(locations, queryIndex, query);
		Hp hp = new Hp.Builder().bandwidth(bandwidth).build();
		Distance distance = new DistanceEuclidean();
		Kernel kernel = new KernelGaussian();
		double weightedAvg = WeightedAverage.apply(distance, kernel, hp, locations, queryIndex, ys);
		assertEquals(expected, weightedAvg, 1e-2);
	}

	@Test
	public void testKwavg() {
		runKernelGaussianWavg(2.132623, makeIdx(0.0, 0.0), 2.0); 
		runKernelGaussianWavg(2.33, makeIdx(0.1, 0.3), 3);
	}

}
