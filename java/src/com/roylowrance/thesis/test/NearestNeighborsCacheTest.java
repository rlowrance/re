package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.ArrayList;

import com.roylowrance.thesis.*;
import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

public class NearestNeighborsCacheTest {
    String filePath;
    NearestNeighborsCache nnc;
    int key1;
    int key2;

    @Before
    public void setUp() throws Exception {
        filePath = Dir.project() + "data/tmp/NearestNeighborsCacheTest.csv";
        nnc = new NearestNeighborsCache();
        
        key1 = 1;
        int[] array1 = {1,2,3};
        ArrayList<Integer> al1 = makeArrayList(array1);
        nnc.put(key1, al1);
        
        key2 = 2;
        ArrayList<Integer> al2 = new ArrayList<Integer>();
        for (int i = 0; i < 256; i++)
            al2.add(100 + i);
        nnc.put(key2, al2);
    }
    
    private ArrayList<Integer> makeArrayList(int[] values) {
        ArrayList<Integer> result = new ArrayList<Integer> ();
        for (int value : values) {
            result.add(value);
        }
        return result;
    }

    @Test
    public void testNearestNeighborsCache() {
        // tested in setUp()
    }
    
    private void checkKey1Key2() {
        Log log = new Log("NearestNeighborsCacheTest", true);
        log.println("nnc:" + nnc);
        ArrayList<Integer> get1 = nnc.get(key1);
        assertEquals(3, get1.size());
        assertEquals(1, get1.get(0), 0);
        assertEquals(2, get1.get(1), 0);
        assertEquals(3, get1.get(2), 0);
        
        ArrayList<Integer> get2 = nnc.get(key2);
        assertEquals(256, get2.size());
        assertEquals(100, get2.get(0), 0);
        assertEquals(101, get2.get(1), 0);
        assertEquals(102, get2.get(2), 0);
        assertEquals(355, get2.get(255), 0);
    }
    
    @Test
    public void testContainsKey() {
        assertTrue(nnc.containsKey(1));
        assertTrue(nnc.containsKey(2));
        assertFalse(nnc.containsKey(0));
    }

    @Test
    public void testGet() {
        checkKey1Key2();
    }

    @Test
    public void testPut() {
        try {
            // build up too-long array list
            ArrayList<Integer> al = new ArrayList<Integer>();
            for (int i = 0; i < 257; i++)
                al.add(i);
            nnc.put(key1,al); 
            fail("expected exception");
        }
        catch (IllegalArgumentException e) {}
    }

    @Test
    public void testPutFromCsv() throws IOException {
        nnc.write(filePath);
        
        // create new NearestNeighborsCache
        NearestNeighborsCache nnc2 = new NearestNeighborsCache();
        // add one extra key,value
        int key3 = 3;
        int[] array3 = {11,12,13};
        ArrayList<Integer> al1 = makeArrayList(array3);
        nnc2.put(key3, al1);
        
        // append the first two keys written to CSV above
        int recordsAdded = nnc2.putFromCsv(filePath);
        assertEquals(2, recordsAdded);
        
        checkKey1Key2();
        assertTrue(nnc2.containsKey(key3));
        assertEquals(11, nnc2.get(key3).get(0), 0);
        assertEquals(12, nnc2.get(key3).get(1), 0);
        assertEquals(13, nnc2.get(key3).get(2), 0);
        
        // re-running should generate an exception from a duplicate key
        try {nnc2.putFromCsv(filePath); fail("expected exception");}
        catch (RuntimeException e) {}
    }

    @Test
    public void testWrite() throws FileNotFoundException {
        int recordsWritten = nnc.write(filePath);
        assertEquals(2, recordsWritten);
        //fail("examine file, then comment out this statement");
    }

}
