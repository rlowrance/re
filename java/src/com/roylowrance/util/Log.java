package com.roylowrance.util;

import java.util.Formatter;

public class Log {
	private String methodName;
	private boolean logging;
	
	public Log(String methodName, boolean actuallyPrint) {
		this.methodName = methodName;
		this.logging = actuallyPrint;
	}
	
	public Log(String methodName) {
		this(methodName, true);
	}
	
	public boolean getLogging() {return logging;}
	
	public void println(String s) {
		if (logging) {
			System.out.println(methodName + ": " + s);
		}
	}
	
	public void print(String s) {
		if (logging) {
			System.out.print(methodName + ": " + s);
		}
	}
	
	public void format(String f, Object... args) {
		if (logging) {
			System.out.format(methodName + ": " + f, args);
		}
	}
		
	public void println(String s1, String s2) {
		println(s1 + " = " + s2);
	}
	
	public void println(String s1, int s2) {
		println(s1, String.valueOf(s2));
	}
	
	public void println(String s1, boolean s2) {
		println(s1, String.valueOf(s2));
	}
		
	public void println(String s1, java.util.GregorianCalendar s2) {
		println(s1, String.valueOf(s2));
	}

	public void println(String s1, float value) {
		println(s1, String.valueOf(value));
		
	}
}
