package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.Hp;

public class HpTest {
	Hp hp;

	@Before
	public void setUp() throws Exception {
		hp = new Hp.Builder().k(1).bandwidth(3.0).build();
	}

//	@Test
//	public void testEqualFields() {
//		Hp a = new Hp.Builder().initial1DCutoff(1).k(2).numberTestSamples(4)
//				.sigma(5).build();
//		Hp b = new Hp.Builder().initial1DCutoff(1).k(2).numberTestSamples(4)
//				.sigma(5).build();
//		Hp c = new Hp.Builder().initial1DCutoff(1).k(2).numberTestSamples(4)
//				.sigma(6).build();
//		assertTrue(a.equalFields(a));
//		assertTrue(a.equalFields(b));
//		assertTrue(b.equalFields(a));
//		assertFalse(a.equalFields(c));
//		assertFalse(c.equalFields(a));
//	}

//	final int BEFORE = -1;
//	final int EQUAL = 0;
//	final int AFTER = 1;
//
//	@Test
//	public void testCompareTo() {
//
//		Hp cutoff1 = new Hp.Builder().initial1DCutoff(10).build();
//		Hp cutoff1a = new Hp.Builder().initial1DCutoff(10).build();
//		Hp cutoff2 = new Hp.Builder().initial1DCutoff(20).build();
//		equals(cutoff1, cutoff1a);
//		ordered(cutoff1, cutoff2);
//
//		Hp numberTestSamples1 = new Hp.Builder().initial1DCutoff(10)
//				.numberTestSamples(1).build();
//		Hp numberTestSamples1a = new Hp.Builder().initial1DCutoff(10)
//				.numberTestSamples(1).build();
//		Hp numberTestSamples2 = new Hp.Builder().initial1DCutoff(10)
//				.numberTestSamples(2).build();
//		equals(numberTestSamples1, numberTestSamples1a);
//		ordered(numberTestSamples1, numberTestSamples2);
//
//		Hp empty = new Hp.Builder().build();
//		Hp k1 = new Hp.Builder().k(1).build();
//		Hp k2 = new Hp.Builder().k(2).build();
//
//		assertEquals(EQUAL, empty.compareTo(empty));
//
//		assertEquals(BEFORE, empty.compareTo(k1)); // empty < k1 ==> empty
//													// BEFORE k1
//		assertEquals(AFTER, k1.compareTo(empty));
//		assertEquals(EQUAL, k1.compareTo(k1));
//
//		assertEquals(AFTER, k2.compareTo(k1));
//		assertEquals(BEFORE, k1.compareTo(k2));
//		assertEquals(EQUAL, k2.compareTo(k2));
//
//		Hp sigma1 = new Hp.Builder().sigma(1).build();
//		Hp sigma2 = new Hp.Builder().sigma(2).build();
//		assertEquals(AFTER, sigma2.compareTo(sigma1));
//		assertEquals(BEFORE, sigma1.compareTo(sigma2));
//		assertEquals(EQUAL, sigma1.compareTo(sigma1));
//
//		Hp k1mu1sigma1 = new Hp.Builder().k(1).sigma(1).build();
//		Hp k1mu1sigma2 = new Hp.Builder().k(1).sigma(2).build();
//		assertEquals(AFTER, k1mu1sigma2.compareTo(k1mu1sigma1));
//		assertEquals(BEFORE, k1mu1sigma1.compareTo(k1mu1sigma2));
//		assertEquals(EQUAL, k1mu1sigma1.compareTo(k1mu1sigma1));
//		assertEquals(EQUAL, k1mu1sigma2.compareTo(k1mu1sigma2));
//
//		// test all fields #1
//		{
//			Hp a = new Hp.Builder().k(1).sigma(20).build();
//			Hp a2 = new Hp.Builder().k(1).sigma(20).build();
//			Hp b = new Hp.Builder().k(2).sigma(20).build();
//			Hp c = new Hp.Builder().k(1).sigma(20).build();
//			Hp e = new Hp.Builder().k(1).sigma(20).build();
//			Hp f = new Hp.Builder().k(1).sigma(21).build();
//
//			equals(a, a2);
//			ordered(a, b);
//			ordered(c, b);
//			ordered(e, f);
//			equals(a, c);
//			equals(a, e);
//			ordered(a, f);
//		}
//
//		// test all fields #2
//		{
//			Hp a = new Hp.Builder().initial1DCutoff(1).k(2)
//					.numberTestSamples(4).sigma(5).build();
//			Hp a1 = new Hp.Builder().initial1DCutoff(1).k(2)
//					.numberTestSamples(4).sigma(5).build();
//			Hp a2 = new Hp.Builder().initial1DCutoff(2).k(2)
//					.numberTestSamples(4).sigma(5).build();
//			equals(a, a1);
//			ordered(a, a2);
//
//			// increment k
//			Hp b = new Hp.Builder().initial1DCutoff(1).k(3)
//					.numberTestSamples(4).sigma(5).build();
//			Hp b1 = new Hp.Builder().initial1DCutoff(1).k(3)
//					.numberTestSamples(4).sigma(5).build();
//			equals(b, b1);
//			ordered(a, b);
//
//			// increment numberTestSamples
//			Hp d = new Hp.Builder().initial1DCutoff(1).k(2)
//					.numberTestSamples(5).sigma(5).build();
//			Hp d1 = new Hp.Builder().initial1DCutoff(1).k(2)
//					.numberTestSamples(5).sigma(5).build();
//			equals(d, d1);
//			ordered(a, d);
//
//			// increment sigma
//			Hp e = new Hp.Builder().initial1DCutoff(1).k(2)
//					.numberTestSamples(4).sigma(6).build();
//			Hp e1 = new Hp.Builder().initial1DCutoff(1).k(2)
//					.numberTestSamples(4).sigma(6).build();
//			equals(e, e1);
//			ordered(a, e);
//			ordered(e, b);
//			ordered(e, d);
//
//		}
//	}
//
//	private void equals(Hp x, Hp y) {
//		assertEquals(EQUAL, x.compareTo(y));
//	}
//
//	private void ordered(Hp x, Hp y) {
//		assertEquals(BEFORE, x.compareTo(y));
//		assertEquals(AFTER, y.compareTo(x));
//	}

	@Test
	public void testHp() {
		// construction tested in setUp()
	}

	@Test
	public void testGet() {
		assertEquals(1, hp.getK(), 0);
		assertEquals(3.0, hp.getBandwidth(), 0);
	}

	@Test
	public void testGetNothing() {
		Hp hpEmpty = new Hp.Builder().build();
		// System.out.println("hpEmpty:" + hpEmpty);
		assertEquals(null, hpEmpty.getK());
		assertEquals(null, hpEmpty.getBandwidth());
	}

	@Test
	public void testToString() {
		final boolean display = false;
		String s = hp.toString();
		s = hp.toString();
		if (display)
			System.out.println("s:" + s);
		assertTrue(s.contains("k=1"));
		assertTrue(s.contains("bandwidth=3.0"));
	}

}
