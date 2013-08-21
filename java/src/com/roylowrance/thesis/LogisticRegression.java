package com.roylowrance.thesis;

import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

/**
 * Carry out logistic regression.
 * 
 * Overview:
 * lr = new LogisticRegression(allFeatures, classes);
 * lr.train(tolerance);
 * Tensor predictedClass = lr.predict(observationFeatures);
 * 
 * Another interface is
 * lr = <as before>
 * repeat Tensor parameters = lr.iterate(); until <converged>
 * Tensor predictedClass = lr.predict(observationFeatures);
 * @author Roy Lowrance
 *
 */
public class LogisticRegression {
    private Tensor features;          // shape is numberObservations x numberDimensions
    private Tensor classes;           // shape is numberObservations
    
    private int numberClasses;        // called J in Greene p803
    private int numberDimensions;     // size of each feature = size of gradient vector
    private int numberObservations;   // in features
    private int numberParameters;     // numberDimensions * (numberClasses - 1)
    
    private StochasticGradient stochasticGradient;  // use to approximately solve for the parameters
    
    private Tensor trainedParameters;  // set by the stochastic gradient search
    
    /**
     * Construct from features and classes
     * 
     * @param features Tensor 2D
     *      first column must be always value 1.0
     *      an observation is a row in features[i:]
     * @param classes Tensor 1D
     *      values must be integers >= 0
     *      these are the class numbers for each observation
     *      class 0 must be used (it becomes the base case for the log-odds ratios)
     */
    public LogisticRegression(Tensor features, Tensor classes) {
        Log log = new Log("LogisticRegression", true);
        if (features.getNDimensions() != 2)
            throw new IllegalArgumentException("features must be 2D; features=" + features);
        this.features = features;
       
        this.numberObservations = features.getSize(0);
        this.numberDimensions = features.getSize(1);
        
        log.format("number observations %d dimensions %d%n", numberObservations, numberDimensions);
        
        // verify that 1st feature is always 1
        for (int i = 0; i < numberObservations; i++) {
            if (features.get(i,0) == 1.0)
                continue;
            throw new IllegalArgumentException("first feature not 1 in observation i=" + i);
        }
        
        if (classes.getNDimensions() != 1) 
            throw new IllegalArgumentException("classes must be 1D; classes=" + classes);
        if (classes.getSize(0) != numberObservations)
            throw new IllegalArgumentException("classes has different # observations than fetures; classes=" + classes);
        this.classes = classes;
        
        // verify that each class is an integer >= 0
        // determine the number of classes (= max class value)
        double maxClass = 0;
        boolean classZeroFound = false;
        for (int i = 0; i < numberObservations; i++) {
            double theClass = classes.get(i);
            if (Math.floor(theClass) != theClass)
                throw new IllegalArgumentException("classes[" + i + "]=" + theClass + " is not an integer");
            if (theClass < 0)
                throw new IllegalArgumentException("classes[" + i + "]=" + theClass + " is < 0");
            if (theClass > maxClass)
                maxClass = theClass;
            if (theClass == 0)
                classZeroFound = true;
        }
        numberClasses = 1 + (int) maxClass;
        log.format("number classes %d%n", numberClasses);
        
        // verify that each class number 0, 1, 2, ..., maxClass is coded
        Tensor classNumberIsUsed = new Tensor(numberClasses + 1);  // initially all zeroes
        for (int i = 0; i < numberObservations; i++) {
            classNumberIsUsed.set((int) classes.get(i), 1);
        }
        for (int c = 0; c <= numberClasses + 1; c++)
            if (classNumberIsUsed.get(c) == 0)
                throw new IllegalArgumentException("class " + c + " is not coded");
        
        // Estimate a beta vector for each class j= 1, 2, ..., numberClasses
        // The beta vector is of size numberDimensions
        numberParameters = (numberClasses - 1) * numberDimensions;
        
        log.format("number parameters %d%n", numberParameters);
        
        // initialize the stochasticGradient instance
        final double learningRate = 0.01;
        final double learningRateDecay = 10000.0;
        final boolean shuffleIndices = false; // TODO: change after debugging
        final StochasticGradient.HookExample hookExample = null;
        final StochasticGradient.HookIteration hookIteration = null;
        final boolean useStochasticAverageGradient = false; // consider testing with true; is it then faster? 
        
        stochasticGradient = new StochasticGradient(
                features,
                classes,
                numberParameters,
                new MyLossGradient(),
                learningRate,
                learningRateDecay,
                shuffleIndices,
                hookExample,
                hookIteration,
                useStochasticAverageGradient);
    }
    
    // return the j-th beta from the parameters
    // The parameters store beta for j = 1, ..., numberClasses
    // For j = 0, beta_0 = 0
    private Tensor beta(Tensor parameters, int j) {
        Log log = new Log("LogisticRegression.beta", true);
        if (parameters.getNDimensions() != 1)
            throw new IllegalArgumentException("parameters must be 1D; parameters=" + parameters);
        if (j < 0)
            throw new IllegalArgumentException("j < 0; j=" + j);
        if (j > numberClasses)
            throw new IllegalArgumentException("j exeeds number of classes (" + numberClasses +") ; j=" + j);
        
        Tensor result = new Tensor(numberDimensions);
        for (int d = 0; d < numberDimensions; d++) {
            final double value = (j == 0) ? 0 : parameters.get((j -  1) * numberDimensions + d);
            result.set(d, value);
        }
        
        log.format("j %d parameters %s%n", j, parameters);
        log.format("result %s%n", result);
        return result;
            
    }
    
    // predict returning most likely
    public double predict(Tensor example) {
        if (example.getNDimensions() != 1)
            throw new IllegalArgumentException("example must be 1D; example=" + example);
        if (example.getSize(0) != numberDimensions)
            throw new IllegalArgumentException("example must have " + numberDimensions + " dimensions; example=" + example);
        
        double maxProbability = 0;
        double bestIndex = -1;
        for (int j = 0; j <= numberClasses; j++) {
            double thisProbability = prob(example, j, trainedParameters);
            if (maxProbability < thisProbability) {
                maxProbability = thisProbability;
                bestIndex = j;
            }
        }
        if (bestIndex == -1)
            throw new RuntimeException("bad code");
        
        return bestIndex;
    }
    
    // run one epoch and return the resulting parameter vector
    public Tensor iterate() {
        // stochastic gradient runs one epoch and returns the resulting parameter vector
        return stochasticGradient.iterate();
    }
    

    // train to difference in parameter vector is smaller than tolerance
    public void train(double tolerance) {
        Log log = new Log("LogisticRegression.train", true);

        Tensor currentParameters;
        Tensor updatedParameters;
        int epochs = 0;
        while (true) {
            // copy current parameters, since stochasticGradient makes no guarantees about over-writing
            currentParameters = Tensor.newInstance(stochasticGradient.getParameters());
            log.println("currentParameters=" + currentParameters);
            updatedParameters = iterate();   // run one training epoch (overall all training examples)
            log.println("updatedParameters=" + updatedParameters);
            double distance = Tensor.dist(currentParameters, updatedParameters);
            epochs++;
            log.format("distance %17.15f epochs %d", distance, epochs);
            if (distance < tolerance)
                break;
        }
        trainedParameters = Tensor.reshape(updatedParameters, numberClasses - 1, numberDimensions);
    }
    
    // negative log of likelihood
    private class MyLossGradient implements LossGradient {
   
        /*
         * Return a new gradient
         * 
         * weights Tensor 1D
         *      current parameters used to calculate the new gradient
         * exampleIndex
         *      the i value, index into examples
         */
        public Tensor apply(Tensor gradientParameters, int exampleIndex) {
            Log log = new Log("LogisticRegression.MyLossGradient.apply", true);
            log.format("example index %d parameters %s%n", exampleIndex, gradientParameters);
            if (gradientParameters.getNDimensions() != 1)
                throw new IllegalArgumentException("gradient parameters must be 1D; parameters=" + gradientParameters);
            gradientParameters.reshape(numberClasses - 1, numberDimensions);
            
            Tensor result = new Tensor(numberClasses, numberDimensions);
            // partial L/w_j = \sum_i (P_ij - d_ij) x_i
            // where
            //   d_ij = 1 if observation i has class j
            //          o otherwise
            //   P_ij = Prob(Y_i = j | x_i) = exp(weights^T x_i)/(1 + \sum_{k=1}^J (weights^T x_k)
            for (int j = 1; j <= numberClasses; j++) {
                double dij = (classes.get(exampleIndex) == j) ? 1.0 : 0.0;
                double pij = prob(exampleIndex, j, gradientParameters); // 
                log.format("exampleIndex %d j %d dij %f pij %5.2f %n", exampleIndex, j, dij, pij);
                for (int k = 0; k < numberDimensions; k++) {
                    result.set(j, k, (pij - dij) * features.get(exampleIndex, k));
                }
                log.format("j %d result %s%n", j, result);
                int x = 1/0;
            }
            return result;
        }

    }
    
    
    // return probability that observation i has class j given the current betas
    // called for i = 0, 1, ..., n and j = 0, 1, 2, ..., numberClasses
    // prob(y_i = j | x_i) = exp(beta_j^T x_i) / \sum_{k=0}^J exp(beta_k^T x_i)
    // the code derives x_i using parameter i and the this.features
    private double prob(int i, int j, Tensor parameters) {
        Log log = new Log("LogisticRegression.MyLossGradient.prob", true);
        if (i < 0 || i > numberObservations)
            throw new IllegalArgumentException("i not in [0,numberObservations-1]; i=" + i);
        if (j < 0)
            throw new IllegalArgumentException("j >= 0; j=" + j);
        if (j > numberClasses)
            throw new IllegalArgumentException("j exceeds number classes (" + numberClasses + "); j=" + j);
        if (parameters.getNDimensions() != 1)
            throw new IllegalArgumentException("parameters must be 1D; parameters=" + parameters);
        
        log.format("i %d j %d parameters %s%n", i, j, parameters);
        double numerator = 0;
        double denominator = 0;
        // determine b_j^T x_i
        for (int k = 0; k <= numberClasses; k++) {
            // set term = beta_k^T x_i
            Tensor beta_k = beta(parameters, k);
            log.format("beta_%d %s%n", k, beta_k);
            double term = 0;
            // dot product of betas[correct portion] and features
            for (int d = 0; d < numberDimensions; d++) {
                log.format("i %d j %d k %d d %d%n", i, j, k, d);
                term += beta_k.get(d) * features.get(i,d);
            }
            
            double expTerm = Math.exp(term);
            denominator += expTerm;
            if (k == j)
                numerator = expTerm;
        }
        if (numerator == 0)
            throw new RuntimeException("numerator should not be zero and is; numerator=" + numerator);
        log.format("numerator %f denominator %f%n", numerator, denominator);
        return numerator / denominator;        
    }
    
    // return probability of the example being in class J using the trained parameters
    private double prob(Tensor example, int j, Tensor parameters) {
        if (example.getNDimensions() != 1)
            throw new IllegalArgumentException("example must be 1D; example=" + example);
        if (example.getSize(0) != numberDimensions)
            throw new IllegalArgumentException("example must have size " + numberDimensions + "; example=" + example);
        if (j < 1)
            throw new IllegalArgumentException("j < 1; j=" + j);
        if (parameters.getNDimensions() != 1)
            throw new IllegalArgumentException("parameters must be 1D; parameters=" + example);
        if (parameters.getSize(0) != numberParameters)
            throw new IllegalArgumentException("parameters must have size " + numberParameters + "; parameters=" + parameters);
        
        // replace the first training feature temporarily
        Tensor temp = new Tensor(numberDimensions);
        for (int d = 0; d < numberDimensions; d++) {
            temp.set(d, features.get(0,d));
            features.set(0,d, example.get(d));
        }
        
        double result = prob(0, j, parameters);
        
        // restore the first feature
        for (int d = 0; d < numberDimensions; d++)
            features.set(0,d, temp.get(d));
        
        return result;
        
    }


    private double probOLD(Tensor example, int j, Tensor weights) {
        if (example.getNDimensions() != 1)
            throw new IllegalArgumentException("example must be 1D; example=" + example);

        double numerator = 0;
        double denominator = 1;
        for (int k = 0; k < numberClasses - 1; k++) {
            double term = Tensor.dot(weights, example);
            denominator += term;
            if (k == j)
                numerator = term;
        }
        return numerator / denominator;        
    }
}
