package com.roylowrance.util.test;

import java.util.List;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.CommandLine;
import com.roylowrance.util.Log;
import com.roylowrance.util.Tuple2;

public class CommandLineTest {
	private CommandLine cl;
	
	@Before // create a sample command line; unit test constructor
	public void setUp() {
		String[] args = {
				"123",
				"var",
				"--obs=AA",
				"--k=(0.1,2.3,6.0)",
				"--kmpd=(0.001)",
				"--x=()",
				"-p",
				"--q",
				"--seq=[abc;def)",
				"--dates=[20000101,20120202]",
				"--n=[1,2,3]",
				"last"};
		this.cl = new CommandLine(args);
	}
	
	@Test
	public void testExtractSequence() {
		final boolean display = false;
		List<String> answer = cl.extractSequence("--n", "[", ",",	"]");
		if (display)
			System.out.println("testExtractSequence answer:" + answer);
		assertEquals("1", answer.get(0));
		assertEquals("2", answer.get(1));
		assertEquals("3", answer.get(2));
	}
	
	@Test
	public void testExtractSequence2() {
		final boolean display = false;
		Tuple2<String,String> answer = cl.extractSequence2("--seq", "[", ";",	")");
		if (display)
			System.out.println("answer:" + answer);
		assertEquals("abc", answer.getElement1());
		assertEquals("def", answer.getElement2());
		
		answer = cl.extractSequence2("--dates", "[", ",", "]");
		assertEquals("20000101", answer.getElement1());
		assertEquals("20120202", answer.getElement2());
	}

	@Test
	public void testGetOptionValue() {
		assertEquals("AA", cl.getOptionValue("--obs"));
		
		// test option not present
		try {
			assertEquals("", cl.getOptionValue("not present"));
			fail("should have thrown Exception");
		}
		catch (CommandLine.Exception e) {
		}
	}

	@Test
	public void testIsPresent() {
		assertTrue(cl.isPresent("-p"));
		assertTrue(cl.isPresent("--q"));
		assertFalse(cl.isPresent("--r"));
	}

	@Test
	public void testGetOptionValueList() {
		Log log = new Log("CommandLineTest.testGetOptionValueList", false);
		String[] ovlK = cl.getOptionValueList("--k");
		assertEquals(3, ovlK.length, 0);
		assertEquals("0.1", ovlK[0]);
		assertEquals("2.3", ovlK[1]);
		assertEquals("6.0", ovlK[2]);
		
		String[] ovlKmpd = cl.getOptionValueList("--kmpd");
		assertEquals(1, ovlKmpd.length);
		assertEquals("0.001", ovlKmpd[0]);
		
		String[] ovlX = cl.getOptionValueList("--x");
		assertEquals(0, ovlX.length);
	}

	@Test
	public void testGetNonOptionList() {
		final String optionIndicators = "-";
		String[] nol = cl.getNonOptionList(optionIndicators);
		assertEquals(3, nol.length);
		assertEquals("123", nol[0]);
		assertEquals("var", nol[1]);
		assertEquals("last", nol[2]);
	}

}
