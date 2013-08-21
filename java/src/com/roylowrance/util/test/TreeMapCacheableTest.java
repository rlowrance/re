package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.Set;

import com.roylowrance.util.TreeMapCacheable;

public class TreeMapCacheableTest {
	TreeMapCacheable<Integer,Double> tmc;
	//TreeMapCacheable<Integer,Double> tmcOne;
	String testFilePath;

	@Before
	public void setUp() throws Exception {
		testFilePath = "/home/roy/Desktop/tempfile.ser";
		tmc = new TreeMapCacheable<Integer,Double>(testFilePath);
	}
	
	@After
	public void tearDown() {
		// delete the temporary file used for the cache
		File file = new File(testFilePath);
		file.delete();
	}

	@Test
	public void testTreeMapCacheable() {
		// constructor tested in setUp()
	}

	@Test
	public void testGet() {
		assertEquals(null, tmc.get(1));
		
		tmc.put(1, 10.0);
		assertEquals(10.0, tmc.get(1), 0);
	}

	@Test
	public void testPut() {
		tmc.put(1, 10.0);
		tmc.put(2, 20.0);
		assertEquals(2, tmc.size());
		assertEquals(10.0, tmc.get(1), 0);
		assertEquals(20.0, tmc.get(2), 0);
	}

	@Test
	public void testContainsKey() {
		assertTrue(!tmc.containsKey(1));
		tmc.put(1, 10.0);
		assertTrue(tmc.containsKey(1));
	}

	@Test
	public void testKeySet() {
		tmc.put(1, 10.0);
		tmc.put(2, 20.0);
		Set<Integer> keySet = tmc.keySet();
		assertEquals(2, keySet.size(), 0);
		assertTrue(keySet.contains(1));
		assertTrue(keySet.contains(2));
	}
	
	@Test
	public void testSize() {
		assertEquals(0, tmc.size(), 0);
		tmc.put(1, 10.0);
		assertEquals(1, tmc.size(), 0);
	}

	@Test
	public void testStoreToDisk()
	throws FileNotFoundException, IOException, ClassNotFoundException {
		// test empty cache
		tmc.storeToDisk(testFilePath);
		{
			TreeMapCacheable<Integer,Double> tmcEmpty = new TreeMapCacheable<Integer,Double>(testFilePath);
			assertEquals(0, tmcEmpty.size());		
		}
		tmc.put(1, 10.0);
		tmc.storeToDisk(testFilePath);
		{
			TreeMapCacheable<Integer,Double> tmcOne = new TreeMapCacheable<Integer,Double>(testFilePath);
			assertEquals(1, tmcOne.size());		
		}

	}
	
	@Test
	public void testMiniApp()
	throws FileNotFoundException, IOException, ClassNotFoundException {
		String filePath = "/home/roy/Desktop/testMiniApp.ser";
		// pass 1: create cache file with 1 result

		{
			TreeMapCacheable<Integer,Double> tmc = new TreeMapCacheable<Integer,Double>(filePath);
			assertEquals(0, tmc.size(), 0); // initially empty
			tmc.put(1, 10.0);
			tmc.storeToDisk(filePath); // write 1 entry
		}
		// pass 2: add another element
		{
			TreeMapCacheable<Integer,Double> tmc = new TreeMapCacheable<Integer,Double>(filePath);
			assertEquals(1, tmc.size(), 0); // initially has one entry
			tmc.put(2, 20.0);
			tmc.storeToDisk(filePath);
		}
		// pass 3: check that there is 2 elements
		{
			TreeMapCacheable<Integer,Double> tmc = new TreeMapCacheable<Integer,Double>(filePath);
			assertEquals(2, tmc.size(), 0); // initially has two entries
		}
		// delete the file used for testing
		File file = new File(filePath);
		file.delete();
	}

}
