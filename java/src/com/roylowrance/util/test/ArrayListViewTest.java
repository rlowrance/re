package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.util.ArrayList;

import com.roylowrance.util.ArrayListView;

public class ArrayListViewTest {
	ArrayListView<Integer> alv;

	@Before
	public void setUp() throws Exception {
		ArrayList<Integer> al = new ArrayList<Integer>();
		al.add(10);
		al.add(20);
		al.add(30);
		al.add(40);
		al.add(50);
		final int logicallyDeletedIndex = 2;
		
		alv = new ArrayListView(al, logicallyDeletedIndex);
	}

	@Test
	public void testArrayListView() {
		// construction tested in setUp()
	}

	@Test
	public void testGet() {
		assertEquals(10, alv.get(0), 0);
		assertEquals(20, alv.get(1), 0);
		assertEquals(40, alv.get(2), 0);
		assertEquals(50, alv.get(3), 0);
	}

	@Test
	public void testSize() {
		assertEquals(4, alv.size(), 0);
	}

}
