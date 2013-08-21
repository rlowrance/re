package com.roylowrance.thesis.test;

import java.util.ArrayList;
import java.util.HashSet;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.HashMap;

import com.roylowrance.libidx.Idx1Long;
import com.roylowrance.libidx.Idx1Double;
import com.roylowrance.libidx.Idx2Double;

import com.roylowrance.thesis.CreateFeatures;
import com.roylowrance.thesis.Dir;
import com.roylowrance.thesis.ExceptionOLD;
import com.roylowrance.thesis.ObsVisit;

import com.roylowrance.util.Date;
import com.roylowrance.util.Log;

public class CreateObs2RFeaturesTest {

	@Test
	// that some observations can be read
	public void testReadColumns() throws FileNotFoundException, IOException,
			ClassNotFoundException {
		Log log = new Log("CreateObs2RFeaturesTest.testReadObs1RSubset1", false);
		final String obsFileBasePath = "/home/roy/Dropbox/nyu-thesis-project/data/generated-v4/obs2R/obs2R";

		// setup names of columns to read
		String[] arrayColumnNames = { "APN ID", "DATE ID", "random",
				"YEAR BUILT", "SALE AMOUNT" };
		ArrayList<String> columnNames = new ArrayList<String>();
		for (String columnName : arrayColumnNames)
			columnNames.add(columnName);

		final int throttle = 1024;

		// read the columns
		HashMap<String, ArrayList<String>> all = CreateFeatures.readColumns(
				obsFileBasePath, columnNames, throttle);

		ArrayList<String> apns = all.get("APN ID");
		assertEquals(throttle, apns.size(), 0);
		assertEquals("2004001004", apns.get(0));
		assertEquals("2004001004", apns.get(1));
		assertEquals("2004001004", apns.get(2));

		ArrayList<String> dates = all.get("DATE ID");
		assertEquals(throttle, dates.size(), 0);
		assertEquals("19840706", dates.get(0));
		assertEquals("19930316", dates.get(1));
		assertEquals("20051212", dates.get(2));

		ArrayList<String> randoms = all.get("random");
		assertEquals(throttle, randoms.size(), 0);
		assertEquals("0.731774", randoms.get(0));
		assertEquals("0.410151", randoms.get(1));
		assertEquals("0.7146368", randoms.get(2));

		ArrayList<String> years = all.get("YEAR BUILT");
		assertEquals(throttle, years.size(), 0);
		assertEquals("1973", years.get(0));
		assertEquals("1973", years.get(1));
		assertEquals("1973", years.get(2));

		ArrayList<String> saleAmount = all.get("SALE AMOUNT");
		assertEquals(throttle, saleAmount.size(), 0);
		assertEquals("00000185000", saleAmount.get(0));
		assertEquals("00000290000", saleAmount.get(1));
		assertEquals("00000725000", saleAmount.get(2));
	}

	private static double deTransform(double p, double mean,
			double standardDeviation) {
		Log log = new Log("ObsVsitTest.deTransform", true);
		log.println("p:" + p);
		log.println("mean:" + mean);
		log.println("standardDeviation:" + standardDeviation);
		return p * standardDeviation + mean;
	}

	// by reading the entire file, this test can be used to calibrate the size
	// of the heap
	@Test
	// entire file should contain some day numbers in (2000,2010) COMMENTED OUT
	public void testReadObs2RDays() throws FileNotFoundException, IOException,
			ClassNotFoundException {
		Log log = new Log("CreateObs2RFeaturesTest.testReadObs2RDays", false);
		final String obsFileBasePath = "/home/roy/Dropbox/nyu-thesis-project/data/generated-v4/obs2R/obs2R";
		final int throttle = 0; // no limit, so read all the records
		// HashMap<String,ArrayList<String>> all = CreateFeatures.readColumns
		// (obsFileBasePath, CreateFeatures.makeAllColumnNames(), throttle);
		throw new RuntimeException("uncomment line above");

		// final long lowestDayNumber = Date.daysPastEpoch("20000101");
		// final long highestDayNumber = Date.daysPastEpoch("20091231");
		// log.println("lowestDayNumber:" + lowestDayNumber +
		// " highestDayNumber:" + highestDayNumber);
		//
		// Idx1Long days = or.getDays();
		// log.println("days.size():" + days.size());
		// int numberInRange = 0;
		// for (long day : days) {
		// log.println("day:" + day);
		// if (day >= lowestDayNumber && day <= highestDayNumber) {
		// log.println("found:" + day);
		// numberInRange += 1;
		// }
		// }
		// log.println("numberInRange:" + numberInRange);
		// assertTrue(numberInRange > 0);
		//
		//
		// log.println("finished");
	}

	private <T> ArrayList<T> makeArrayList(T... array) {
		ArrayList<T> result = new ArrayList<T>();
		for (T s : array)
			result.add(s);
		return result;
	}

	@Test
	public void testUniqueValues() {
		ArrayList<String> list = makeArrayList("a", "b", "c", "a");
		HashSet<String> set = CreateFeatures.uniqueValues(list);
		assertEquals(3, set.size(), 0);
		assertTrue(set.contains("a"));
		assertTrue(set.contains("b"));
		assertTrue(set.contains("c"));
	}

	@Test
	public void testIndicate() {
		ArrayList<String> list = makeArrayList("a", "b", "c", "a");

		ArrayList<String> a = CreateFeatures.indicate(list, "a");
		assertEquals(4, a.size());
		assertEquals("1", a.get(0));
		assertEquals("0", a.get(1));
		assertEquals("0", a.get(2));
		assertEquals("1", a.get(3));

		ArrayList<String> b = CreateFeatures.indicate(list, "b");
		assertEquals(4, b.size());
		assertEquals("0", b.get(0));
		assertEquals("1", b.get(1));
		assertEquals("0", b.get(2));
		assertEquals("0", b.get(3));
	}

	@Test
	public void testConvertStringsToIdx1Long() {
		ArrayList<String> s = makeArrayList("0", "1", "2");
		Idx1Long idx = CreateFeatures.convertStringsHoldingLongsToTensor(s);
		assertEquals(0L, idx.get(0), 0);
		assertEquals(1L, idx.get(1), 0);
		assertEquals(2L, idx.get(2), 0);
	}

	@Test
	public void testConvertStringsToIdx1LongDays() {
		ArrayList<String> s = makeArrayList("20100101", "19831215");
		Idx1Double days = CreateFeatures
				.convertStringsHoldingDateToTensorHoldingDays(s);
		assertEquals(Date.daysPastEpoch("20100101"), days.get(0), 0);
		assertEquals(Date.daysPastEpoch("19831215"), days.get(1), 0);
	}

	// @Test
	// public void testConvertStringsToIdx1Float() {
	// ArrayList<String> s = makeArrayList("0", "1", "2");
	// Idx1Double idx = CreateFeatures.convertStringsToIdx1Double(s);
	// assertEquals(0F, idx.get(0), 0);
	// assertEquals(1F, idx.get(1), 0);
	// assertEquals(2F, idx.get(2), 0);
	// }

	// @Test
	// public void testConvertStringsToIdx1Int() {
	// ArrayList<String> s = makeArrayList("0", "1", "2");
	// Idx1Int idx = CreateFeatures.convertStringsHoldingsIntToIdx1Double(s);
	// assertEquals(0, idx.get(0), 0);
	// assertEquals(1, idx.get(1), 0);
	// assertEquals(2, idx.get(2), 0);
	// }

}
