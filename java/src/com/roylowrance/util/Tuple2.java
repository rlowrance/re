package com.roylowrance.util;

public class Tuple2<A,B> {
	private A element1;
	private B element2;
	
	public Tuple2(A element1, B element2) {
		this.element1 = element1;
		this.element2 = element2;
	}
	
	// accessors
	public A getElement1() {
		return element1;
	}
	
	public B getElement2() {
		return element2;
	}
	
	public String toString() {
		return "Tuple2(" + element1 + ", " + element2 + ")";
	}

}
