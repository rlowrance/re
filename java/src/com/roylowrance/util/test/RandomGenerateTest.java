package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.util.ArrayList;

import com.roylowrance.util.RandomGenerate;

public class RandomGenerateTest {

	@Before
	public void setUp() throws Exception {
	}

	@Test
	public void testGenerateGaussianDoubleValues1() {
		// test generation of N(0,1)
		final boolean display = false;
		final double mean = 0;
		final double variance = 1;  // standard deviation is 33
		final int numberSamples = 256;
		final ArrayList<Double> nums = RandomGenerate.gaussianDoubleValues(mean, Math.sqrt(variance), numberSamples);
		int countInUnit = 0;
		for (double num : nums) {
			if (display)
				System.out.println("num:" + num);
			// these tests do not hold in general, but do hold for the first 256 values
			if (num < 1 && num > -1)
				countInUnit++;
		}
		double fractionInUnit = countInUnit * 1.0 / nums.size();
		assertEquals(0.682, fractionInUnit, 0.10);
	}
	
	@Test
	public void testGenerateGaussianDoubleValues2() {
		// test generation of N(100, )
		final boolean display = false;
		final double mean = 100;
		final double standardDeviation = 33;  // standard deviation is 33
		final int numberSamples = 256;
		final ArrayList<Double> nums = RandomGenerate.gaussianDoubleValues(mean, standardDeviation, numberSamples);
		int countInUnit = 0;
		for (double num : nums) {
			if (display)
				System.out.println("num:" + num);
			// these tests do not hold in general, but do hold for the first 256 values
			if (num < (mean + standardDeviation) && num > (mean- standardDeviation))
				countInUnit++;
		}
		double fractionInUnit = countInUnit * 1.0 / nums.size();
		assertEquals(2.0 / 3.0, fractionInUnit, 0.10);
	}

	@Test
	public void testGenerateRandomUniformDoubleValues() {
		final boolean display = false;
		final double lowest = -1.0;
		final double highest = 10.0;
		final int numberSamples = 256;
		final ArrayList<Double> nums = RandomGenerate.uniformDoubleValues(lowest, highest, numberSamples);
		boolean containsLowest = false;
		boolean containsHighest = false;
		for (double num : nums) {
			if (display)
				System.out.println("num:" + num);
			assertTrue(num >= lowest);
			assertTrue(num <= highest);
			containsLowest = containsLowest || (num == lowest);
			containsHighest = containsHighest || (num == highest);
		}
		// the following conditions happens to be true for the test
		// but are not true in general
		assertFalse(containsLowest);
		assertFalse(containsHighest);
	}
	
	@Test
	public void testGenerateRandomUniformIntValues() {
		final boolean display = false;
		final int lowest = 1;
		final int highest = 128;
		final int numberSamples = 256;
		final ArrayList<Integer> nums = RandomGenerate.uniformIntegerValues(lowest, highest, numberSamples);
		boolean containsLowest = false;
		boolean containsHighest = false;
		assertEquals(numberSamples, nums.size(), 0);
		for (int num : nums) {
			if (display)
				System.out.println("num:" + num);
			assertTrue(num >= lowest);
			assertTrue(num <= highest);
			containsLowest = containsLowest || (num == lowest);
			containsHighest = containsHighest || (num == highest);
		}
		// the following conditions happens to be true for the test
		// but are not true in general
		assertTrue(containsLowest);
		assertTrue(containsHighest);
	}
	
	@Test
	public void testGenerateRandomUniformIntValues2() {
		// test that the exact number of values is returned
		final boolean display = false;
		final int lowest = 1;
		final int highest = 128;
		final int numberSamples = 20;
		final ArrayList<Integer> nums = RandomGenerate.uniformIntegerValues(lowest, highest, numberSamples);
		assertEquals(numberSamples, nums.size(), 0);
	}

}
