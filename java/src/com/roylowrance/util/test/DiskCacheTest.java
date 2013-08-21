package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.Serializable;

import java.util.HashMap;
import java.util.TreeMap;

import com.roylowrance.util.DiskCache;

public class DiskCacheTest {
	String temporaryFileName;
	DiskCache<Integer,String> diskCache;

	@Before
	public void setUp() throws Exception {
		temporaryFileName = "DiskCacheTest-tempfile.tmp";
		diskCache = new DiskCache<Integer,String>(temporaryFileName);
	}
	
	@After
	public void tearDown() throws Exception {
		File file = new File(temporaryFileName);
		file.delete();
	}

	@Test
	public void testDiskCache() {
		// constructor testing in setUp
	}

	@Test
	public void testLoadFromDisk()
	throws FileNotFoundException, IOException, ClassNotFoundException {
		// load empty cache
		TreeMap<Integer,String> map = diskCache.loadFromDisk();
		assertEquals(0, map.size(), 0);
	}

	@Test
	public void testStoreToDisk() 
	throws FileNotFoundException, IOException {
		TreeMap<Integer,String> map = new TreeMap<Integer,String>();
		// write empty cache
		diskCache.storeToDisk(map);
		
		// write cache with content
		map.put(1, "one");
		diskCache.storeToDisk(map);
	}
	
	@Test
	public void testTypicalUsage() 
	throws FileNotFoundException, IOException, ClassNotFoundException {
		TreeMap<Integer,String> map = new TreeMap<Integer,String>();
		map.put(1, "one");
		map.put(2, "two");
		
		diskCache.storeToDisk(map);
		
		TreeMap<Integer, String> map2 = diskCache.loadFromDisk();
		assertEquals("one", map2.get(1));
		assertEquals("two", map2.get(2));
		
		// add to the cache and re-write
		map.put(3, "three");
		diskCache.storeToDisk(map);
		assertTrue(!map2.containsKey(3));
		map2 = diskCache.loadFromDisk();
		assertEquals("three", map2.get(3));
	}
	


}
