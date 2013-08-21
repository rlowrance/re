package com.roylowrance.thesis.test;

import java.util.ArrayList;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.HashMap;

import com.roylowrance.util.Tensor;

import com.roylowrance.thesis.Dir;
import com.roylowrance.thesis.ExceptionOLD;
import com.roylowrance.thesis.ObsVisit;

import com.roylowrance.util.Date;
import com.roylowrance.util.Log;

public class ObsVisitTest {
	private ObsVisit testObsVisit;
	private String testBaseFilePath;

	@Before
	// access obs2R
	public void setUp() throws ExceptionOLD, FileNotFoundException, IOException {
		Log log = new Log("ObsVisitTest.setUp", false);
		String projectDir = Dir.project();
		testBaseFilePath = projectDir + "data/generated-v4/obs2R/obs2R";
		testObsVisit = new ObsVisit(testBaseFilePath + ".data",
				testBaseFilePath + ".header");
		log.println(" returning");
	}

	@Test
	public void testObsVisit() {
		Log log = new Log("ObsVisitTest.testObsVisit", false);
		// setUp() testing the constructor
		log.println(" returning");
	}

	@Test
	public void testClose() throws IOException {
		testObsVisit.close();
	}

	class MyVisitor implements ObsVisit.Visitor {
		private int dataRecordsRead;
		private boolean logging = false;

		public MyVisitor() {
			dataRecordsRead = 0;
		}

		public void start(String header) {
			Log log = new Log("ObsVisitTest.MyVisitor.start", logging);
			log.println("header:" + header);
		}

		public void end() {
			Log log = new Log("ObsVisitTest.MyVisitor.end", logging);
			log.println("dataRecordsRead:" + dataRecordsRead);
		}

		public void visit(String dataRecord) {
			Log log = new Log("ObsVisitTest.MyVisitor.visit", logging);
			log.println("dataRecord:" + dataRecord);
			dataRecordsRead++;
		}
	}

	@Test
	public void testVisit() throws IOException {
		final int throttle = 3;
		MyVisitor mv = new MyVisitor();
		testObsVisit.visit(mv, throttle);
	}
}
