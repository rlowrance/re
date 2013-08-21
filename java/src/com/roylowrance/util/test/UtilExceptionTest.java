package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Exception;

public class UtilExceptionTest {

	@Before
	public void setUp() throws Exception {
	}

	@Test
	public void testUtilException() {
		try {
			throw new Exception("abc");
		}
		catch (Exception e) {
			assertEquals("abc", e.getMessage());
			return;
		}
		// cannot test for wrong exception thrown
		// because the compiler is too smart
	}

}
