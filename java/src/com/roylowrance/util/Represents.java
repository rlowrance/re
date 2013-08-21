package com.roylowrance.util;

// boolean static function to determine what a String represents
public class Represents {

	// return true iff s is YYYYYMMDD or YYYY-MM-DD
	// allow DD to be zero
	public static boolean date(String s) {
	    if (s == null)
	        throw new RuntimeException("s must not be null");
	    
		try {
			new Date(s);
			return true;
		}
		catch (IllegalArgumentException e) {
			return false;
		}
	}
	
	public static boolean double_(String s) {
	    if (s == null)
	        throw new RuntimeException("s must not be null");
	       
		try {
			Double.valueOf(s);
			return true;
		}
		catch (NumberFormatException e) {
			return false;
		}
	}
	
	public static boolean int_(String s) {
	    if (s == null)
	        throw new RuntimeException("s must not be null");
	       
		try {
			Integer.valueOf(s);
			return true;
		}
		catch (NumberFormatException e) {
			return false;
		}
	}
	
	public static boolean float_(String s) {
        if (s == null)
            throw new RuntimeException("s must not be null");		
	    
	    try {
			Float.valueOf(s);
			return true;
		}
		catch (NumberFormatException e) {
			return false;
		}
	}
	
	public static boolean long_(String s) {
        if (s == null)
            throw new RuntimeException("s must not be null");
        
	    try {
			Long.valueOf(s);
			return true;
		}
		catch (NumberFormatException e) {
			return false;
		}
	}
}
