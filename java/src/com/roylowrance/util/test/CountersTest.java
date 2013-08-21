package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Test;

import com.roylowrance.util.Counters;

public class CountersTest {

	@Test
	public void test() {
		Counters counters = new Counters();
		counters.increment("a");
		counters.increment("b");
		counters.increment("b");
		assertEquals(1, counters.get("a"), 0);
		assertEquals(2, counters.get("b"), 0);
		assertEquals(0, counters.get("c"), 0);
	}

}
