package com.roylowrance.thesis.test;

//import static org.junit.Assert.*;
//import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.LinkedList;

import com.roylowrance.thesis.Dir;
import com.roylowrance.thesis.MasterVisit;

public class MasterVisitTest {

	static class MyVisitor implements MasterVisit.Visitor {
		int visitCount;

		public MyVisitor() {
			visitCount = 0;
		}

		public void start(String headerParcel, String headerDeed,
				String headerGeocoding) {
		}

		public void end() {
			assertEquals(4, visitCount, 0);
		}

		public void visit(String parcelRecord, LinkedList<String> deedRecords,
				LinkedList<String> geocodingRecords) {
			visitCount++;
			if (visitCount > 3)
				return;
			if (visitCount == 1) {
				// A
				assertTrue(parcelRecord.startsWith("A|2004001003"));
				assertEquals(0, deedRecords.size(), 0);
				assertEquals(0, geocodingRecords.size(), 0);
			} else if (visitCount == 2) {
				// A B B C
				assertTrue(parcelRecord.startsWith("A|2004001004"));
				assertEquals(2, deedRecords.size(), 0);
				assertEquals(1, geocodingRecords.size(), 0);
				int deedCount = 0;
				for (String deedRecord : deedRecords) {
					deedCount++;
					if (deedCount == 1)
						assertTrue(deedRecord
								.startsWith("B|2004001004|19840706"));
					else if (deedCount == 2)
						assertTrue(deedRecord
								.startsWith("B|2004001004|19930316"));
					// else if (deedCount == 3)
					// assertTrue(deedRecord.startsWith("B|2004001004|20051212"));
					// else if (deedCount == 4)
					// assertTrue(deedRecord.startsWith("B|2004001004|20091014"));
					for (String geocodingRecord : geocodingRecords)
						assertTrue(geocodingRecord.startsWith("C|2004001004"));
				}
			} else if (visitCount == 3) {
				// A C
				assertTrue(parcelRecord.startsWith("A|2004001005"));
				assertEquals(0, deedRecords.size(), 0);
				assertEquals(1, geocodingRecords.size(), 0);
			}
		}
	}

	public static void main(String[] args) throws FileNotFoundException,
			IOException {

		String projectDir = Dir.project();
		String generatedDir = projectDir + "data/generated-v4/";

		String masterDataPath = generatedDir + "master.data";
		String masterHeadersPath = generatedDir + "master.headers";

		MasterVisit vm = new MasterVisit(masterDataPath, masterHeadersPath);
		final int throttle = 7;
		vm.visit(new MyVisitor(), throttle);
	}

	private static void assertEquals(int expected, int actual, int margin) {
		if (Math.abs(expected - actual) <= margin)
			return;
		System.out.println("expected:" + expected);
		System.out.println("actual:" + actual);
		System.out.println("margin:" + margin);
		throw new RuntimeException("assertEquals failed");
	}

	private static void assertTrue(boolean value) {
		if (value)
			return;
		System.out.println("value:" + value);
		throw new RuntimeException("assertTrue failed");
	}

}
