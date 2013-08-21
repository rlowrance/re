package com.roylowrance.thesis;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;

// visit each line in a file
public class FileLineVisitor {
	private BufferedReader bufferedReader;

	public FileLineVisitor(String filePath) throws FileNotFoundException {
		bufferedReader = new BufferedReader(new FileReader(new File(filePath)));
	}

	public void close() throws IOException {
		bufferedReader.close();
	}

	public interface Visitor {
		public void start(); // called before first visit

		public void visit(String inputLine); // called for each input line

		public void end(); // called after last visit
	}

	// visit up to throttle input lines
	// set throttle to 0 to visit all lines
	public void visit(Visitor visitor, int throttle) throws IOException {
		visitor.start();
		String nextLine;
		while ((nextLine = bufferedReader.readLine()) != null) {
			visitor.visit(nextLine);
		}
		visitor.end();
	}

}
