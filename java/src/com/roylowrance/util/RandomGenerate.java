package com.roylowrance.util;

import java.util.ArrayList;
import java.util.Random;

public class RandomGenerate {

	/**
	 * Generate random Double values from the uniform distribution in [lowest,highest)
	 * @param lowest lowest generated value
	 * @param highest highest generated value
	 * @param numberSamples number of values generated
	 * @return list of values
	 */
	public static ArrayList<Double> gaussianDoubleValues(double mean, double sigma, int numberSamples) {
		Log log = new Log("RandomGenerate.gaussianDoubleValues", false);
		if (sigma <= 0)
			throw new IllegalArgumentException("sigma (" + sigma + ") is negative");
		final long randomSeed = 27L;
		Random r = new Random(randomSeed);
		ArrayList<Double> result = new ArrayList<Double>();
		for (int i = 0 ; i < numberSamples; i++) {
			// nextGaussian returns a double samples from N(0,1)
			final double z = r.nextGaussian();
			log.println("next N(0,1) random:" + z);
			result.add(z * sigma + mean);
		}			
		return result;
	}
	
	/**
	 * Generate random Double values from the uniform distribution in [lowest,highest)
	 * @param lowest lowest generated value
	 * @param highest highest generated value
	 * @param numberSamples number of values generated
	 * @return list of values
	 */
	public static ArrayList<Double> uniformDoubleValues(double lowest, double highest, int numberSamples) {
		Log log = new Log("RandomGenerate.uniformDoubleValues", false);
		if (lowest > highest)
			throw new IllegalArgumentException("lowest (" + lowest + ") exceeds highest (" + highest + ")");
		final long randomSeed = 27L;
		Random r = new Random(randomSeed);
		final double range = highest - lowest;
		log.println("range:" + range);
		ArrayList<Double> result = new ArrayList<Double>();
		for (int i = 0 ; i < numberSamples; i++) {
			// nextDouble returns a number between 0.0 and 1.0, so its value needs to be scaled
			final double next = lowest + (r.nextDouble() * range);
			log.println("next random:" + next);
			result.add(next);
		}			
		return result;
	}
	
	/**
	 * Generate random Integer values from the uniform distribution [lowest,highest)
	 * @param lowest lowest generated value
	 * @param highest highest generated value
	 * @param numberSamples number of values generated
	 * @return list of values
	 */
	public static ArrayList<Integer> uniformIntegerValues(int lowest, int highest, int numberSamples) {
		Log log = new Log("RandomGenerate.uniformIntegerValues", false);
		if (lowest > highest)
			throw new IllegalArgumentException("lowest (" + lowest + ") exceeds highest (" + highest + ")");
		final long randomSeed = 27L;
		Random r = new Random(randomSeed);
		final int range = highest - lowest;
		ArrayList<Integer> result = new ArrayList<Integer>();
		for (int i = 0 ; i < numberSamples; i++) {
			final int next = lowest + r.nextInt(lowest + range);
			log.println("next random:" + next);
			result.add(next);
		}			
		return result;
	}

}
