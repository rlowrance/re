package com.roylowrance.util;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;

// like a Scanner, but only handle lines
// this class was designed and implemented to work around a bug in java.util.Scanner
// the bug causes large files (more than a few hundred thousand lines) to be truncated before end of file
public class LineScanner {
	private BufferedReader bufferedReader;
	private String nextLine;
	private int numberLinesRead = 0;
	
	public LineScanner(String filePath) {
		try {
		    bufferedReader = new BufferedReader(new FileReader (new File(filePath)));
		}
	    //catch (IOException e)           {throw new RuntimeException("IOException e =" + e);}
		catch (FileNotFoundException e) {throw new RuntimeException("file " + filePath + " not found; e=" + e);}

		nextLine = null;
	}
	
	// return true iff there is another line
	public boolean hasNextLine() {
		Log log = new Log("LineScanner.hasNextLine", false);
		if (nextLine != null) {
			return true;
		}
		try {
		    nextLine = bufferedReader.readLine();
		}
		catch (IOException e) {throw new RuntimeException("IOException e=" + e);}
		log.println("nextLine:" + nextLine);
		return nextLine != null;
	}
	
	// return the next line if it exists
	// if it does not, throw Exception
	public String nextLine() {
		if (!this.hasNextLine())
			throw new RuntimeException("attempting to read past end of file");
		String result = nextLine;
		nextLine = null;
		numberLinesRead++;
		return result;
	}
	
	// return number of lines read
	public int getNumberLinesRead() {
		return numberLinesRead;
	}
	
	// close the underlying buffered reader
	public void close()
	throws IOException {
		bufferedReader.close();
	}

}
