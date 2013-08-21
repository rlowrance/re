package com.roylowrance.thesis;

import java.util.ArrayList;
import java.util.Random;

import com.roylowrance.util.Tensor;

import com.roylowrance.util.Log;
import com.roylowrance.util.RandomGenerate;

// Functor to determine if gradient functor is well formed by testing
// f(r+a) ~= f(r) + dot(a, grad(r))
// 
// Overview:
// cg = CheckGradient(weightSize, xSize);
// Tensor xs = cg.getRandomXs(); // return 2D
// Tensor ys = cg.getRandomYs(); // return 1D
// cg.testGradient(function, gradient, tolerance); 
public class CheckGradient {
    private int weightSize;
    private int xSize;
    
    private Random random;
    private Tensor xs; // 2D
    private Tensor ys; // 1D
    
    private int rIndex = 0;
    private int rPlusAIndex = 1;
    
    public CheckGradient(int weightSize, int xSize) {
        if (weightSize < 1)
            throw new IllegalArgumentException("weightSize < 1; weightSize=" + weightSize);
        if (xSize < 1)
                throw new IllegalArgumentException("sSize < 1; sSize=" + xSize);        

        this.weightSize = weightSize;
        this.xSize = xSize;
        
        random = new Random(27);
        
        // generate xs and ys
        Tensor x = randomTensor(xSize);
        double y = random.nextGaussian();
        
        xs = new Tensor(1,xSize);
        for (int i = 0; i < xSize; i++)
            xs.set(0, i, x.get(i));
        
        ys = new Tensor(1);
        ys.set(0, y);
    }
    
    public Tensor getXs() {
        return xs;
    }
    
    public Tensor getYs() {
        return ys;
    }
    
    // throw if gradient does not satisfy Taylor's expansion:
    // in 1D: f(x) = f(a) + f'(x)  * (x -a) 
    // in 2D: f(x,y) = f(a,b) + f_x(a,b) * (x - a) + f_y(a,b) * (y - b)
    // where f_x is the partial derivative
    // in multiple D: f(x) = f(a) + (x-a)^T Df(a)
    // in multiple D: f(r+a) = f(r) + dot(a, grad(r)) (from: http://mathworld.wolfram.com/TaylorSeries.html)
    // to within some tolerance
    // Here, 
    //   f(w) = lossFunction.apply(w, x, y)
    //   grad(w) = lossGradient.apply(w, x, y)
    public void apply(LossFunction lossFunction, LossGradient lossGradient, double tolerance) {
        Log log = new Log("CheckGradient.apply", true);


        // r and a are weights
        Tensor r = randomTensor(weightSize);
        Tensor a = Tensor.div(randomTensor(weightSize),1e6); // a small amount
        
        log.println("ys:" + ys);
        log.println("r:" + r);
        log.println("a:" + a);

        final int exampleIndex = 0;
        final Tensor rPlusA = Tensor.add(r,a);
        final double fRPlusA = lossFunction.apply(rPlusA, exampleIndex);
        final double fR = lossFunction.apply(r, exampleIndex);
        final Tensor gradientR = lossGradient.apply(r, exampleIndex);
        final double rhs = fR + Tensor.dot(a, gradientR);
        final double difference = fRPlusA - rhs;

        log.println("r+a=" + rPlusA);
        log.println("f(r+a)=loss(r+a,x,y)" + fRPlusA);
        log.println("f(r)=loss(r,x,y)=" + fR);
        log.println("gradient(r)=lossGradient(r,x,y)" + gradientR);
        log.println("rhs=f(r)+a.gradient(r)=" + rhs);
        log.println("difference=" + difference);
        log.println("tolerance=" + tolerance);
        if (Math.abs(difference) < tolerance)
            return;
        throw new RuntimeException("gradient did not pass test; run with logging to see diagnostics");
    }
    
    // return 1D Tensor with random elements drawn from N(0,1)
    // each element is drawn from N(0,1)
    private Tensor randomTensor(int size) {
        Tensor result = new Tensor(size);
        for (int i = 0; i < size; i++)
            result.set(i, random.nextGaussian());  // drawn from N(0,1)
        
        return result;
    }

}
