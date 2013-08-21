package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import com.roylowrance.util.LineScanner;

public class LineScannerTest {
	LineScanner ls;

	@Before
	public void setUp() throws Exception {
		// read one a test version of a deed file, because it is short
		String filePath = "/home/roy/Dropbox/nyu-thesis-project/data/raw/deeds-all-columns/CAC_TEST1.txt";
		ls = new LineScanner(filePath);
	}

	@Test
	public void testLineScanner() throws IOException {
		// normal case testing in setUp()
		
		// test invalid file name
		try {
			LineScanner bad = new LineScanner("234242k02342.txt"); // presumedly not a file path
			fail("expected to throw");
		}
		catch (FileNotFoundException e) {
			assertTrue(true); //count the successful test case
		}
	}

	@Test
	public void testHasNextLine() throws IOException {
		assertTrue(ls.hasNextLine());
	}

	@Test
	public void testNextLine() throws IOException {
		// read the file
		int recordsRead = 0;
		while (ls.hasNextLine()) {
			String line = ls.nextLine();
			recordsRead += 1;
			final boolean display = false;
			if (display)
				System.out.println("line:" + line);
		}
		assertEquals(3, recordsRead);
		assertEquals(3, ls.getNumberLinesRead());
		assertFalse(ls.hasNextLine());
		
	}

	@Test
	public void testClose() throws IOException {
		ls.close();
	}
	
	@Test // on deeds file were there was a problem
	public void testDeedsFile()
	throws FileNotFoundException, IOException {
		String filePath = "/home/roy/Dropbox/nyu-thesis-project/data/raw/deeds-all-columns/CAC06037F8.txt";
		ls = new LineScanner(filePath);
		// the bug in Scanner reads only the first several hundred thousand records of the over million in the file
		int lineCount = 0;
		while (ls.hasNextLine()) {
			ls.nextLine();
			lineCount++;
		}
		final int expectedNumberLines = 2269343;
		assertEquals(expectedNumberLines, lineCount);
		assertEquals(expectedNumberLines, ls.getNumberLinesRead());
	}

	@Test // that there is still a problem with java.util.Scanner on the deeds file
	public void testDeedsFileJavaUtilScanner()
	throws FileNotFoundException {
		String filePath = "/home/roy/Dropbox/nyu-thesis-project/data/raw/deeds-all-columns/CAC06037F8.txt";
		java.util.Scanner s = new java.util.Scanner(filePath);
		// the bug in Scanner reads only the first several hundred thousand records of the over million in the file
		int lineCount = 0;
		while (s.hasNextLine()) {
			s.nextLine();
			lineCount++;
		}
		final int actualNumberLines = 2269343;
		final int expectedNumberLines = 1; // the broken Scanner read this mean lines on 2012-01-22
		assertEquals(expectedNumberLines, lineCount);
	}
	
	@Test // that a header record can be read
	public void TestReadHeader()
	throws FileNotFoundException, IOException {
		final boolean display = true;
		String filePath = "/home/roy/Dropbox/nyu-thesis-project/data/raw/deeds-all-columns/CAC06037F8.txt";
		LineScanner ls = new LineScanner(filePath);
		String header = ls.nextLine();
		if (display)
			System.out.println("header:" + header);
		assertTrue(header.length() != 0);
	}
}
