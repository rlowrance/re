package com.roylowrance.util.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Date;
import com.roylowrance.util.Log;

public class DateTest {
	Date d1;
	Date d2;

	@Before
	public void setUp() throws Exception {
		d1 = new Date("20120114");
		d2 = new Date("2012-01-14");
	}

	@Test // construction with String
	public void testDate() {
		// construction tested in setUp()
	}
	
	@Test // construction with double
	public void testDateDouble() {
	    Date d = Date.newInstance(20091215);
	    assertEquals(2009, d.getYear(), 0);
	    assertEquals(11, d.getMonth(), 0);
	    assertEquals(15, d.getDay(), 0);
	}

	@Test
	public void testGetYear() {
		assertEquals(2012, d1.getYear());
		assertEquals(2012, d2.getYear());
	}

	@Test
	public void testGetMonth() {
		assertEquals(0, d1.getMonth());
		assertEquals(0, d2.getMonth());
		assertEquals(11, new Date("19711231").getMonth());
	}

	@Test
	public void testGetDay() {
		assertEquals(14, d1.getDay());
		assertEquals(14, d2.getDay());
	}

	@Test
	public void testGetDaysPastEpcoh() {
		assertEquals(0, new Date("19700101").getDaysPastEpoch());
		assertEquals(1, new Date("19700102").getDaysPastEpoch());
		assertEquals(2, new Date("19700103").getDaysPastEpoch());
		assertEquals(365, new Date("19710101").getDaysPastEpoch());
		assertEquals(0, new Date("19691231").getDaysPastEpoch()); // NOTE: 2 days 0 days past epoch
		assertEquals(-1, new Date("19691230").getDaysPastEpoch());
	}
	
	@Test // conversion using static method
	public void testDaysPastEpoch() {
		assertEquals(0, Date.daysPastEpoch("19700101"));
		assertEquals(1, Date.daysPastEpoch("19700102"));
		assertEquals(2, Date.daysPastEpoch("19700103"));
		assertEquals(365, Date.daysPastEpoch("19710101"));
		assertEquals(0, Date.daysPastEpoch("19691231")); // NOTE: 2 days 0 days past epoch
		assertEquals(-1, Date.daysPastEpoch("19691230"));
	}
	
	// test construction of invalid Date
	
	@Test
	public void testConstruction1() {
		try {
			Date d = new Date("20120100");
		} 
		catch (IllegalArgumentException e) {
			;
		}
	}

	@Test
	public void testConstruction2() {
		try {
			Date d = new Date("2011-12-16x");
		} 
		catch (IllegalArgumentException e) {
			;
		}
	}

	@Test
	public void testConstruction3() {
		try {
			Date d = new Date("abcd-12-16");
		} 
		catch (IllegalArgumentException e) { // not NumberFormatException
			;
		}
	}
	
	@Test public void testCurrentDateAndTime() {
	    Log log = new Log("DateTest.testCurrentDateAndTime", true);
	    String now = Date.currentDateAndTime();
	    log.println("now:" + now);
	    assertTrue(now.contains("2012"));
	}
}
