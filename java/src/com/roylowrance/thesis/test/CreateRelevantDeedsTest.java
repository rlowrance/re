package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.CreateRelevantDeeds;

public class CreateRelevantDeedsTest {

	@Before
	public void setUp() throws Exception {
	}

	@Test
	public void testCleanDate() {
		assertEquals("20001201", CreateRelevantDeeds.cleanDate("20001200"));
		assertEquals("20001201", CreateRelevantDeeds.cleanDate("20001201"));
	}

}
