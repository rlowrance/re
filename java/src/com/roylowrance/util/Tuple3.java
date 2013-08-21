package com.roylowrance.util;

public class Tuple3<A,B,C> {
	private A element1;
	private B element2;
	private C element3;
	
	public Tuple3(A element1, B element2, C element3) {
		this.element1 = element1;
		this.element2 = element2;
		this.element3 = element3;
	}
	
	// accessors
	public A getElement1() {
		return element1;
	}
	
	public B getElement2() {
		return element2;
	}
	
	public C getElement3() {
		return element3;
	}
	
	public String toString() {
		return "Tuple3(" + element1 + ", " + element2 + ", " + element3 + ")";
	}
}
