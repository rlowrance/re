package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Tuple2;

public class Tuple2Test {
	private Tuple2<Double,Double> x;
	private Tuple2<String,Integer> y;

	@Before
	public void setUp() throws Exception {
		x = new Tuple2<Double,Double> (123D, 456D);
		y = new Tuple2<String,Integer> ("abc", 789);
	}

	@Test
	public void testTuple2() {
		// constuctors tested in setUp()
	}

	@Test
	public void testGetElement1() {
		assertEquals(123D, x.getElement1(), 0D);
		assertEquals("abc", y.getElement1());
	}

	@Test
	public void testGetElement2() {
		assertEquals(456D, x.getElement2(), 0);
		assertEquals(789, y.getElement2(), 0);
	}

}
