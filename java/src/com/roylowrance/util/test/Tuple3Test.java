package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Tuple3;

public class Tuple3Test {
	Tuple3 x;

	@Before
	public void setUp() throws Exception {
		Integer a = 1;;
		Long b = 2L;
		Float c = 3F;
		x = new Tuple3<Integer,Long,Float>(a, b, c);
	}

	@Test
	public void testTuple3() {
		// tested in setUp()
	}

	@Test
	public void testGetElement1() {
		assertEquals(1, x.getElement1());
	}

	@Test
	public void testGetElement2() {
		assertEquals(2L, x.getElement2());
	}

	@Test
	public void testGetElement3() {
		assertEquals(3F, x.getElement3());
	}
}
