package com.roylowrance.thesis.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.util.Random;

import com.roylowrance.thesis.LogisticRegression;

import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

public class LogisticRegressionTest {
    Random random;
    int numberClasses;
    Tensor betas;

    int numberObservations;
    Tensor xs;
    Tensor probs;
    
    Tensor prob0;
    Tensor prob1;
    Tensor prob2;
    
    Tensor classes;
    
    @Before
    public void setUp() throws Exception {
        // generate synthetic data
        Log log = new Log("LogisticRegressionTest.setUp", true);
        
        random = new Random(27); // set random number generator
        
        // 3 classes: 0, 1, 2
        numberClasses = 3;
        betas = makeBetas();
        
        numberObservations = 20;
        xs = makeXs(numberObservations, 3);
        log.println("xs:" + xs);
        probs = makeProbs(betas, xs);
        
        prob0 = makeProbs(betas.selectRow(0), xs);
        prob1 = makeProbs(betas.selectRow(1), xs);
        prob2 = makeProbs(betas.selectRow(2), xs);
        
        classes = makeClasses(probs);
       
        printXsProbsClasses();
    }
    
    private Tensor makeClasses(Tensor probs) {
        Tensor result = new Tensor(probs.getSize(0));
        for (int i = 0; i < probs.getSize(0); i++) {
            int maxIndex = 0;
            double max = 0;
            for (int k = 0; k < probs.getSize(1); k++)
                if (probs.get(i,k) > max) {
                    max = probs.get(i,k);
                    maxIndex = k;
                }
            result.set(i, maxIndex);
        }
        return result;
    }
    
    private void printXsProbsClasses() {
        System.out.format("%2s %5s %5s %5s  %4s %4s %4s %1s%n",
                " i", "xi0", "xi1", "xi2", "pi0", "pi1", "pi2", "C");
        for (int i = 0; i < numberObservations; i++) {
            System.out.format("%2d %5.2f %5.2f %5.2f  %4.2f %4.2f %4.2f %1d%n",
                    i, xs.get(i,0), xs.get(i,1), xs.get(i,2), probs.get(i,0), probs.get(i,1), probs.get(i,2), (int) classes.get(i));
        }
    }
    
    private Tensor makeBetas() {
        Tensor result = new Tensor(3,3);
        //setRow(result, 0, makeTensor1D(10.,-11.0,-12.0));
        setRow(result, 0, makeTensor1D(0.,0.,0.)); // first is vector 0 
        setRow(result, 1, makeTensor1D(1.,2.,3.));
        setRow(result, 2, makeTensor1D(4.,-5.,6.));
        return result;
    }
    
    private void setRow(Tensor t, int rowNumber, Tensor row) {
        t.set(rowNumber, 0, row.get(0));
        t.set(rowNumber, 1, row.get(1));
        t.set(rowNumber, 2, row.get(2));
    }
    
    // return dot product of beta_i and x[j:]
    private double dot(int i, int j) {
        return Tensor.dot(betas.selectRow(i), xs.selectRow(j));
    }
    
    // return prob(y_i = j | x_i)
    private double prob_ij(int i, int j) {
        Log log = new Log("LogisticRegressionTest.prob_ij", true);
        log.println("beta[" + j + ":]=" + betas.selectRow(j));
        log.println("xs[" + i + ":]=" + xs.selectRow(i));
        double numerator = Math.exp(Tensor.dot(betas.selectRow(j), xs.selectRow(i)));

        double denominator= 1;
        for (int k = 1; k < numberClasses; k++) {
            denominator += Math.exp(Tensor.dot(betas.selectRow(k), xs.selectRow(i)));
        }
        
        double result = numerator / denominator;
        log.format("i %2d j %2d numerator %8.2f denominator %8.2f result %6f%n", i, j, numerator, denominator, result);
        return result;
    }

    private Tensor makeProbs(Tensor betas, Tensor xs) {
        Log log = new Log("LogisticRegressionTest.makeProbs", true);
        log.println("xs:" + xs);
        log.println("betas:" + betas);
        Tensor result = new Tensor(xs.getSize(0), betas.getSize(0));
        for (int i = 0; i < xs.getSize(0); i++)
            for (int j = 0; j < betas.getSize(0); j++) {
                result.set(i, j, prob_ij(i, j));
            }
        return result;
    }
    
    private Tensor makeXs(int numberRows, int numberColumns) {
        //int counter = 0;
        Tensor result = new Tensor(numberRows, numberColumns);
        for (int i = 0; i < numberRows; i++) {
            result.set(i, 0, 1);
            for (int j = 1; j < numberColumns; j++) {
                result.set(i, j, random.nextGaussian());
                //counter++;
            }
        }
        return result;
    }
    
    private Tensor makeTensor1D(Double...values) {
        final int size = values.length;
        Tensor result = new Tensor(size);
        for (int i = 0; i < size; i++)
            result.set(i, values[i]);
        return result;
    }

    // TODO: implement test in the paper that says whether the logistic regression worked
    @Test
    public void test() {
        LogisticRegression lr = new LogisticRegression(xs, classes);
        double tolerance = 1e-3;
        lr.train(tolerance);
        // predict and compare each training sample point
        for (int i = 0; i < xs.getSize(0); i++) {
            double prediction = lr.predict(xs.selectRow(i));
            assertEquals(classes.get(i), prediction, 0);
        }
        
        fail("Not yet implemented");
    }

}
