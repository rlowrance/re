package com.roylowrance.util.test;

import static org.junit.Assert.*;

import java.util.ArrayList;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.ArrayListOps;
import com.roylowrance.util.Exception;

public class ArrayListOpsTest {

	@Before
	public void setUp() throws Exception {
	}

	@Test
	public void testStandardize() {
		// example is from Wikipedia
		// http://en.wikipedia.org/wiki/Standard_deviation
		float[] array = {2F, 4F, 4F, 4F, 5F, 5F, 7F, 9F};
		ArrayList<Float> vector = new ArrayList<Float>();
		for (float element : array)
			vector.add(element);
		
		ArrayListOps.StandardizeResult sr = ArrayListOps.standardize(vector);
		assertEquals(5.0, sr.getMean(), 0);
		assertEquals(2.0, sr.getStandardDeviation(), 0);
		ArrayList<Float> std = sr.getValues();		
		assertEquals(8, std.size(),0);
		assertEquals((2F - 5)/2.0, std.get(0), 0);
		assertEquals((9F - 5)/2.0, std.get(7), 0);
	}
	
	@Test // throw if standard deviation is zero
	public void testStandardizeException() {
		// example is from Wikipedia
		// http://en.wikipedia.org/wiki/Standard_deviation
		float[] array = {4F, 4F, 4F};
		ArrayList<Float> vector = new ArrayList<Float>();
		for (float element : array)
			vector.add(element);
		
		try {
			ArrayListOps.StandardizeResult sr = ArrayListOps.standardize(vector);
			fail("expected an exception to be thrown");
		}
		catch (Exception e) {
		}
	}	
	@Test
	public void testLog() {
		float[] array = {0.1F, 1F, 10F};
		ArrayList<Float> vector = new ArrayList<Float>();
		for (float element : array)
			vector.add(element);
		
		ArrayList<Float> x = ArrayListOps.log(vector);
		assertEquals(3, x.size(),0);
		// values differ because ArrayListOps.log uses double precision
		// and Math.log uses single precision in the calls below
		assertEquals(Math.log(0.1F), x.get(0), 1e-5);
		assertEquals(Math.log(1F), x.get(1), 1e-5);
		assertEquals(Math.log(10F), x.get(2), 1e-5);
	}

}
