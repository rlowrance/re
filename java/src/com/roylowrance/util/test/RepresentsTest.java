package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Represents;

public class RepresentsTest {

	@Before
	public void setUp() throws Exception {
	}

	@Test
	public void testDate() {
		assertTrue(Represents.date("20120114"));
		assertFalse(Represents.date("20120100")); // day 00 is not allowed"
		assertTrue(Represents.date("00010101"));
		assertFalse(Represents.date("20123101")); // not yyyy-dd-mm
		assertFalse(Represents.date("01/03/2012"));
		assertTrue(Represents.date("1999-05-16"));
	}

	@Test
	public void testDouble_() {
		assertTrue(Represents.double_("1"));
		assertTrue(Represents.double_("1.0"));
		assertTrue(Represents.double_("1.0F"));
		assertTrue(Represents.double_(" 32D"));
		assertTrue(Represents.double_("+32D"));
		assertTrue(Represents.double_("-32.0D "));
	}

	@Test
	public void testInt_() {
		assertTrue(Represents.int_("0"));
		assertTrue(Represents.int_("-1"));
		assertFalse(Represents.int_("+1"));
		assertFalse(Represents.int_("12.0"));
		assertFalse(Represents.int_("9000000000000000000"));

	}

	@Test
	public void testFloat_() {
		assertTrue(Represents.float_("1"));
		assertTrue(Represents.float_("1.0"));
		assertTrue(Represents.float_("1.0D"));
		assertTrue(Represents.float_(" 32F"));
		assertTrue(Represents.float_("+32F"));
		assertTrue(Represents.float_("-32.0F "));
	}

	@Test
	public void testLong_() {
		assertTrue(Represents.long_("0"));
		assertTrue(Represents.long_("-1"));
		assertTrue(Represents.long_("1"));
		assertTrue(Represents.long_("9000000000000000000"));
		assertFalse(Represents.long_("+1"));
		assertFalse(Represents.long_("0.0L"));
		assertFalse(Represents.long_("0L"));
		assertFalse(Represents.long_("-1L"));
		assertFalse(Represents.long_("+1L"));
		assertFalse(Represents.long_("1."));
	}
	
	@Test
	public void testInt_2() {
		assertTrue(Represents.int_("-123"));
		assertTrue(Represents.int_("0"));
		assertTrue(Represents.int_("456"));
		assertFalse(Represents.int_("0.0"));
	}
	
	@Test
	public void testDouble_2() {
		assertTrue(Represents.double_("34.2086"));
		assertTrue(Represents.double_("34"));
		assertTrue(Represents.double_("0.0"));
		assertTrue(Represents.double_("0"));
		assertTrue(Represents.double_("-123.456"));
		assertTrue(Represents.double_("-123"));
		assertFalse(Represents.double_("abc"));
	}
	
	@Test
	public void testDate2() {
		assertTrue(Represents.date("20111217"));
		assertTrue(Represents.date("2011-12-17"));
		assertFalse(Represents.date("19500100"));  // the date is not on the calendar
		assertFalse(Represents.date("1950-01-00"));
		assertFalse(Represents.date("12/17/2001"));
	}
	
	@Test
	public void testFloat_2() {
		assertTrue(Represents.float_("34.2086"));
		assertTrue(Represents.float_("34"));
		assertTrue(Represents.float_("0.0"));
		assertTrue(Represents.float_("0"));
		assertTrue(Represents.float_("-123.456"));
		assertTrue(Represents.float_("-123"));
		assertFalse(Represents.float_("abc"));
	}
	
	@Test
	public void TestLong_2() {
		assertTrue(Represents.long_("-123"));
		assertTrue(Represents.long_("0"));
		assertTrue(Represents.long_("456"));
		assertFalse(Represents.long_("0.0"));	
		assertFalse(Represents.long_("19        19"));
	}


}
