package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import com.roylowrance.thesis.FileLineVisitor;

public class FileLineVisitorTest {
	FileLineVisitor flv;

	@Before
	public void setUp() throws Exception {
		// test on one of the deed input files
		flv = new FileLineVisitor(
				"/home/roy/Dropbox/nyu-thesis-project/data/raw/deeds-all-columns/CAC06037F1.txt");
	}

	@Test
	public void testFileLineVisitor() {
		// valid construtor test in setup

		// test invalid file path
		FileLineVisitor test;
		try {
			test = new FileLineVisitor("does not exist 12353345132431");
			fail("expected to throw");
		} catch (FileNotFoundException e) {
			assertTrue(true); // what we expected
		}
	}

	@Test
	public void testClose() throws IOException {
		flv.close();
	}

	@Test
	public void testVisit() throws IOException {
		// check that we read all records in the first deeds file
		class MyVisitor implements FileLineVisitor.Visitor {
			private int numberLinesRead;

			// constructor
			public MyVisitor() {
			}

			public void start() {
				numberLinesRead = 0;
			}

			public void visit(String line) {
				numberLinesRead += 1;
			}

			public void end() {
			}

			public int getNumberLinesRead() {
				return numberLinesRead;
			}
		}

		MyVisitor mv = new MyVisitor();
		int throttle = 0; // read all the lines
		flv.visit(mv, throttle);
		assertEquals(2204005, mv.getNumberLinesRead());
	}

}
