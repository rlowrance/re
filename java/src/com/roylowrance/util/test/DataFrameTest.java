package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.util.ArrayList;

import com.roylowrance.util.DataFrame;
import com.roylowrance.util.Tensor;

public class DataFrameTest {
    DataFrame df;
    
    private ArrayList<String> makeColumnNames() {
        String[] names = {"a", "b", "c"};
        ArrayList<String> result = new ArrayList<String> ();
        for (String name : names)
            result.add(name);
        return result;
    }
    
    private Tensor makeTensor() {
        Tensor result = new Tensor(2,3);
        for (int row = 0; row < 2; row++)
            for (int column = 0; column < 3; column++)
                result.set(row, column, 10 * row + column);
        return result;
    }

    @Before
    public void setUp() throws Exception {
        df = new DataFrame(makeColumnNames(), makeTensor());
    }

    @Test
    public void testDataFrame() {
        // constructor tested in setUp()
    }

    @Test
    public void testGetNames() {
        ArrayList<String> names = df.getNames();
        assertEquals(3, names.size());
        assertTrue(names.get(0).equals("a"));
        assertTrue(names.get(1).equals("b"));
        assertTrue(names.get(2).equals("c"));
    }

    @Test
    public void testGetTensor() {
        Tensor t = df.getTensor();
        assertEquals(2, t.getNDimensions());
        assertEquals(2, t.getSize(0));
        assertEquals(3, t.getSize(1));
        
        for (int row = 0; row < 2; row++)
            for (int column = 0; column < 3; column++)
                assertEquals(10 * row + column, t.get(row, column), 0);
    }

    @Test
    public void testGetColumnIndex() {
        assertEquals(0, df.getColumnIndex("a"));
        assertEquals(1, df.getColumnIndex("b"));
        assertEquals(2, df.getColumnIndex("c"));
    }

    @Test
    public void testGetColumNamed() {
        Tensor t = df.getColumnNamed("b");
        assertEquals(1, t.getNDimensions());
        assertEquals(2, t.getSize(0));
        assertEquals(1, t.get(0), 0);
        assertEquals(11, t.get(1), 0);
    }

}
