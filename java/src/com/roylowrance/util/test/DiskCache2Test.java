package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.Serializable;

import java.util.ArrayList;

import com.roylowrance.util.DiskCache2;
import com.roylowrance.util.Log;

class CacheType extends ArrayList<Integer> {}

public class DiskCache2Test {
	String temporaryFileName;
	DiskCache2<CacheType> diskCache;

	@Before
	public void setUp() throws Exception {
		temporaryFileName = "DiskCacheTest-tempfile.tmp";
		diskCache = new DiskCache2<CacheType>(temporaryFileName);
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
		Log log = new Log("DiskCache2Test", true);
		// load empty cache
		log.println("about to load from disk");
		CacheType ct = (CacheType) diskCache.loadFromDisk();
		assertEquals(0, ct.size(), 0);
	}

	@Test
	public void testStoreToDisk() 
	throws FileNotFoundException, IOException {
		CacheType ct = new CacheType();
		// write empty cache
		diskCache.storeToDisk(ct);
		
		// write cache with content
		ct.add(27);
		diskCache.storeToDisk(ct);
	}
	
	@Test
	public void testTypicalUsage() 
	throws FileNotFoundException, IOException, ClassNotFoundException {
		CacheType ct = new CacheType();
		ct.add(27);
		ct.add(46);
		
		diskCache.storeToDisk(ct);
		
		CacheType ct2 = diskCache.loadFromDisk();
		assertEquals(27, ct.get(0), 0);
		assertEquals(46, ct.get(1), 0);
		
		// add to the cache and re-write
		ct.add(3);
		diskCache.storeToDisk(ct);
		assertEquals(2, ct2.size(), 0);
		ct2 = diskCache.loadFromDisk();
		assertEquals(3, ct.size());
	}
	


}
