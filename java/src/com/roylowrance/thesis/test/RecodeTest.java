package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Test;

import com.roylowrance.thesis.Recode;

public class RecodeTest {

	@Test
	public void testApn() {
		assertTrue("0000000123".equals(Recode.apn("12-3", "123")));
		assertTrue("0000000123".equals(Recode.apn("12-3", "123x")));
		assertTrue("0000000123".equals(Recode.apn("12 3", "123x")));
		assertTrue("0000000123".equals(Recode.apn("12_3", "123x")));
		assertTrue("0000000123".equals(Recode.apn("1-  __ 2-3", "123x")));
		assertFalse("0000000456".equals(Recode.apn("123", "123")));
		assertTrue("0000001919".equals(Recode.apn("19                    19",
				""))); // all spaces are dropped
	}

	@Test
	public void testDate() {
		assertTrue("20110830".equals(Recode.date("20110915", "20110830")));
		assertTrue("20110830".equals(Recode.date("20110915", "2011-08-30")));
		assertTrue("20110915".equals(Recode.date("20110915", "20110830x")));
		assertTrue("20110915".equals(Recode.date("2011-09-15", "20110815x")));
		assertFalse("20110830".equals(Recode.date("20110915", "20110815x")));
	}

}
