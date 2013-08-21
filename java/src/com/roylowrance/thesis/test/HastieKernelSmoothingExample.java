package com.roylowrance.thesis.test;

import java.io.FileNotFoundException;
import java.io.PrintWriter;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.roylowrance.thesis.Dir;
import com.roylowrance.thesis.Distance;
import com.roylowrance.thesis.DistanceEuclidean;
import com.roylowrance.thesis.Hp;
import com.roylowrance.thesis.Kernel;
import com.roylowrance.thesis.KernelEpanechnikov;
import com.roylowrance.thesis.KNearestNeighbors;
import com.roylowrance.thesis.WeightedAverage;

import com.roylowrance.util.RandomGenerate;
import com.roylowrance.util.Tensor;

public class HastieKernelSmoothingExample {

    /**
     * Implement the example in Hastie page 166 using knn and gaussian kernel
     * 
     * Write file <project>/data/generated-v4/tests/* for plotting with R
     * 
     * @param args not used
     */
    public static void main(String[] args) {
        final int numberObservations = 100;
        Tensor xs = new Tensor(numberObservations, 1);
        Tensor ys = new Tensor(numberObservations);
        
        final double lowestX = 0;
        final double highestX = 1;
        List<Double> xList = RandomGenerate.uniformDoubleValues(lowestX, highestX, numberObservations);
        
        final double noiseMean = 0;
        final double noiseSigma = 1.0 / 3.0;
        List<Double> noise = RandomGenerate.gaussianDoubleValues(noiseMean, noiseSigma, numberObservations);
        
        for (int index = 0; index < numberObservations; ++index) {
            final double x = xList.get(index);
            xs.set(index, 0, x);
            ys.set(index, f(x) + noise.get(index));
        }
        
        double rmseNearestNeighbors = nearestNeighbors(xs, ys);
        System.out.println("nearest neighbors rmse = " + rmseNearestNeighbors);
        
        double rmseKwavg = weightedAverage(xs, ys);
        System.out.println("weighted average rmse  = " + rmseKwavg);
    }
    
    static double nearestNeighbors(Tensor xs, Tensor ys) {
        if (xs.getNDimensions() != 2)
            throw new IllegalArgumentException("xs should be 2D; xs=" + xs);
        if (ys.getNDimensions() != 1)
            throw new IllegalArgumentException("ys should be 1D; ys=" + ys);
        final int numberObservations = xs.getSize(0);
        if (numberObservations != ys.getSize(0))    
            throw new IllegalArgumentException("size mismatch");
        
        // determine nearest neighbors
        Distance distance = new DistanceEuclidean();
        NearestNeighborsCache nnc = new NearestNeighborsCache(distance, xs);
        KNearestNeighbors knn = new KNearestNeighbors(distance, xs, ys, nnc);
        final int numberNeighbors = 30;
        Hp hp = new Hp.Builder().k(numberNeighbors).build();
        Tensor yHats = new Tensor(numberObservations);
        for (int queryIndex = 0; queryIndex < numberObservations; queryIndex++) {
            yHats.set(queryIndex, knn.applyExact(hp, queryIndex ));
        }
        
        // write the csv for processing by R
        PrintWriter pw;
        try {pw = new PrintWriter(Dir.project() + "data/generated-v4/tests/HastieKernelSmoothingExample-KNearestNeighbors.csv"); }
        catch (FileNotFoundException e) {throw new RuntimeException(e);}
        pw.println("x|y|yHat");
        for (int i = 0; i < numberObservations; i++) {
            pw.println(xs.get(i,0) + "|" + ys.get(i) + "|" + yHats.get(i));
        }
        pw.close();
        
        return rmse(ys, yHats);
    }
    
    static double weightedAverage(Tensor xs, Tensor ys) {
        if (xs.getNDimensions() != 2)
            throw new IllegalArgumentException("xs must be 2D; xs=" + xs);
        if (ys.getNDimensions() != 1)
            throw new IllegalArgumentException("ys must be 1D; ys=" + ys);
        final int numberObservations = xs.getSize(0);
        if (numberObservations != ys.getSize(0))    
            throw new IllegalArgumentException("size mismatch");
        
        Distance distance = new DistanceEuclidean();
        Kernel kernel = new KernelEpanechnikov();
        Hp hp = new Hp.Builder().bandwidth(0.2).build();
        Tensor yHats = new Tensor(numberObservations);
        for (int queryIndex = 0; queryIndex < numberObservations; queryIndex++) {
            yHats.set(queryIndex, WeightedAverage.apply(distance, kernel, hp, xs, queryIndex, ys));
        }
        
        // write the csv for processing by R
        PrintWriter pw;
        try {pw = new PrintWriter(Dir.project() + "data/generated-v4/tests/HastieKernelSmoothingExample-WeightedAverage.csv"); }
        catch (FileNotFoundException e) {throw new RuntimeException(e);}
        pw.println("x|y|yHat");
        for (int i = 0; i < numberObservations; i++) {
            pw.println(xs.get(i,0) + "|" + ys.get(i) + "|" + yHats.get(i));
        }
        pw.close();
        
        return rmse(ys, yHats);
    }
    
    static double rmse(Tensor a, Tensor b) {
        final int numberObservations = a.getSize(0);
        double sumSquaredErrors = 0;
        for (int i = 0; i < numberObservations; i++) {
            final double error = a.get(i) - b.get(i);
            sumSquaredErrors += error * error;
        }
        final double mse = sumSquaredErrors / numberObservations;
        return Math.sqrt(mse);
    }
    
    static class NearestNeighborsCache implements KNearestNeighbors.KnnCache {
        Map<Integer,ArrayList<Integer>> map;
        
        // constructor
        public NearestNeighborsCache(Distance distance, Tensor xs) {
            map = new HashMap<Integer,ArrayList<Integer>>();
            for (int i = 0; i < xs.getSize(0); i++) {
                map.put(i, neighbors(distance, i, xs));
            }
        }
        
        // methods required by interface KnnCache
        public ArrayList<Integer> get(int index)             { return map.get(index); }
        public void put(int index, ArrayList<Integer> value) { map.put(index, value); }
        public boolean containsKey(int index)                { return map.containsKey(index); }
        public Set<Integer> keySet()                         { return map.keySet(); }
        
        // return the indices of all the nearest neighbors
        private ArrayList<Integer> neighbors(Distance distance, int queryIndex, Tensor xs) {
            List<DistanceIndex> pairs = new ArrayList<DistanceIndex>();
            
            // determine all distances, excluding queryIndex
            for (int i = 0; i < xs.getSize(0); i++) {
                if (i == queryIndex)
                    continue;
                pairs.add(new DistanceIndex(distance.apply(xs, i, queryIndex), i));
            }
            
            Collections.sort(pairs); // sort the pairs
            
            // return the indices from the sorted pairs
            ArrayList<Integer> result = new ArrayList<Integer>();
            for (DistanceIndex pair : pairs) 
                result.add(pair.getIndex());
                    
            return result;
        }
    }
    
    static class DistanceIndex implements Comparable<Object> {
        private double distance;
        private int index;

        // constructor
        public DistanceIndex(double distance, int index) {
            this.distance = distance;
            this.index = index;
        }

        // comparing
        @Override
        public int compareTo(Object other) {
            if (this.distance < ((DistanceIndex) other).distance)
                return -1;
            if (this.distance > ((DistanceIndex) other).distance)
                return 1;
            return 0;
        }

        public double getDistance() {
            return distance;
        }

        // accessors
        public int getIndex() {
            return index;
        }

        @Override
        public String toString() {
            return "Pair(distance=" + distance + ",index=" + index + ")";
        }
    }
    
    // see hastie p 166
    private static double f(double x) {
        return Math.sin(4 * x);
    }

}
