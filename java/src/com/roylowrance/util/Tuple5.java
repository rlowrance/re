package com.roylowrance.util;

public class Tuple5<A,B,C,D,E> {
	private A element1;
	private B element2;
	private C element3;
	private D element4;
	private E element5;
	
	public Tuple5(A element1, B element2, C element3, D element4, E element5) {
		this.element1 = element1;
		this.element2 = element2;
		this.element3 = element3;
		this.element4 = element4;
		this.element5 = element5;
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
	
	public D getElement4() {
		return element4;
	}
	
	public E getElement5() {
		return element5;
	}
	
	public String toString() {
		return "Tuple5(" + 
				element1 + ", " + 
				element2 + ", " + 
				element3 + ", " +
				element4 + ", " + 
				element5 + ")";
	}

}
