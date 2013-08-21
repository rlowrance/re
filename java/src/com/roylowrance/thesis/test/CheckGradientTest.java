package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;


import com.roylowrance.thesis.CheckGradient;
import com.roylowrance.thesis.LossFunction;
import com.roylowrance.thesis.LossGradient;

import com.roylowrance.util.*;


public class CheckGradientTest {

    @Before
    public void setUp() throws Exception {
    }
    
    // functor to implement w0 * x * y + w1 * x + w2 * y + w4
    class MyFunction implements LossFunction {
        private Tensor xs;
        private Tensor ys;
        
        public MyFunction(Tensor xs, Tensor ys) {
            this.xs = xs;
            this.ys = ys;
        }
        
        @Override public double apply(Tensor weights, int exampleIndex) {
            assertEquals(1, weights.getNDimensions());
            assertEquals(4, weights.getSize(0));
            double w0 = weights.get(0);
            double w1 = weights.get(1);
            double w2 = weights.get(2);
            double w3 = weights.get(3);
            
            double x0 = xs.get(exampleIndex, 0);
            double x1 = xs.get(exampleIndex, 1);
            double y = ys.get(exampleIndex);
            
            double error = w0 * x0 * x1 + w1 * x0 + w2 * x1 + w3 - y;
            
            return error * error;
        }
    }
    
    // functor to return the gradient of f(x,y)
    // gradient_f(x,y) = (w0*y + w1, w0*x+w2)
    class MyGradient implements LossGradient {
        private Tensor xs;
        private Tensor ys;
        
        public MyGradient(Tensor xs, Tensor ys) {
            this.xs = xs;
            this.ys = ys;
        }
        
        @Override public Tensor apply(Tensor weights, int exampleIndex) {
            Log log = new Log("CheckGradientTest.Gradient.apply", true);
            assertEquals(1, weights.getNDimensions());
            assertEquals(4, weights.getSize(0));
            double w0 = weights.get(0);
            double w1 = weights.get(1);
            double w2 = weights.get(2);
            double w3 = weights.get(3);
            
            final double x0 = xs.get(exampleIndex, 0);
            final double x1 = xs.get(exampleIndex, 1);
            final double y = ys.get(exampleIndex);
            
            double fw3 = 2 * (w0 * x0 * x1 + w1 * x0 + w2 * x1 + w3 - y);
            double fw2 = fw3 * x1;
            double fw1 = fw3 * x0;
            double fw0 = fw3 * x0 * x1;
            
            Tensor result = new Tensor(4);
            result.set(0, fw0);
            result.set(1, fw1);
            result.set(2, fw2);
            result.set(3, fw3);
            
            return result;
        }
    }
    
    // functor to return the gradient of f(x,y), but contains a mistake, leaving off the constants
    // gradient_f(x,y) = (2y+3, 2x+4)
    // however, by mistake, forget to subtract y
    class GradientBad implements LossGradient {
        Tensor xs;
        Tensor ys;
        
        public GradientBad(Tensor xs, Tensor ys) {
            this.xs = xs;
            this.ys = ys;
        }
        
        @Override public Tensor apply(Tensor weights, int exampleIndex) {
            Log log = new Log("CheckGradientTest.Gradient.apply", true);
            assertEquals(1, weights.getNDimensions());
            assertEquals(4, weights.getSize(0));
            double w0 = weights.get(0);
            double w1 = weights.get(1);
            double w2 = weights.get(2);
            double w3 = weights.get(3);
            
            final double x0 = xs.get(exampleIndex,0);
            final double x1 = xs.get(exampleIndex,1);
            final double y = ys.get(exampleIndex);
            
            double fw3 = 2 * (w0 * x0 * x1 + w1 * x0 + w2 * x1 + w3);  // leave out y (on purpose)
            double fw2 = fw3 * x1;
            double fw1 = fw3 * x0;
            double fw0 = fw3 * x0 * x1;
            
            Tensor result = new Tensor(4);
            result.set(0, fw0);
            result.set(1, fw1);
            result.set(2, fw2);
            result.set(3, fw3);
            
            return result;
        }
    }
  
    
    @Test
    public void testApplyGood() {
        final int weightSize = 4;
        final int exampleSize = 2;
        CheckGradient cg = new CheckGradient(weightSize, exampleSize);
        Tensor xs = cg.getXs();
        
        Tensor ys = cg.getYs();
        
        // test success
        final LossFunction function = new MyFunction(xs, ys);
        final LossGradient lossGradient = new MyGradient(xs, ys);
        final double tolerance = 1e-10;
        cg.apply(function, lossGradient, tolerance);
    }
    
    @Test
    public void testApplyBad() {
        final int weightSize = 4;
        final int exampleSize = 2;
        CheckGradient cg = new CheckGradient(weightSize, exampleSize);
        Tensor xs = cg.getXs();
        
        Tensor ys = cg.getYs();
        
        final LossFunction function = new MyFunction(xs, ys);
        final double tolerance = 1e-10;
        
        // test badly written gradient functor
        try {cg.apply(function, new GradientBad(xs, ys), tolerance); fail("expected exception");}
        catch (RuntimeException e) {}
    }

}
