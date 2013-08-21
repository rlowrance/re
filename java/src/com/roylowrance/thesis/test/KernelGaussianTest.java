package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.Distance;
import com.roylowrance.thesis.DistanceEuclidean;
import com.roylowrance.thesis.Kernel;
import com.roylowrance.thesis.KernelGaussian;
import com.roylowrance.thesis.Hp;

import com.roylowrance.util.Tensor;

public class KernelGaussianTest {
    Tensor tensorAB;

	@Before
	public void setUp() throws Exception {
	    // setup idx version of apply
	}

	@Test
	public void testBadHp() {
		Distance d = new DistanceEuclidean();
		KernelGaussian kg = new KernelGaussian();
		Tensor pointA = make2DPoint(0.0, 0.0);
		Tensor pointB = make2DPoint(1.1, 1.1);
		Hp hpOk = new Hp.Builder().bandwidth(1.0).build();
		kg.apply(d, pointA, pointB, hpOk); // OK hp

		Hp hpBad = new Hp.Builder().build(); // empty Hp

		// hp is missing SIGMA value
		try {
			kg.apply(d, pointA, pointB, hpBad);
			fail("expected exception");
		} catch (IllegalArgumentException e) {
		}
	}

	@Test
	public void testNullArgs() {
		Distance d = new DistanceEuclidean();
		KernelGaussian kg = new KernelGaussian();
		Tensor pointA = make2DPoint(0.0, 0.0);
		Tensor pointB = make2DPoint(1.1, 1.1);
		Hp hp = new Hp.Builder().bandwidth(1.0).build();

		// null pointA
		try {
			kg.apply(d, null, pointB, hp);
			fail("expecting exception");
		} catch (IllegalArgumentException e) {
		}

		// null pointB
		try {
			kg.apply(d, pointA, null, hp);
			fail("expecting exception");
		} catch (IllegalArgumentException e) {
		}

		// null hp
		try {
			kg.apply(d, pointA, pointB, null);
			fail("expecting exception");
		} catch (IllegalArgumentException e) {
		}

	}

	private Tensor make2DPoint(double x, double y) {
		Tensor point = new Tensor(2); // 2D point
		point.set(0, x);
		point.set(1, y);
		return point;
	}
	
	// verify smoothed distance from [0,0] to [x,y]
	private void test2DPoint(Hp hp, double x, double y, double expected) {
	    test2DPointIdx1s(hp, x, y, expected);
	    test2DPointIdx2(hp, x, y, expected);
	}

	private void test2DPointIdx1s(Hp hp, double x, double y, double expected) {
		Tensor samplePoint = make2DPoint(x, y);
		Tensor queryPoint = make2DPoint(0.0, 0.0);
		Distance d = new DistanceEuclidean();
		KernelGaussian kg = new KernelGaussian();
		assertEquals(expected, kg.apply(d, queryPoint, samplePoint, hp), 1e-6);
		// test that the Kernel is symmetrical
		assertEquals(expected, kg.apply(d, samplePoint, queryPoint, hp), 1e-6);
	}
	
	private void test2DPointIdx2(Hp hp, double x, double y, double expected) {
	    Tensor idx = new Tensor(2,2);
	    idx.set(0, 0, x);
	    idx.set(0, 1, y);
	    idx.set(1, 0, 0); // query point
	    idx.set(1, 1, 0);
	    Distance d = new DistanceEuclidean();
	    KernelGaussian kg = new KernelGaussian();
	    assertEquals(expected, kg.apply(d, idx, 0, 1 , hp), 1e-6);
	    // test that the Kernel is symmetrical
	    assertEquals(expected, kg.apply(d, idx, 1, 0, hp), 1e-6);
	}

	private void test2Dw1() {
		Hp hp = new Hp.Builder().bandwidth(1.0).build();
		test2DPoint(hp, 0.0, 0.0, 1.0);
		test2DPoint(hp, 1.0, 0.0, .367879);
		test2DPoint(hp, 0.0, 1.0, .367879);
		test2DPoint(hp, 1.0, 1.0, .135335);
	}

	private void test2Dw2() {
		Hp hp = new Hp.Builder().bandwidth(2.0).build();
		test2DPoint(hp, 0.0, 0.0, 1.0);
		test2DPoint(hp, 1.0, 0.0, .606531);
		test2DPoint(hp, 0.0, 1.0, .606531);
		test2DPoint(hp, 1.0, 1.0, .367879);
	}

	@Test
	public void testWeight() {
		// sigma = 1
		test2Dw1();
		test2Dw2();
	}

	@Test
	public void testKernelGaussian() {
	}

}
