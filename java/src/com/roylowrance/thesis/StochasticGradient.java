package com.roylowrance.thesis;

/*
Overview:

class MyLossGradient implements LossGradient {
     @Override public function apply(Tensor weights, int exampleIndex) {...}
 }
 
StochasticGradient sg = new StochasticGradient(xs, ys, d, new MyLossGradient(), ...);
boolean converted = false;
while (!converged) {
    Tensor updatedParameters = sg.iterate();  // one epoch (use each training sample)
}
 */

import java.util.ArrayList;
import java.util.Collections;
import java.util.Random;

import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

// stochastic gradient descent
// modeled on Torch's StochasticGradient class
// ref: http://www.torch.ch/manual/nn/index
//
// Implements (as an option) the stochastic average gradient (SAG) as described in
// leroux-12 "Stochastic Gradient Method With Exponential Convergence Rate"
// which requires that the loss function be strongly convex

// Another reference is Leon Bottou's presentation
// http://learning.stat.purdue.edu/mlss/_media/mlss/bottou.pdf

// Overview
// sg = StochasticGradient(...)
//      construct
// parameters = sg.iterate()
//      perform one epoch (over each training example)
//      decide whether to stop or continue with further iterations
// parameters = sg.iterate(N)
//      perform N epochs

public class StochasticGradient {
    private Tensor xs; // 2D: size n x k
    private Tensor ys; // 1D: size n
    private int gradientSize;
    private LossGradient gradient;
    private double learningRate;
    private double learningRateDecay;
    private boolean shuffleIndices;
    private HookExample hookExample;
    private HookIteration hookIteration;
    private boolean useStochasticAverageGradient;

    private int numberExamples;
    private int epochNumber;
    private Tensor parameters; // the weights

    private ArrayList<Integer> indices;
    private Random random;
    private Tensor[] priorStochasticGradients;

    /**
     * Return initialized StochasticGradient instance for subsequent iteration.
     * 
     * @param xs
     *            Tensor 2D xs[i:] are the training features for observation i
     * @param ys
     *            Tensor 1D ys[i] is the observed response for features xs[i:]
     * @param gradientSize
     *            number of elements in the gradient (the size of the weight vector)
     * @param gradient
     *            gradient of the loss function
     * @param learningRate
     *            the update is w := w - learningRate * gradient(w)
     * @param learningRateDecay
     *            if not zero, the learningRate is decayed according to currentLearningRate := learningRate / (1 + epochNumber +
     *            learningRateDecay)
     * @param shuffleIndices
     *            if true, the xs and ys are shuffled before each epoch
     * @param hookExample
     *            if not null, called after each example has been handled hookExample.apply(this, x, y)
     * @param hookIteration
     *            if not null, called after each epoch has completed hookIteration.apply(this, epochNumber)
     * @param useStochasticAverageGradient
     *            if true, the update is a stochastic average gradient see leroux-12
     *            "Stochastic Gradient Method with Exponential Convergence Rate ..." One randomly-selected stochastic gradient is computed
     *            on each iteration and the full gradient is formed, using the previous randomly-selected gradients
     */
    public StochasticGradient(Tensor xs, Tensor ys, int gradientSize, LossGradient gradient, double learningRate, double learningRateDecay,
            boolean shuffleIndices, HookExample hookExample, HookIteration hookIteration, boolean useStochasticAverageGradient) {
        Log log = new Log("StochasticGradient", true);

        // validate and save parameters
        if (xs.getNDimensions() != 2)
            throw new IllegalArgumentException("xs must be 2D; xs=" + xs);
        this.xs = xs;

        if (ys.getNDimensions() != 1)
            throw new IllegalArgumentException("ys must be 1D; ys=" + ys);
        this.ys = ys;

        this.gradientSize = gradientSize;
        this.gradient = gradient;
        this.learningRate = learningRate;
        this.learningRateDecay = learningRateDecay;
        this.shuffleIndices = shuffleIndices;
        this.hookExample = hookExample;
        this.hookIteration = hookIteration;
        this.useStochasticAverageGradient = useStochasticAverageGradient;

        // further initialization
        this.numberExamples = xs.getSize(0);
        log.println("numberExamples:" + numberExamples);

        if (useStochasticAverageGradient) {
            // initialize prior stochastic gradient values to all nulls
            for (int i = 0; i < numberExamples; i++)
                priorStochasticGradients[i] = null;
        }

        this.epochNumber = 0;

        // initialize the parameters to zero
        this.parameters = new Tensor(gradientSize);

        // initial the indices
        indices = new ArrayList<Integer>();
        for (int i = 0; i < numberExamples; i++)
            indices.add(i);

        // the indices may be shuffled
        // if so, seed the random generator used by the shuffle method so that results
        // are reproducible
        final long randomSeed = 27;
        random = new Random(randomSeed);

    }

    public Tensor getParameters() {
        return parameters;
    }

    // called after each example has been run
    // return true if the iteration should terminate
    public interface HookExample {
        public boolean apply(StochasticGradient sgd, Tensor x, double y);
    }

    // called after each epoch (pass through all examples)
    public interface HookIteration {
        public boolean apply(StochasticGradient sgd, int iterationNumber);
    }

    /**
     * Perform an epoch, by running throw all training examples, updating parameters := parameters - currentLearningRate *
     * gradient(parameters,x,y)
     * 
     * @return parameters at end of epoch
     */
    public Tensor iterate() {
        Log log = new Log("StochasticGradient.iterate", true);
        epochNumber++;
        double currentLearningRate = (learningRateDecay == 0.0) ? learningRate : (learningRate / (1.0 + epochNumber + learningRateDecay));
        if (shuffleIndices) {
            Collections.shuffle(indices, random);
        }
        log.println("numberExamples:" + numberExamples);
        for (int i = 0; i < numberExamples; i++) {
            int exampleIndex = indices.get(i);
            log.println("exampleIndex:" + exampleIndex);
            // parameters = parameters - currentLearningRate * gradient
            Tensor exampleFeatures = xs.selectRow(exampleIndex);
            double exampleValue = ys.get(exampleIndex);

            log.println("parameters before update       :" + parameters);
            log.println("exampleIndex                   :" + exampleIndex);
            Tensor stochasticGradient = gradient.apply(parameters, exampleIndex);
            log.println("exampleFeatures                :" + exampleFeatures);
            log.println("exampleValue                   :" + exampleValue);
            log.println("stochastic gradient at example :" + stochasticGradient);
            log.println("current learning rate          :" + currentLearningRate);
            if (useStochasticAverageGradient) {
                priorStochasticGradients[i] = stochasticGradient; // save just-computed value
                // update parameters using all the prior stochastic gradients from all the examples
                // approximate gradient with known last stochastic values
                for (int j = 0; j < numberExamples; j++) {
                    if (priorStochasticGradients[j] == null) {
                        // we haven't yet computed a gradient for example j
                        // an alternative is to compute and save the stochastic gradient
                        continue;
                    }
                    // use any known prior stochastic gradients
                    for (int k = 0; k < gradientSize; k++)
                        parameters.set(k, parameters.get(k) - currentLearningRate * priorStochasticGradients[j].get(k));
                }
            } else {
                // not using stochastic average approach
                for (int k = 0; k < gradientSize; k++) {
                    parameters.set(k, parameters.get(k) - currentLearningRate * stochasticGradient.get(k));
                }
            }

            log.println("parameters after update :" + parameters);
            // call the example hook function
            if (hookExample != null) {
                if (hookExample.apply(this, exampleFeatures, exampleValue))
                    return parameters;
            }
        }
        return parameters;
    }

    // return parameters after iterating a pre-specified number of epochs
    public Tensor iterate(int numberEpochs) {
        Log log = new Log("StochasticGradient.iterate(int)", false);
        log.println("numberEpochs:" + numberEpochs);
        for (int epoch = 0; epoch < numberEpochs; epoch++) {
            this.iterate();
            if (hookIteration != null) {
                if (hookIteration.apply(this, epoch))
                    return parameters;
            }
        }

        return parameters;
    }
}
