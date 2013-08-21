package com.roylowrance.thesis;
/*
 *  synopsis: a functor that maintains a cache
 *  
 *  to obtain the 256 nearest y values for a query point:
 *  Nearest256Ys n256ys = Nearest256Ys(xs, ys, cacheDirPath, cacheFileNameSuffix); // no cache files read
 *  ArrayList<Double> nearest256Ys = n256ys.apply(xsRowIndexToOmit, query);        // save result in cache; reuse on same query
 *  
 *  to maintain the cache:
 *  numberRecordsRead = n256ys.cacheMerge(cacheFileNameSuffix);   // add records in file to current cache
 *  numberRecordsWritten = n256ys.cacheWrite();                   // write the cache to disk using original cacheFileNameSuffix
 */

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;

import com.roylowrance.util.CsvReader;
import com.roylowrance.util.CsvWriter;
import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

// Return list of up to the nearest 256 Y values associated with a pre-defined list of x values
// The xs and ys are previously defined
public class Nearest256Ys {
    public final static int K_MAX = 256;
    private Tensor xs;
    private Tensor ys;
    private String cacheFilePathBase;
    private String cacheFileNameOriginalSuffix;
    
    private HashMap<Tensor, ArrayList<Double>> cache;
    
    // construct but do not read cache files from disk
    public Nearest256Ys(Tensor xs, Tensor ys, String cacheDirPath, String cacheFileNameSuffix) {
        IAE.is2D(xs, "xs");
        IAE.is1D(ys, "ys");
        //IAE.notNull(cacheDirPath, "cacheFilePath");
        IAE.notNull(cacheFileNameSuffix, "cacheFileNameSuffix");
        
        this.xs = xs;
        this.ys = ys;
        
        if (cacheDirPath == null) {
        	cache = null;
        }
        else {
        	this.cacheFilePathBase = cacheDirPath + makeSHA();
        	this.cacheFileNameOriginalSuffix = cacheFileNameSuffix;
        	
        	cache = new HashMap<Tensor, ArrayList<Double>>();
        }
    }
    
    // return list of the nearest 256 y values to the query
    // remember the query and results and re-use if query is presented again
    // the xsRowIndexToOmit can be out of bounds (for example, -1) to indicate that
    // no row in the xs is to be excluded
    public ArrayList<Double> apply(Tensor query, int xsRowIndexToOmit) {
        Log log = new Log("Nearest256Ys.apply", false);
        IAE.notNull(query, "query");
        
        if (cache == null) {
        	log.println("no cache in use: query:" + query);
        }
        else if (cache.containsKey(query)) {
            log.println("found in cache; query:" + query);
            return cache.get(query);
        }
        
        final long startTime = System.nanoTime();
        Distance distance = new DistanceEuclidean();
        
        List<DistanceIndex> pairs = new ArrayList<DistanceIndex>();
        for (int i = 0; i < xs.getSize(0); i++) {
            if (i == xsRowIndexToOmit)
                continue;
            pairs.add(new DistanceIndex(distance.apply(xs, i, query), i));
        }

        // sort the pairs in increasing distance order
        Collections.sort(pairs);

        // return the first K_MAX of the y values
        ArrayList<Double> result = new ArrayList<Double>();
        int inserted = 0;
        for (DistanceIndex pair : pairs) {
            //log.println("pair:" + pair);
            if (inserted >= K_MAX || inserted >= xs.getSize(0))
                break;
            result.add(ys.get(pair.index));
            inserted++;
        }

        final long stopTime = System.nanoTime();
        log.println("elapsed seconds:" + ((stopTime - startTime) / 1e9));
        if (cache != null)
        	cache.put(query, result);
        return result;
        
        
    }
    
    // merge cache on disk with current cache
    // return number of data records in the on-disk cache
    // NOTE: only the queries not seen so far will be actually merged
    public int cacheMerge(String cacheFileNameSuffix) {
        Log log = new Log("Nearest256Ys.cacheMerge", false);
        log.println("cacheFileNameSuffix:" + cacheFileNameSuffix);
        final String separatorRegex = "\\|";
        CsvReader csvreader = new CsvReader(cacheFilePathBase + cacheFileNameSuffix + ".csv", separatorRegex);
        
        // ignore the header
        csvreader.next();
        
        // parse each data row
        int numberRecordsAdded = 0;
        while (csvreader.hasNext()) {
            ArrayList<String> row = csvreader.next();
            log.format("row size %d%n", row.size());
            
            final int dimensions = xs.getSize(1);
            log.format("dimensions %d%n", dimensions);
            Tensor key = new Tensor(dimensions);
            for (int i = 0; i < dimensions; i++) 
                key.set(i, Double.valueOf(row.get(i)));
            
            // append each y value
            // a y value < 0 indicates the value is missing
            // a missing value can arise because a specific x had fewer than 256 neighbors
            ArrayList<Double> yValues = new ArrayList<Double>();
            for (int i = 0; i < K_MAX; i++) {
                double nextValue = Double.valueOf(row.get(dimensions + i));
                if (nextValue >= 0)
                    yValues.add(nextValue);
            }
            
            cache.put(key, yValues);
            numberRecordsAdded++;
        }
        
        csvreader.close();
        return numberRecordsAdded;
    }
    
    // write the cache to disk
    // return number of data records written
    public int cacheWrite() {
        Log log = new Log("Nearest256Ys.cacheWrite", true);
        final String delimiter = "|";
        CsvWriter csvwriter = new CsvWriter(cacheFilePathBase + cacheFileNameOriginalSuffix + ".csv", delimiter);
        
        final int numberDimensions = xs.getSize(1);
        
        // write column names
        String[] columnNames = new String[numberDimensions + K_MAX];
        for (int i = 0; i < numberDimensions; i++)
            columnNames[i] = "t" + (i + 1);
        for (int i = 0; i < K_MAX; i++)
            columnNames[numberDimensions + i] = "y" + (i + 1);
        log.println("number of column names:" + columnNames.length);
        log.println("columnNames:" + columnNames);
        csvwriter.writeRow(columnNames);
        
        
        // write one row for each cache value
        int dataRecordsWritten = 0;
        for (Tensor key : cache.keySet()) {
            Tensor row = new Tensor(numberDimensions + K_MAX);
            for (int i = 0; i < numberDimensions; i++)
                row.set(i, key.get(i));
            List<Double> cachedYs = cache.get(key);
            for (int i = 0; i < K_MAX; i++) {
                // there may be fewer the K_MAX neighbors
                row.set(numberDimensions + i, (i < cachedYs.size()) ? cachedYs.get(i) : -1);
            }
            log.println("data row:" + row);
            csvwriter.writeRow(row);
            dataRecordsWritten++;
        }
        csvwriter.close();
        return dataRecordsWritten;
    }
    
    ////////////////////// private
    
    // hold pairs containing a distance and an index, which is the row in xs
    // used for sorting, so must implement compareTo
    private static class DistanceIndex implements Comparable<Object> {
        public double distance;
        public int index;
        
        public DistanceIndex(double distance, int index) {
            this.distance = distance;
            this.index = index;
        }
        
        @Override public int compareTo(Object other) {
            // order first on distance
            if (this.distance < ((DistanceIndex) other).distance)
                return -1;
            if (this.distance > ((DistanceIndex) other).distance)
                return 1;
            
            // order next on index
            if (this.index < ((DistanceIndex) other).index)
                return -1;
            if (this.index > ((DistanceIndex) other).index)
                return 1;
            
            return 0;
        }
    }
    
    // return SHA message digest as a String
    private String makeSHA() {
        Log log = new Log("Nearest256Ys.makeSHA", true);
        MessageDigest md = null;
        try {
            md = MessageDigest.getInstance("SHA");
        }
        catch (NoSuchAlgorithmException e) {throw new RuntimeException(e);}
        
        // update digest for all the xs and all the ys
        IAE.isNotNull(xs, "xs");
        IAE.isNotNull(ys, "ys");
        for (int i = 0; i < xs.getSize(0); i++) {
            updateDigest(md, ys.get(i));
            for (int j = 0; j < xs.getSize(1); j++)
                updateDigest(md, xs.get(i,j));
        }
        
        byte[] bytes = md.digest();
        // convert the bytes into an equivalent String in hex encoding
        // not:
        //   String result = new String(bytes);
        String result = toHex(bytes);
        log.println("result:" + result);
        return result;
    }
    
    // convert a double value to an array of bytes
    // ref:
    // http://stackoverflow.com/questions/2905556/how-can-i-convert-a-byte-array-into-a-double-and-back
    private byte[] toByteArray(double value) {
        byte[] result = new byte[8];
        ByteBuffer.wrap(result).putDouble(value);
        return result;
    }
    
    // convert bytes to hex representatives in a String
    // ref:
    // http://stackoverflow.com/questions/332079/in-java-how-do-i-convert-a-byte-array-to-a-string-of-hex-digits-while-keeping-l
    public String toHex(byte[] bytes) {
        char[] hexArray = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j*2] = hexArray[v/16];
            hexChars[j*2 + 1] = hexArray[v%16];
        }
        return new String(hexChars);
    }
    
    private void updateDigest(MessageDigest md, double x) {
        byte[] bytes = toByteArray(x);
        md.update(bytes, 0, bytes.length);
    }
}
