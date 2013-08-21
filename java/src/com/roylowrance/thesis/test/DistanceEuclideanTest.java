package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.DistanceEuclidean;
import com.roylowrance.thesis.Hp;

import com.roylowrance.util.Tensor;

public class DistanceEuclideanTest {
	private DistanceEuclidean de;

	@Before
	public void setUp() throws Exception {
		de = new DistanceEuclidean();
	}

	@Test
	// construction
	public void testDistance() {
	}

	@Test
	public void testDistanceEuclidean() {
		// 1D
		{
			Hp hp = new Hp.Builder().build(); // empty Hp
			Tensor a = new Tensor(1);
			Tensor b = new Tensor(1);
			a.set(0, 1.0);
			b.set(0, 2.0);
			assertEquals(0.0, de.apply(a, a, hp), 0);
			assertEquals(1.0, de.apply(a, b, hp), 0);
		}
		// 2D
		{
			Hp hp = new Hp.Builder().build(); // empty Hp
			Tensor a = new Tensor(2);
			Tensor b = new Tensor(2);
			a.set(0, 0.0F);
			a.set(1, 0.0F);
			b.set(0, 1.0F);
			b.set(1, 1.0F);
			assertEquals(0.0, de.apply(a, a, hp), 0);
			assertEquals(1.414, de.apply(a, b, hp), 1e-2);
		}
	}

}
