package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.util.Tensor;

import com.roylowrance.util.Log;

public class TensorTest {
    Tensor t1;
    Tensor t2;
    double[] arrayT1 = {1,2,3};
    double[][] arrayT2 = {{1,2,3},{11,12,13}};
    
    private void assertLikeT1(Tensor x, double value1, double value2, double value3) {
        assertEquals(1, x.getNDimensions());
        assertEquals(3, x.getSize(0));
        assertEquals(value1, x.get(0), 0);
        assertEquals(value2, x.get(1), 0);
        assertEquals(value3, x.get(2), 0);
    }
    
    private void assertLikeT2(
            Tensor x, 
            double value1, double value2, double value3,
            double value4, double value5, double value6) {
        assertEquals(2, x.getNDimensions());
        assertEquals(2, x.getSize(0));
        assertEquals(3, x.getSize(1));
        assertEquals(value1, x.get(0,0), 0);
        assertEquals(value2, x.get(0,1), 0);
        assertEquals(value3, x.get(0,2), 0);
        assertEquals(value4, x.get(1,0), 0);
        assertEquals(value5, x.get(1,1), 0);
        assertEquals(value6, x.get(1,2), 0);
    }
    
    public void assertTensor1D(Tensor x, double...values) {
        assertEquals(1, x.getNDimensions());
        assertEquals(values.length, x.getSize(0));
        for (int i = 0; i < values.length; i++) 
            assertEquals(values[i], x.get(i), 0);
    }

    @Before
    public void setUp() throws Exception {
        {
            t1 = Tensor.newInstanceFromArray(arrayT1);
            assertEquals(1, t1.getNDimensions());
            assertEquals(3, t1.getSize(0), 0);
            for (int i = 0; i < arrayT1.length; i++) {
                assertEquals(arrayT1[i], t1.get(i), 0);
            }
        }
        {
            t2 = Tensor.newInstanceFromArray(arrayT2);
            assertEquals(2, t2.getNDimensions());
            assertEquals(2, t2.getSize(0), 0);
            assertEquals(3, t2.getSize(1), 0);
            for (int i = 0; i < arrayT2.length; i++)
                for (int j = 0; j < arrayT2[0].length; j++) {
                assertEquals(arrayT2[i][j], t2.get(i,j), 0);
            }
        }
    }
    
    private final int LESS = -1;
    private final int EQUAL = 0;
    private final int GREATER = 1;
    
    // test if x < y
    private void testLess(Tensor x, Tensor y) {
        assertEquals(LESS, x.compareTo(y));
        assertEquals(GREATER, y.compareTo(x));
        assertFalse(EQUAL == x.compareTo(y));
        assertFalse(EQUAL == y.compareTo(x));
    }
    
    // test if x == y
    // ref: http://docs.oracle.com/javase/6/docs/api/java/lang/Comparable.html
    private void testEquals(Tensor x, Tensor y) {
        assertEquals(EQUAL, x.compareTo(y));
        assertEquals(EQUAL, y.compareTo(x));
        assertFalse(LESS == x.compareTo(y));
        assertFalse(GREATER == x.compareTo(y));
    }
    
    @Test public void testCompareTo() {
        Tensor t1a1 = Tensor.new1DInstance(1.0);
        Tensor t1a2 = Tensor.new1DInstance(1.0);
        Tensor t1a3 = Tensor.new1DInstance(2.0);
        
        testLess(t1a1, t1a3);
        testEquals(t1a1, t1a2);
        
        Tensor t1b1 = Tensor.new1DInstance(1.0, 2.0);
        Tensor t1b2 = Tensor.new1DInstance(1.0, 2.0);
        Tensor t1b3 = Tensor.new1DInstance(1.0, 3.0);
        
        testLess(t1a1, t1b1);
        testLess(t1b1, t1b3);
        testEquals(t1b1, t1b2);
        
        double[][] a2a1 = {{1,2}, {3,4}};
        double[][] a2a3 = {{1,3}, {2,4}};
        double[][] a2a4 = {{1,2,3},{4,5,6}};
        double[][] a2a5 = {{1,2},{3,4},{5,6}};
        Tensor t2a1 = Tensor.newInstanceFromArray(a2a1);
        Tensor t2a2 = Tensor.newInstanceFromArray(a2a1);
        Tensor t2a3 = Tensor.newInstanceFromArray(a2a3);
        Tensor t2a4 = Tensor.newInstanceFromArray(a2a4);
        Tensor t2a5 = Tensor.newInstanceFromArray(a2a5);
        
        testLess(t1a1, t2a3);
        testLess(t2a1, t2a4);
        testLess(t2a1, t2a5);
        testLess(t2a4, t2a5);
        testEquals(t2a1, t2a2);
    }
    
    @Test
    public void testEmptyConstructor() {
        Tensor e = new Tensor();
        assertEquals(null, e.getStorage());
        assertEquals(0, e.getNDimensions());
        
        try {assertEquals(0, e.getSize(0)); fail("expected exception");}
        catch (IllegalArgumentException x) {}
        
        try {assertEquals(0, e.getSize(1)); fail("expected exception");}
        catch (IllegalArgumentException x) {}
    }
    
    @Test
    public void testCopyConstructor() {
        // verify sizes, element values, and use of same storage
        {
            Tensor t = new Tensor(t1);
            assertEquals(1, t.getNDimensions());
            assertEquals(3, t.getSize(0), 0);
            assertEquals(t1.getStorage(), t.getStorage());
            for (int i = 0; i < t1.getSize(0); i++) {
                assertEquals(t1.get(i), t.get(i), 0);
            }
        }
        
        {
            Tensor t = new Tensor(t2);
            assertEquals(2, t.getNDimensions());
            assertEquals(2, t.getSize(0), 0);
            assertEquals(3, t.getSize(1), 0);
            assertEquals(t2.getStorage(), t.getStorage());
            for (int i = 0; i < t2.getSize(0); i++)
                for (int j = 0; j < t2.getSize(1); j++) {
                assertEquals(t2.get(i,j), t.get(i,j), 0);
            }
        }
    }
    
    @Test
    public void testConstructionFromArray() {
        // t1 was constructed from an array
        assertEquals(1, t1.getNDimensions());
        assertEquals(3, t1.getNElements());
        assertEquals(3, t1.getSize(0), 0);
        try {t1.getSize(1); fail("expected exception"); }
        catch (IllegalArgumentException e){}
        assertEquals(1, t1.get(0), 0);
        assertEquals(2, t1.get(1), 0);
        assertEquals(3, t1.get(2), 0);
        
        // t2 was constructed form an array
        assertEquals(2, t2.getNDimensions());
        assertEquals(6, t2.getNElements());
        assertEquals(2, t2.getSize(0), 0);
        assertEquals(3, t2.getSize(1), 0);
        assertEquals(1, t2.get(0,0), 0);
        assertEquals(2, t2.get(0,1), 0);
        assertEquals(3, t2.get(0,2), 0);
        assertEquals(11, t2.get(1,0), 0);
        assertEquals(12, t2.get(1,1), 0);
        assertEquals(13, t2.get(1,2), 0);
    }
    
    @Test
    public void testConstructionFromSizes() {
        // 1D
        {
            Tensor t = new Tensor(27);
            assertEquals(1, t.getNDimensions(), 0);
            assertEquals(27, t.getNElements(), 0);
            assertEquals(27, t.getSize(0), 0);
            for (int i = 0; i < 27; i++)
                assertEquals(0, t.get(i), 0);
        }
        
        // 2D
        {
            Tensor t = new Tensor(27,89);
            assertEquals(2, t.getNDimensions(), 0);
            assertEquals(27*89, t.getNElements(), 0);
            assertEquals(27, t.getSize(0), 0);
            assertEquals(89, t.getSize(1), 0);
            for (int i = 0; i < 27; i++)
                for (int j = 0; j < 89; j++)
                assertEquals(0, t.get(i,j), 0);
        }
        
    }


    @Test
    public void testGetNDimensions() {
        assertEquals(1, t1.getNDimensions(), 0);
        assertEquals(2, t2.getNDimensions(), 0);
    }
    
    @Test
    public void testGetSize() {
        // getSize(dim)
        assertEquals(3, t1.getSize(0), 0);
        try {t1.getSize(1); fail("expected exception");}
        catch (IllegalArgumentException e){}
        
        assertEquals(2, t2.getSize(0), 0);
        assertEquals(3, t2.getSize(1), 0);
        try {t1.getSize(2); fail("expected exception");}
        catch (IllegalArgumentException e){}
        
        // getSize()
        int[] expectedT1 = {3};
        assertArrayEquals(expectedT1, t1.getSize());
        
        int[] expectedT2 = {2,3};
        assertArrayEquals(expectedT2, t2.getSize());
    }
    
    @Test
    public void testGetStride() {
        // getStride(dim)
        assertEquals(1, t1.getStride(0), 0);
        try {t1.getStride(1); fail("expected exception");}
        catch (IllegalArgumentException e){}
        
        assertEquals(3, t2.getStride(0), 0);
        assertEquals(1, t2.getStride(1), 0);
        try {t1.getSize(2); fail("expected exception");}
        catch (IllegalArgumentException e){}
        
        // getStride()
        int[] expectedT1 = {1};
        assertArrayEquals(expectedT1, t1.getStride());
        
        int[] expectedT2 = {3,1};
        assertArrayEquals(expectedT2, t2.getStride());
    }
    
    @Test
    public void testGetStorage() {
        // tested as part of copy constructor test
    }
    
    @Test
    public void testGetNElements() {
       assertEquals(3, t1.getNElements());
       assertEquals(6, t2.getNElements()); 
    }
    
    @Test
    public void testGetOffset() {
       assertEquals(0, t1.getOffset());
       assertEquals(0, t2.getOffset()); 
    }
    
    @Test 
    public void testGetSet() {
        // t1
        {
            for (int i = 0; i < t1.getSize(0); i++) {
                assertEquals(i+1, t1.get(i), 0);
                t1.set(i, i);
                assertEquals(i, t1.get(i), 0);
            }
            
            try {t1.set(-1, 100); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t1.set(3, 100); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t1.get(-1); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t1.get(3); fail("expected exception");}
            catch (IllegalArgumentException e) {}
        }
        
        // t2
        {
            for (int i = 0; i < t2.getSize(0); i++)
                for (int j = 0; j < t2.getSize(1); j++) {
                    t2.set(i, j, i + j);
                    assertEquals(i + j, t2.get(i, j), 0);
            }
            
            try {t2.set(-1, 0, 100); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.set(0, -1, 100); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.set(2, 0, 100); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.set(0, 3, 100); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.get(-1, 0); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.get(0, -1); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.get(2, 0); fail("expected exception");}
            catch (IllegalArgumentException e) {}
            
            try {t2.get(0, 3); fail("expected exception");}
            catch (IllegalArgumentException e) {}
        } 
    }
    
    // return 2^k
    private long powerOf2(int k) {
        if (k == 0)
            return 1;
        else
            return 2 * powerOf2(k - 1);
    }
    
    @Test
    public void testGetLongSetLong() {
        final boolean display = false;
        // one of these should fail
        
        {   // test t1
            int k;
            try {
                for (k = 0; k < 80; k++) {
                    // the stored value is 0 starting at k == 63
                    // for k == 62, it is negative
                    long power = powerOf2(k);  // an exact power of 2 of any long can be stored precisely
                    long stored = power - 1;
                    if (display)
                        System.out.println("k:" + k + " 2^k=" + power + " stored=" + stored);
                    t1.setLong(0, stored);
                    long retrieved = t2.getLong(0);
                    assertEquals(stored, retrieved, 0);
                }
                fail("expected exception");
            }
            catch (IllegalArgumentException e) {}
        }
        
        {   //test t2 
            int k;
            try {
                for (k = 0; k < 80; k++) {
                    // the stored value is 0 starting at k == 63
                    // for k == 62, it is negative
                    long power = powerOf2(k);  // an exact power of 2 of any long can be stored precisely
                    long stored = power - 1;
                    if (display)
                        System.out.println("k:" + k + " 2^k=" + power + " stored=" + stored);
                    t2.setLong(0, 0, stored);
                    long retrieved = t2.getLong(0, 0);
                    assertEquals(stored, retrieved, 0);
                }
                fail("expected exception");
            }
            catch (Tensor.LossOfPrecision e) {}
        }
    }
    
    @Test public void testNew1DInstance() {
        Tensor t = Tensor.new1DInstance(27.0, 64.0, 32.0);
        assertEquals(1, t.getNDimensions());
        assertEquals(3, t.getSize(0));
        assertEquals(27.0, t.get(0), 0);
        assertEquals(64.0, t.get(1), 0);
        assertEquals(32.0, t.get(2), 0);
    }
    
    @Test
    public void testNewIntance() {
        // 1D
        {
            Tensor n = Tensor.newInstance(t1);
            assertEquals(1, t1.getNDimensions());
            assertEquals(3, t1.getSize(0), 0);
            for (int i = 0; i < arrayT1.length; i++) {
                assertEquals(arrayT1[i], n.get(i), 0);
            }
            // check that storage is not coupled
            n.set(0, 27);
            assertTrue(27 != t1.get(0));
        }
        
        // 2D
        {
            Tensor n = Tensor.newInstance(t2);
            assertEquals(2, t2.getNDimensions());
            assertEquals(2, t2.getSize(0), 0);
            assertEquals(3, t2.getSize(1), 0);
            for (int i = 0; i < arrayT2.length; i++)
                for (int j = 0; j < arrayT2[0].length; j++) {
                    assertEquals(arrayT2[i][j], n.get(i,j), 0);
                }
            // check that storage is not coupled
            n.set(0, 0, 27);
            assertTrue(27 != t2.get(0,0));
        }
    }
        
    @Test
    public void testFill() {
        t1.fill(27);
        for (int i = 0; i < t1.getSize(0); i++)
            assertEquals(27, t1.get(i), 0);
        
        t2.fill(79);
        for (int i = 0; i < t2.getSize(0); i++)
            for (int j = 0; j < t2.getSize(1); j++)
                assertEquals(79, t2.get(i, j), 0);
    }
    
    @Test
    public void testZero() {
        t1.fill(27).fill(0);
        for (int i = 0; i < t1.getSize(0); i++)
            assertEquals(0, t1.get(i), 0);
        
        t2.fill(79).fill(0);
        for (int i = 0; i < t2.getSize(0); i++)
            for (int j = 0; j < t2.getSize(1); j++)
                assertEquals(0, t2.get(i, j), 0);
        
    }
    
    @Test public void testSelect() {
        Log log = new Log("TensorTest.testSelect", false);
        // T1
        try {t1.select(0,0); fail("expected exception");}
        catch (IllegalArgumentException e) {}
        
        
        // 2D dimension 0
        
        log.println("t2.select(0,0):" + t2.select(0,0));
        assertLikeT1(t2.select(0, 0), 1, 2, 3);
        log.println("t2.select(0,1):" + t2.select(0,1));
        assertLikeT1(t2.select(0, 1), 11, 12, 13);
        
        // 2D dimension 1
        
        assertTensor1D(t2.select(1, 0), 1, 11);
        assertTensor1D(t2.select(1, 1), 2, 12);
        assertTensor1D(t2.select(1, 2), 3, 13);
        
    }
    
    @Test public void testSelectRow() {
        assertLikeT1(t2.selectRow(0), 1, 2, 3);
        assertLikeT1(t2.selectRow(1), 11, 12, 13);
        
        try {t2.selectRow(-1); fail("expected exception");}
        catch (IllegalArgumentException e) {}
        try {t2.selectRow(2); fail("expected exception");}
        catch (IllegalArgumentException e) {}
        
        // storage should be coupled
        Tensor s = t2.selectRow(0);
        s.set(0, 27);
        assertEquals(27, s.get(0), 0);
        assertEquals(27, t2.get(0,0), 0);
        s.set(1, 64);
        assertEquals(64, t2.get(0,1), 0);
        s.set(2,42);
        assertEquals(42, t2.get(0,2), 0);
    }
    
    @Test public void testSelectColumn() {
        assertTensor1D(t2.selectColumn(0), 1, 11);
        assertTensor1D(t2.selectColumn(1), 2, 12);
        assertTensor1D(t2.selectColumn(2), 3, 13);
        
        try {t2.selectColumn(-1); fail("expected exception");}
        catch (IllegalArgumentException e) {}
        try {t2.selectColumn(3); fail("expected exception");}
        catch (IllegalArgumentException e) {}

        // storage should be coupled
        Tensor s = t2.selectRow(0);
        s.set(0, 27);
        assertEquals(27, s.get(0), 0);
        assertEquals(27, t2.get(0,0), 0);
    }
    
    @Test
    public void testT() {
        // transpose of 2D Tensor
        Log log = new Log("TensorTest.testT", false);
        Tensor transposed = t2.t();
        log.println("transposed:" + transposed);
        assertEquals(6, transposed.getNElements());
        assertEquals(3, transposed.getSize(0));
        assertEquals(2, transposed.getSize(1));
        assertEquals(1, transposed.get(0,0), 0);
        assertEquals(2, transposed.get(1,0), 0);
        assertEquals(3, transposed.get(2,0), 0);
        assertEquals(11, transposed.get(0,1), 0);
        assertEquals(12, transposed.get(1,1), 0);
        assertEquals(13, transposed.get(2,1), 0);
        
        // check that storage is shared
        t2.set(0, 0, 27);
        assertEquals(27, transposed.get(0,0), 0);
    }
    
    @Test public void testReshape() {
        Log log = new Log("TensorTest.testReshape", false);
        double[] array = {1,2,3,4,5,6};
        Tensor t = Tensor.newInstanceFromArray(array);
        t.reshape(3, 2);
        log.println("t:" + t);
        assertEquals(2, t.getNDimensions());
        assertEquals(6, t.getNElements());
        assertEquals(1, t.get(0,0), 0);
        assertEquals(2, t.get(0,1), 0);
        assertEquals(3, t.get(1,0), 0);
        assertEquals(4, t.get(1,1), 0);
        assertEquals(5, t.get(2,0), 0);
        assertEquals(6, t.get(2,1), 0);
        
        t.reshape(2,3);
        assertEquals(2, t.getNDimensions());
        assertEquals(6, t.getNElements());
        assertEquals(1, t.get(0,0), 0);
        assertEquals(2, t.get(0,1), 0);
        assertEquals(3, t.get(0,2), 0);
        assertEquals(4, t.get(1,0), 0);
        assertEquals(5, t.get(1,1), 0);
        assertEquals(6, t.get(1,2), 0);
        
        t.reshape(6, 1);
        assertEquals(2, t.getNDimensions());
        assertEquals(6, t.getNElements());
        assertEquals(1, t.get(0,0), 0);
        assertEquals(2, t.get(1,0), 0);
        assertEquals(3, t.get(2,0), 0);
        assertEquals(4, t.get(3,0), 0);
        assertEquals(5, t.get(4,0), 0);
        assertEquals(6, t.get(5,0), 0);
        
        try {t.reshape(4,2); fail("expected exception");}
        catch (IllegalArgumentException e) {}
    }
    
    @Test 
    public void testLog() {
        // this.log()
        Log log = new Log("TensorTest.testLog", false);
        // mutate this
        t1.log();
        for (int i = 0; i < arrayT1.length; i++)
            assertEquals(Math.log(arrayT1[i]), t1.get(i), 0);
        
        t2.log();
        for (int i = 0; i < arrayT2.length; i++)
            for (int j = 0; j < arrayT2[0].length; j++) {
                //log.format("i=%d j=%d%n", i, j);
                log.format("t2[%d,%d]=%f%n", i, j, t2.get(i,j));
                assertEquals(Math.log(arrayT2[i][j]), t2.get(i,j), 0);
            }
    }
    
    @Test public void testLogTensor() {
        // return log(x)
        {

            Tensor r = Tensor.log(t1);
            for (int i = 0; i < arrayT1.length; i++)
                assertEquals(Math.log(arrayT1[i]), r.get(i), 0);
        }
        {
            Tensor r = Tensor.log(t2);
            for (int i = 0; i < arrayT2.length; i++)
                for (int j = 0; j < arrayT2[0].length; j++) 
                    assertEquals(Math.log(arrayT2[i][j]), r.get(i,j), 0);
        }
    }
    
    @Test 
    public void testMean() {
        // test example is from Wikipedia at "Standard deviation"
        double[] array = {2D, 4D, 4D, 4D, 5D, 5D, 7D, 9D};
        Tensor t = Tensor.newInstanceFromArray(array);
        
        assertEquals(5.0, Tensor.mean(t), 0);
    }
    
    @Test
    public void testStd() {
        // test example is from Wikipedia at "Standard deviation"
        double[] array = {2D, 4D, 4D, 4D, 5D, 5D, 7D, 9D};
        Tensor t = Tensor.newInstanceFromArray(array);
        
        assertEquals(2.0, Tensor.std(t), 0);
    }
    
    @Test
    public void testVar() {
        // test example is from Wikipedia at "Variance"
        double[] array = {1,2,3,4,5,6};
        Tensor t = Tensor.newInstanceFromArray(array);
        
        assertEquals(3.5, Tensor.mean(t), 0);
        assertEquals(2.916667, Tensor.var(t), 1e-5);
    }
    
    @Test
    public void testAddToSelf() {
        // self.add(x)
        assertLikeT1(t1.add(1), 2, 3, 4);
        assertLikeT2(t2.add(-1), 0, 1, 2, 10, 11, 12);
    }
    
    @Test public void testAddDouble() {
        // this += value
        t1.add(1);
        assertLikeT1(t1, 2, 3, 4);
        
        t2.add(-1);
        assertLikeT2(t2, 0, 1, 2, 10, 11, 12);
    }
    
    @Test public void testAddTensorTensor() {
        Log log = new Log("TensorTest.testAddTensorTensor", false);
        // return x + y
        assertLikeT1(Tensor.add(t1, t1), 2, 4, 6);
        assertLikeT2(Tensor.add(t2, t2), 2, 4, 6, 22, 24, 26);
        // example from http://www.torch.ch/manual/torch/maths#res_torchcdiv_res_tensor1_tensor2
        // example modified, as the calls below are not what is in the torch7 documentation!
        Tensor x = new Tensor(2,2).fill(2);
        Tensor y = new Tensor(4).fill(4);
        Tensor z = Tensor.add(x,y);
        log.println("z:" + z);
        assertEquals(2, z.getNDimensions());
        assertEquals(6, z.get(0,0), 0);
        assertEquals(6, z.get(0,1), 0);
        assertEquals(6, z.get(1,0), 0);
        assertEquals(6, z.get(1,1), 0);
        
    }
    
    @Test // Tensor.add(Tensor,double): Tensor
    public void testAddTensorValue() {
        // return add(Tensor,double)
        assertLikeT1(Tensor.add(t1, 1), 2, 3, 4);
        assertLikeT2(Tensor.add(t2, -1), 0, 1, 2, 10, 11, 12);
    }
    
    @Test public void testDivTensorDouble() {
        // return x / value
        assertLikeT1(Tensor.div(t1, 4), 1.0/4, 2.0/4, 3.0/4);
        assertLikeT2(Tensor.div(t2, 4), 1.0/4, 2.0/4, 3.0/4, 11.0/4, 12.0/4, 13.0/4);
    }
    
    @Test public void testCDivTensorTensor() {
        // return x / y
        // example is from torch7 documentations:
        // ref: http://www.torch.ch/manual/torch/maths#res_torchcdiv_res_tensor1_tensor2
        
        Log log = new Log("testCDivTensorTensor", false);
        
        {
            // 1D-1D
            Tensor x = new Tensor(4).fill(1);
            Tensor y = new Tensor(4);
            for (int i = 0; i < 4; i++)
                y.set(i, i+1);
            Tensor r = Tensor.cdiv(x, y);
            log.println("x:" + x);
            log.println("y:" + y);
            log.println("r:" + r);
            assertEquals(1, r.get(0), 0);
            assertEquals(0.5, r.get(1), 0);
            assertEquals(0.333333, r.get(2), 1e-5);
            assertEquals(0.2500, r.get(3), 1);
        }
        
        {
            // 1D-2D
            Tensor x = new Tensor(4).fill(1);
            Tensor y = new Tensor(2,2);
            int count = 1;
            for (int i = 0; i < 2; i++)
                for (int j = 0; j < 2; j++) {
                    y.set(i, j, count);
                    count++;
                }
            Tensor r = Tensor.cdiv(x, y);
            assertEquals(1, r.get(0), 0);
            assertEquals(0.333333, r.get(1), 1e-5);
            assertEquals(0.5000, r.get(2), 0);
            assertEquals(0.2500, r.get(3), 1);
        }
        
        {
            // 2D-1D
            Tensor x = new Tensor(2,2).fill(1);
            Tensor y = new Tensor(4);
            for (int i = 0; i < 4; i++)
                y.set(i, i+1);
            Tensor r = Tensor.cdiv(x, y);
            log.println("r:" + r);
            assertEquals(1, r.get(0,0), 0);
            assertEquals(0.333333, r.get(0,1), 1e-5);
            assertEquals(0.5000, r.get(1,0), 0);
            assertEquals(0.2500, r.get(1,1), 1);
        }
        
        {
            // 2D-2D
            Tensor x = new Tensor(2,2).fill(1);
            Tensor y = new Tensor(2,2);
            int count = 1;
            for (int i = 0; i < 2; i++)
                for (int j = 0; j < 2; j++) {
                    y.set(i, j, count);
                    count++;
                }
            log.println("y:" + y);
            Tensor r = Tensor.cdiv(x, y);
            assertEquals(1, r.get(0,0), 0);
            assertEquals(0.5, r.get(0,1), 0);
            assertEquals(0.333333, r.get(1,0), 1e-6);
            assertEquals(0.2500, r.get(1,1), 0);
        }

    }
    
    @Test public void testDist() {
        // distance between two tensors
        double[] arrayX1 = {1,2,3};
        double[] arrayY1 = {11,12,13};
        double[][] arrayX2 = {{1,2},{3,4}};
        double[][] arrayY2 = {{11,12},{13,14}};
        Tensor x1 = Tensor.newInstanceFromArray(arrayX1);
        Tensor y1 = Tensor.newInstanceFromArray(arrayY1);
        Tensor x2 = Tensor.newInstanceFromArray(arrayX2);
        Tensor y2 = Tensor.newInstanceFromArray(arrayY2);
        
        // 1D
        assertEquals(17.320508, Tensor.dist(x1, y1), 1e-6); // 2 norm distance
        assertEquals(30, Tensor.dist(x1, y1, 1), 1e-6); // 1 norm (taxicab distance)
        assertEquals(17.320508, Tensor.dist(x1, y1, 2), 1e-6); // 2 norm again
        assertEquals(10.11047, Tensor.dist(x1, y1, 100), 1e-5); // an approximation to the the max norm

        // 2D
        assertEquals(20, Tensor.dist(x2, y2), 1e-6); // 2 norm distance
        assertEquals(40, Tensor.dist(x2, y2, 1), 1e-6); // 1 norm (taxicab distance)
        assertEquals(20, Tensor.dist(x2, y2, 2), 1e-6); // 2 norm again
        assertEquals(10.13959, Tensor.dist(x2, y2, 100), 1e-5); // an approximation to the the max norm
        
        // 1D and 2D
        double[] zArray = {0,1,3,5};
        Tensor z1 = Tensor.newInstanceFromArray(zArray);
        assertEquals(20.663978, Tensor.dist(z1, y2), 1e-6);
        assertEquals(41, Tensor.dist(y2, z1, 1), 0);
        
        try {Tensor.dist(x1, z1); fail("expected exception");}
        catch (IllegalArgumentException e){}
        
    }
    
    @Test public void testDot() {
        // dot product
        Tensor other = new Tensor(3).fill(5);
        
        // operate on this
        {
            double result = t1.dot(other);
            assertEquals(30, result, 0);
            assertLikeT1(t1, 1, 2, 3);   // does not mutate
        }
        // static version
        {
            double result = Tensor.dot(t1, other);
            assertEquals(30, result, 0);
            assertLikeT1(t1, 1, 2, 3);
            assertLikeT1(other, 5, 5, 5);
        }
        
    }
    
    @Test
    public void testAddT2DotT1() {
        // matrix-vector multiplication
        
        double[][] aArray = {{14, 9, 3}, {2, 11, 15}, {0, 12, 17}, {5, 2, 3}};
        Tensor a = Tensor.newInstanceFromArray(aArray);  // 4 x 3
        
        double[] vectorArray = {1, 2, 3};
        Tensor vector = Tensor.newInstanceFromArray(vectorArray); // 3 x 1
        
        {   // av is a mat 4 x 1
            Tensor av = new Tensor(4,1).fill(1);
            av.addT2DotT1(3, a, vector);
            assertEquals(1 + 3*41, av.get(0,0), 0); 
            assertEquals(1 + 3*69, av.get(1,0), 0);
            assertEquals(1 + 3*75, av.get(2,0), 0);
            assertEquals(1 + 3*18, av.get(3,0), 0);
        }
        
        {   // av is a vec with 4 elements
            Tensor av = new Tensor(4).fill(1);
            av.addT2DotT1(3, a, vector);
            assertEquals(1 + 3*41, av.get(0), 0);
            assertEquals(1 + 3*69, av.get(1), 0);
            assertEquals(1 + 3*75, av.get(2), 0);
            assertEquals(1 + 3*18, av.get(3), 0);
        }

    }
    
    @Test
    public void testAdddT2dotT2() {
        // matrix-matrix multiplication
        
        // test example is from wikipedia at "matrix multiplication"
        double[][] aArray = {{14, 9, 3}, {2, 11, 15}, {0, 12, 17}, {5, 2, 3}};
        Tensor a = Tensor.newInstanceFromArray(aArray);  // 4 x 2
        
        double[][] bArray = {{12, 25}, {9, 10}, {8, 5}};
        Tensor b = Tensor.newInstanceFromArray(bArray);  // 2 x 2
        
        Tensor c = (new Tensor(4,2)).fill(1);
        c.addT2DotT2(3, a, b);
        assertEquals(1 + 3*273, c.get(0,0), 0);
        assertEquals(1 + 3*455, c.get(0,1), 0);
        assertEquals(1 + 3*243, c.get(1,0), 0);
        assertEquals(1 + 3*235, c.get(1,1), 0);
        assertEquals(1 + 3*244, c.get(2,0), 0);
        assertEquals(1 + 3*205, c.get(2,1), 0);
        assertEquals(1 + 3*102, c.get(3,0), 0);
        assertEquals(1 + 3*160, c.get(3,1), 0);
        
        Tensor bb = new Tensor(2,2);
        try {c.addT2DotT2(1, a, bb); fail("expected exception");}
        catch (IllegalArgumentException e) {}
    }
}
