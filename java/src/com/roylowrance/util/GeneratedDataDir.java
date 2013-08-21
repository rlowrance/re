package com.roylowrance.util;

/**
 * return path to generated data directory
 * @author Roy
 * @deprecated 
 * Use Dir().generated() instead
 */
@Deprecated
public class GeneratedDataDir {
	String dir = null;
	
	public  GeneratedDataDir() {
		dir = "/Users/Roy/Dropbox/nyu-fha/data/generated/";
	}
	
	public String getDir() {return dir;}
		
}
