package com.roylowrance.thesis;

import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import com.roylowrance.util.CsvReader;
import com.roylowrance.util.CsvWriter;
import com.roylowrance.util.DataFrame;
import com.roylowrance.util.Log;
import com.roylowrance.util.Tensor;

// maintain a nearest neighbors cache on disk
// the disk file is a CSV file
// the map contains the indices of the transactions, not the transactions themselves
// so there is an issue of being sure that the map is correct for the problem
// caller must solve that problem


public class NearestNeighborsCache {
    private Map<Integer,ArrayList<Integer>> map = new HashMap<Integer,ArrayList<Integer>>();
    final int maxValuesPerKey = 256;
    final String delimiter = "|";
    final String regex = "\\|";
    final int endOfValuesSentinel = -1;  // can never be a value in the map
    
    // construct a new empty cache
    public NearestNeighborsCache() {
    }
    
    // return keys
    public Set<Integer> keySet() {
        return map.keySet();
    }
    
    // return number of key-value pairs in map
    public int size() {
        return map.size();
    }
    
    // return true iff map contains the key
    public boolean containsKey(int key) {
        return map.containsKey(key);
    }
    
    // return the list of values associated with the key
    public ArrayList<Integer> get(int key) {
        if (key < 0)
            throw new IllegalArgumentException("key < 0; key=" + key);
        return map.get(key);
    }
    
    // associate the key with the list of values
    // don't expand too short a list to full size
    public ArrayList<Integer> put(int key, ArrayList<Integer> values) {
        Log log = new Log("NearestNeighborsCache.put", false);
        log.println("key:" + key);
        log.println("values:" + values);
        log.println("value.size:" + values.size());
        // key must be non negative
        if (key < 0)
            throw new IllegalArgumentException("key < 0; key=" + key);
        
        // not too many values
        final int numValues = values.size();
        if (numValues > maxValuesPerKey)
            throw new IllegalArgumentException("no more than " + maxValuesPerKey + " implemented; values=" + values);
       
        return map.put(key, values);
    }
    
    // put keys and values in CSV file into the cache
    // throws if key is already in the cache
    // return number of records added to the map
    public int putFromCsv(String filePath) {
        Log log = new Log("NearestNeighborsCache.read", false);

        // read the CSV file into Tensor t
        Tensor t = null;
        CsvReader csvReader = new CsvReader(filePath, regex);
        DataFrame df = csvReader.readAll();
        t = df.getTensor();
        csvReader.close();
        log.println("t:" + t);
        
        // validate t
        final int numberRows = t.getSize(0);
        final int numberColumns = t.getSize(1);
        if (numberColumns != maxValuesPerKey + 1)
            throw new IllegalArgumentException("file mis-structured; numberColumns=" + numberColumns);
        
        // append to the map
        int countAdded = 0;
        for (int rowIndex = 0; rowIndex < numberRows; rowIndex++) {
            double keyValue = t.get(rowIndex, 0);
            if (keyValue < 0)
                throw new RuntimeException("keyValue < 0; keyValue=" + keyValue);
            if (Math.floor(keyValue) != keyValue)
                throw new RuntimeException("keyValue not an integer; keyValue=" + keyValue);
            
            ArrayList<Integer> values = new ArrayList<Integer>();
            for (int columnIndex = 1; columnIndex < numberColumns; ++columnIndex) {
                double columnValue = t.get(rowIndex, columnIndex);
                if (columnValue == -1) {
                    // signals the end of the values
                    break;
                }
                if (columnValue < 0)
                    throw new RuntimeException("columnValue < 0; columnValue=" + columnValue);
                if (Math.floor(columnValue) != columnValue)
                    throw new RuntimeException("columnValue not an integer; columnValue=" + columnValue);
                    
                values.add((int)columnValue);
            }
            if (map.containsKey((int)keyValue))
                throw new RuntimeException("key is already in map; keyValue=" + keyValue);
            map.put((int)keyValue, values);
            countAdded++;
        }
        return countAdded;
    }
    
    // write cache as CSV to filePath
    // return number of data records written
    public int write(String filePath) {
        Log log = new Log("NearestNeighborsCache.write", false);
        CsvWriter csvWriter = null;
        csvWriter = new CsvWriter(filePath, delimiter);
        
        // build up and write the header
        String[] header = new String[maxValuesPerKey + 1];
        header[0] = "index";
        for (int i = 0; i < maxValuesPerKey; i++) {
            header[i+1] = Integer.toString(i);
        }
        csvWriter.writeRow(header);
        
        // write each row
        // pad with the sentinel value if the row is shorter than maxValuesPerKey
        // NOTE: keys (column 0) are in random order, so if you examine the csv set looking for 
        // keys in order, you are not likely to find this!
        int recordsWritten = 0;
        for (int key : map.keySet()) {
            ArrayList<Integer> values = map.get(key);
            String[] row = new String[maxValuesPerKey + 1];
            row[0] = Integer.toString(key);
            final int numberEntries = values.size();
            for (int i = 0; i < numberEntries; i++)
                row[i + 1] = Integer.toString(values.get(i));
            if (numberEntries < maxValuesPerKey) {
                for (int i = numberEntries; i < maxValuesPerKey; i++) {
                    row[i + 1] = Integer.toString(endOfValuesSentinel);
                }
            }
            log.println("row:" + row);
            csvWriter.writeRow(row);
            recordsWritten++;
        }
        
        // close the underlying file
        csvWriter.close();
        return recordsWritten;
    }
        
    
        
}
