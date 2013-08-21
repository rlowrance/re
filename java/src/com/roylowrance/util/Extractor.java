package com.roylowrance.util;

import java.util.HashMap;
import java.util.NoSuchElementException;


// extract fields as Strings from records in a csv file
// confirm that each record has the expected number of fields
public class Extractor {
	private String separatorRegex = null;
	private HashMap<String, Integer> indexOf = new HashMap<String,Integer>();
	private String cachedInputLine	= null;
	private String[] cachedFieldValues = null;
	private Integer expectedNumberFields = null;
	
	public Extractor(final String header, final String separatorRegex) {
		this.separatorRegex = separatorRegex;
		String[] splitHeader = header.split(separatorRegex, -1); // -1 forces return of trailing empty fields
		expectedNumberFields = splitHeader.length;
		for (int count = 0; count < splitHeader.length; ++count) {
			String fieldName = splitHeader[count];
			if (indexOf.containsKey(fieldName)) {
				throw new RuntimeException("header contains field (" + fieldName + ") at least twice");
			}
			indexOf.put(fieldName, count);
		}
	}
	
	public class Exception extends java.lang.RuntimeException {
		public Exception(String message) {
			super(message);
		}
	}
	
	public void checkNumberOfFields(String record) {
		if (expectedNumberFields == null)
			return;
		final int actualNumberFields = splitLine(record).length;
		if (actualNumberFields != expectedNumberFields) {
			throw new Exception("record <" + record + 
					            "> has " + actualNumberFields + 
					            " fields not the expected " + expectedNumberFields); 
		}		
	}
	
	// extract fieldName from inputLine
	// confirm that inputLine has the expected number of fields
	public String extract(final String inputLine, final String fieldName) {
		final boolean logging = false;
		Log log = new Log("Extractor.extract", logging);
		if (logging) {
			log.println("inputLine:" + inputLine);
			log.println("fieldName:" + fieldName);
		}
		if (cachedInputLine == null || !cachedInputLine.equals(inputLine))
			loadCache(inputLine);
		if (!indexOf.containsKey(fieldName)) {
			System.out.println("header fields:");
			for (String key : indexOf.keySet())
				System.out.println(" " + key);
			System.out.println("fieldName:" + fieldName);
			throw new RuntimeException("fieldName (" + fieldName + ") not in the header");
		}
		final int index = indexOf.get(fieldName);
		if (index >= cachedFieldValues.length) {
			// the input record does not have enough fields
			System.out.println("inputLine:" + inputLine);
			for (int i = 0; i < cachedFieldValues.length; i++) {
				System.out.println("field " + i +":" + cachedFieldValues[i]);
			}
			System.out.println("fieldName:" + fieldName);
			System.out.println("index:" + index);
			System.out.println("length of cached values:" + cachedFieldValues.length);
			throw new NoSuchElementException("input record does not have enough fields to contain the requested field");
		}
		if (logging)
			log.println("indexOf.get(fieldName):" + indexOf.get(fieldName)); 
		return cachedFieldValues[index];
	}

	// load cached input line and field values; confirm that the input line had the expected number of fields
	private void loadCache(final String line) {
		cachedInputLine = new String(line);  // in case caller mutates line
		cachedFieldValues = splitLine(cachedInputLine);
		checkNumberOfFields(line);
	}
	
	private String[] splitLine(final String line) {
		return line.split(separatorRegex, -1); // -1 forces return of trailing empty fields
	}

}
