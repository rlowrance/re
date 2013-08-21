package com.roylowrance.thesis;

import java.io.Serializable;

//import java.util.Comparable;
import java.util.HashMap;

/**
 * An immutable collection of named hyperparameters, each a double.
 * 
 * Construct using a builder, as the number of hyperparameters can be large.
 * Example: Hp hp1 = new Hp.Builder.mu(2.0).sigma(3.0).build(); Example: Hp hp2
 * = new Hp.Builder.k(27.0);
 * 
 * Old version also implemented Comparable<Hp>
 * 
 * @author Roy Lowrance
 * 
 */
public class Hp implements Serializable {
	// the private variables must be Objects so that one can test for
	// not-present
	// not present is indicated by a null value
	// By definition, a hyperparameter controls the accuracy of an algorithms
	// Another def (from Wikipedia): A hyperparamater is a parameter to a prior
	// probability distribution

	private final Integer k; // number of neighbors in k-nearest neighbors
	private final Double bandwidth; // std dev in Gaussian kernel
	
	private static final long serialVersionUID = 6;

	// comment out the comparable stuff, as its not needed and makes the code complicated
//	final int BEFORE = -1; // this < other
//	final int EQUAL = 0; // this.equals(other)
//	final int AFTER = 1; // other < this
//
//	private <T> int compare(Comparable<T> a, T b) {
//		if (a == null && b == null)
//			return EQUAL;
//		if (a == null && b != null)
//			return BEFORE; // null < some value
//		if (a != null && b == null)
//			return AFTER; // some value > null
//		return a.compareTo(b);
//	}
//
//	// return <0 iff this < other
//	// return >0 iff this > other
//	// return 0 iff this.equals(other)
//	public int compareTo(Hp other) {
//		// ref: http://www.javapractices.com/topic/TopicAction.do?Id=10
//
//		if (this == other)
//			return EQUAL;
//
//		int comparison;
//
//		comparison = compare(this.initial1DCutoff, other.initial1DCutoff);
//		if (comparison != EQUAL)
//			return comparison;
//
//		comparison = compare(this.k, other.k);
//		if (comparison != EQUAL)
//			return comparison;
//
//		comparison = compare(this.numberTestSamples, other.numberTestSamples);
//		if (comparison != EQUAL)
//			return comparison;
//
//		comparison = compare(this.bandwidth, other.bandwidth);
//		if (comparison != EQUAL)
//			return comparison;
//
//		return EQUAL;
//	}

	/**
	 * Builder class for Hp.
	 * 
	 * @author Roy Lowrance
	 * 
	 */
	public static class Builder {
		// initialize parameters to default null values
		// these variables must be Objects
		private Integer k;
		private Double bandwidth;

		// constructor sets no values
		public Builder() {
		}

		public Builder k(int k) {
			this.k = k;
			return this;
		}

		public Builder bandwidth(double bandwidth) {
			this.bandwidth = bandwidth;
			return this;
		}

		// static factory method to return a new immutable Hp instance
		public Hp build() {
			return new Hp(this);
		}
	}

	// constructor is private; use the Builder
	private Hp(Builder builder) {
		this.k = builder.k;
		this.bandwidth = builder.bandwidth;
	}

	// accessors
	public Integer getK() {
		return k;
	}

	public Double getBandwidth() {
		return bandwidth;
	}


//	public boolean equalFields(Hp other) {
//		return EQUAL == this.compareTo(other);
//	}

	/**
	 * Return a string containing each parameters value or null if value is not
	 * set
	 * 
	 * @return a String
	 */
	@Override
	public String toString() {
		return
		        "hp" + 
		        "(k=" + k +
		        ",bandwidth=" + bandwidth +
		        ")";
	}

}
