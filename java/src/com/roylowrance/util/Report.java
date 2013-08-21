package com.roylowrance.util;

import java.io.PrintWriter;

import java.util.Formatter;
import java.util.TreeMap;
import java.util.LinkedList;
import java.util.Set;

/**
 * Simple report writer. Duplex lines to a file and to system console.
 * @author Roy
 *
 */
public class Report {
	private java.io.File outFile;
	private java.io.PrintWriter outPrintWriter;
	private TreeMap<String,Section> sectionNamed;
	private boolean echoLines;
	
	/**
	 * Construct a Report from path to a file
	 * @param filepath path to the file
	 * @param echoLines if true, also write the lines to System.out
	 */
	public Report(String filepath, boolean echoLines) {
		try {
			outFile = new java.io.File(filepath);
			outPrintWriter = new PrintWriter(new java.io.FileWriter(outFile));
		}
		catch (java.io.IOException e) {
			System.out.println("Report.Report(String): failed to open file " + filepath);
			System.exit(1);
		}
		sectionNamed = new TreeMap<String,Section>();
		this.echoLines = echoLines;
	}
	
	public Report(String filePath) {
		this(filePath, true);
	}
	
	/**
	 * Close the underlying file
	 */
	public void close() {
		// print any sections
		
		for (String sectionName : sectionNamed.keySet()) {
			String msg = "Section " + sectionName;
			outPrintWriter.println(msg);
			System.out.println(msg);
			sectionNamed.get(sectionName).replay(outPrintWriter);
		}
		
		outPrintWriter.close();
	}
	
	/**
	 * Print a line followed by a newline character.
	 * @param line the line to print
	 */
	public void println(String line) {
		outPrintWriter.println(line);
		if (echoLines)
			System.out.println(line);
	}
	
	public void print(String s) {
		outPrintWriter.print(s);
		if (echoLines)
			System.out.print(s);
	}
	
	public void format(String s, Object... args) {
		outPrintWriter.format(s, args);
		if (echoLines)
			System.out.format(s, args);
	}
	
	/**
	 * Close the underlying file in case user failed to do this.
	 */
	protected void finalize() throws Throwable {
		super.finalize();
		outPrintWriter.close();
	}
	
	public class Section {
		private LinkedList<String> lines;
		private String sectionName;
		
		public Section(String sectionName) {
			this.lines = new LinkedList<String>();
			this.sectionName = sectionName;
			sectionNamed.put(sectionName, this);
		}
		public void println(String nextLine) {
			final boolean logging = sectionName.equals("parcels");
			if (logging) {
				;
			}
			Log log = new Log("Report.Section.println", logging);
			log.println("sectionName:" + sectionName + " line:" + nextLine);
			this.lines.add(nextLine);  // add to end of list
			System.out.println(nextLine);
		}
		public void replay(PrintWriter outPrintWriter) {
			Log log = new Log("Report.Section.replay", true);
			log.println("entered");
			log.println("Section: " + sectionName);
			for (String line : this.lines) {
				outPrintWriter.println(line);
			}
		}
	}
}
