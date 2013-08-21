package com.roylowrance.thesis.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Before;
import org.junit.Test;

import com.roylowrance.thesis.CheckGradient;
import com.roylowrance.thesis.LossFunction;
import com.roylowrance.thesis.LossGradient;
import com.roylowrance.thesis.StochasticGradient;
import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

// Another ref is leroux-12 stochastic gradient method with exponential convergence rate
public class StochasticGradientTest {
    boolean exampleFunctorCalled;
    boolean iterationFunctorCalled;
    Tensor xs; // n x 1
    Tensor ys; // n

    @Before
    public void setUp() throws Exception {
        exampleFunctorCalled = false;
        iterationFunctorCalled = false;
        xs = makeXs(0, 1, 2, 3);
        ys = makeYs(1, 3, 5, 7);
    }

    private Tensor makeXs(Integer... examples) {
        final int n = examples.length;
        final int dimensions = 1;
        Tensor result = new Tensor(n, dimensions);
        for (int i = 0; i < n; i++) {
            result.set(i, 0, examples[i]);
        }
        return result;
    }

    private Tensor makeYs(Integer... ys) {
        Tensor result = new Tensor(ys.length);
        for (int i = 0; i < ys.length; i++) {
            result.set(i, ys[i]);
        }
        return result;
    }

    // functor to compute loss function
    // needed only to test the MyGradient functor
    // loss = (predicted - actual)^2
    // predicted = w1 * x + w2
    // actual = y
    class MyLossFunction implements LossFunction {
        @Override
        public double apply(Tensor weights, int exampleIndex) {
            Log log = new Log("StochasticGradientTest.MyLossFunction.apply", false);
            assertEquals(1, weights.getNDimensions());
            assertEquals(2, weights.getSize(0));
            double w1 = weights.get(0);
            double w2 = weights.get(1);
            double x = xs.get(exampleIndex, 0);
            double predicted = x * w1 + w2;
            double y = ys.get(exampleIndex);
            double error = predicted - y;
            double result = error * error;
            log.println("weights:" + weights);
            log.println("x:" + x);
            log.println("y:" + y);
            log.println("result:" + result);
            return result;
        }
    }

    // functor to compute gradient
    class MyGradient implements LossGradient {
        @Override
        public Tensor apply(Tensor weights, int exampleIndex) {
            Log log = new Log("StochasticGradientTest.MyGradient.apply", false);
            assertEquals(1, weights.getNDimensions());
            assertEquals(2, weights.getSize(0));
            double w1 = weights.get(0);
            double w2 = weights.get(1);
            double x = xs.get(exampleIndex, 0);
            double y = ys.get(exampleIndex);
            double c0 = 2 * (w1 * x + w2 - y) * x;
            double c1 = 2 * (w1 * x + w2 - y);
            Tensor result = new Tensor(2);
            result.set(0, result.get(0) + c0);
            result.set(1, result.get(1) + c1);
            log.println("weights:" + weights);
            log.println("xs:" + xs);
            log.println("y:" + y);
            log.println("result:" + result);
            return result;
        }
    }

    @Test
    public void TestGradient() {
        final int weightDimensions = 2;
        final int exampleDimensions = 2;
        final double tolerance = 0.05;
        // next statement throws if LossGradient is not the gradient for MyLossFunction
        new CheckGradient(weightDimensions, exampleDimensions).apply(new MyLossFunction(), new MyGradient(), tolerance);
    }

    // // test with rosebrock function
    // @Test public void TestRosenbrock() {
    // private Tensor examples;
    // class RosenbrockLossGradient implements LossGradient {
    // @Override public Tensor apply(Tensor weights, int exampleIndex) {
    // Tensor xTensor = examples.selectRow(exampleIndex);
    // double x = xTensor.get(0);
    // double y = xTensor.get(1);
    // double dx = 2 * (1 - x) * (-1) + 200 * (y - x * x) * (-2 * x);
    // double dy = 200 * (y - x * x);
    // }
    // }
    // }
    //
    // }
    //

    // functor to compute gradient over all samples

    // function is f(x,w) = w1 * x + w2
    // The gradient is for the loss function, not f!
    // MyLossFunction(w) == \sum_i Loss_(w, x_i) = \sum_i Loss_i(w,x_i)
    // Loss_i((w1,w2), (xi,yi)) = (predicted - actual) ^2 = (w1 xi + w2 - yi)^2
    // D_{w1} MyLossFunction = 2 (w1 xi + w2 - y) xi
    // D_{w2} MyLossFunction = 2 (w1 xi + w2 - y
    private class MyLossGradient implements LossGradient {
        @Override
        public Tensor apply(Tensor parameters, int exampleIndex) {
            Log log = new Log("StochasticGradientTest.MyLossGradient.apply", true);
            log.println("parameters:" + parameters);
            log.println("exampleIndex:" + exampleIndex);

            assertEquals(1, parameters.getNDimensions());
            assertEquals(2, parameters.getSize(0));
            double w1 = parameters.get(0);
            double w2 = parameters.get(1);
            double x = xs.get(exampleIndex, 0);
            double y = ys.get(exampleIndex);

            Tensor result = new Tensor(2);
            final double factor = 2 * (w1 * x + w2 - y);
            result.set(0, factor * x);
            result.set(1, factor);

            log.println("x:" + x);
            log.println("y:" + y);
            log.println("result:" + result);
            return result;
        }
    }

    private class TestHookExample implements StochasticGradient.HookExample {
        @Override
        public boolean apply(StochasticGradient sgd, Tensor x, double y) {
            Log log = new Log("StochasticGradient.TestExampleFunctor.apply", false);
            log.println("x:" + x);
            log.println("y:" + y);
            exampleFunctorCalled = true;
            return false;
        }
    }

    private class TestHookIteration implements StochasticGradient.HookIteration {
        @Override
        public boolean apply(StochasticGradient sgd, int iterationNumber) {
            Log log = new Log("StochasticGradient.TestIterationFunctor.apply", false);
            iterationFunctorCalled = true;
            log.println("iterationNumber:" + iterationNumber);
            return false;
        }
    }

    @Test
    public void testFitLine() {
        Log log = new Log("StochasticGradientDescent.testFitLine", true);
        final boolean display = true;
        // fit straight line through sample points
        LossGradient gradientFunctor = new MyLossGradient();
        final int gradientDimensions = 2;
        final double learningRate = 0.01;
        final double learningRateDecay = 1;
        final boolean shuffleIndices = true;
        StochasticGradient.HookExample hookExample = new TestHookExample();
        StochasticGradient.HookIteration hookIteration = new TestHookIteration();
        final boolean useStochasticAverageGradient = false;

        StochasticGradient sgd = new StochasticGradient(xs, ys, gradientDimensions, gradientFunctor, learningRate, learningRateDecay,
                shuffleIndices, hookExample, hookIteration, useStochasticAverageGradient);
        log.println("initial parameters:" + sgd.getParameters());
        Tensor parameters = null;
        for (int epoch = 1; epoch <= 10000; epoch++) {
            parameters = sgd.iterate(1); // run 1 epoch for each call
            if (display)
                System.out.format("epoch %5d w1 %17.15f w2 %17.15f RMSE %17.15f %n", epoch, parameters.get(0), parameters.get(1),
                        rmse(parameters, xs, ys));
        }
        // Tensor result = sgd.iterate(4);
        // log.println("result:" + result);
        assertEquals(2, parameters.get(0), .15);
        assertEquals(1, parameters.get(1), .15);
        assertTrue(exampleFunctorCalled);
        assertTrue(iterationFunctorCalled);
    }

    // return RMSE given parameters and examples
    private double rmse(Tensor parameters, Tensor xs, Tensor ys) {
        double sumSquaredErrors = 0;
        double w1 = parameters.get(0);
        double w2 = parameters.get(1);
        for (int i = 0; i < xs.getSize(0); i++) {
            double x = xs.get(i, 0);
            double actual = ys.get(i);
            double estimate = w1 * x + w2;
            double error = actual - estimate;
            sumSquaredErrors += error * error;
        }
        return Math.sqrt(sumSquaredErrors);
    }

}
