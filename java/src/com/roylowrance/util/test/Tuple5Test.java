package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Tuple5;

public class Tuple5Test {
	Tuple5 x;

	@Before
	public void setUp() throws Exception {
		Integer a = 1;;
		Long b = 2L;
		Float c = 3F;
		Double d = 4D;
		String e = "abc";
		x = new Tuple5<Integer,Long,Float,Double,String>(a, b, c, d, e);
	}

	@Test
	public void testTuple5() {
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

	@Test
	public void testGetElement4() {
		assertEquals(4D, x.getElement4());
	}

	@Test
	public void testGetElement5() {
		assertEquals("abc", x.getElement5());
	}

}
