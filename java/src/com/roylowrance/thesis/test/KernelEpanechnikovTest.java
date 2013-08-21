package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.*;

import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

public class KernelEpanechnikovTest {
    Tensor a;
    Tensor b;
    Tensor c;
    Tensor all;
    Distance distance;

    @Before
    public void setUp() {
        Log log = new Log("KernelEpanechnikovTest.setUp", true);
        a = makeTensor1(1);
        b = makeTensor1(2);
        c = makeTensor1(3);
        all = makeTensor2(a, b, c);
        log.println("all:" + all);
        distance = new DistanceEuclidean();
    }
    
    // return 1D tensor of size 1
    private Tensor makeTensor1(double x) {
        Tensor result = new Tensor(1);
        result.set(0, x);
        return result;
    }
    
    // return 2D tensor of shape n x 1
    private Tensor makeTensor2(Tensor...tensor1D) {
        final int numberRows = tensor1D.length;
        Tensor result = new Tensor(numberRows, 1);
        for (int rowNumber = 0; rowNumber < numberRows; rowNumber++) {
            assertEquals(1, tensor1D[rowNumber].getNDimensions());
            result.set(rowNumber, 0, tensor1D[rowNumber].get(0));
        }
        return result;
    }
    
    private Hp hp(double bandwidth) {
        return new Hp.Builder().bandwidth(bandwidth).build();
    }

    @Test
    public void testApplyDistanceIdx1Idx1Hp() {
        Kernel k = new KernelEpanechnikov();
        assertEquals(0, k.apply(distance, a, b, hp(0.2)), 0);
        assertEquals(0, k.apply(distance, a, b, hp(1.0)), 0);
        assertEquals(9.0 / 16.0, k.apply(distance, a, b, hp(2.0)), 0);
    }

    @Test
    public void testApplyDistanceIdx2IntIntHp() {
        Kernel k = new KernelEpanechnikov();
        assertEquals(0, k.apply(distance, all, 0, 1, hp(0.2)), 0);
        assertEquals(0, k.apply(distance, all, 0, 1, hp(1.0)), 0);
        assertEquals(9.0 / 16.0, k.apply(distance, all, 0, 1, hp(2.0)), 0);
    }

}
