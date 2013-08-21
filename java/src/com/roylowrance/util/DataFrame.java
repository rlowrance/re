package com.roylowrance.util;

import java.util.ArrayList;
import java.util.HashMap;

// a tensor with column (feature) names
// mimic's R's data.frame
public class DataFrame {
    private ArrayList<String> names;
    private Tensor tensor;
    
    private HashMap<String,Integer> indexOfName;
    
    // construct from a list of column names (1 or more)
    // Tensor can be 1D or 2D
    public DataFrame(ArrayList<String> columnNames, Tensor tensor) {
        final int numberColumns = columnNames.size();
        if (numberColumns < 1)
            throw new IllegalArgumentException("must have at least one column; numberColumns=" + numberColumns);
        
        final int dimensions = tensor.getNDimensions();
        if (dimensions != 1 && dimensions != 2)
            throw new IllegalArgumentException("tensor must be 1D or 2D; tensor=" + tensor);
        
        if (numberColumns > 1 && dimensions == 1)
            throw new IllegalArgumentException(">1 column name but only 1D tensor; columnNames=" + columnNames + "tensor=" + tensor);

        this.names = columnNames;
        this.tensor = tensor;
        
        // build the map from column names to column numbers
        indexOfName = new HashMap<String,Integer> ();
        for (int columnIndex = 0; columnIndex < numberColumns; columnIndex++) {
            indexOfName.put(columnNames.get(columnIndex), columnIndex);
        }
    }
    
    public ArrayList<String> getNames() {
        return names;
    }
    
    public Tensor getTensor() {
        return tensor;
    }
    
    public int getColumnIndex(String columnName) {
        if (indexOfName.containsKey(columnName))
            return indexOfName.get(columnName);
        throw new IllegalArgumentException("columnName (" + columnName + ") not in DataFrame");
    }
    
    // return new 1D tensor with specified name
    public Tensor getColumnNamed(String columnName) {
        Log log = new Log("DataFrame.getColumnNames", false);
        final int columnNumber = this.getColumnIndex(columnName);
        log.println("columnNumber:" + columnNumber);
        final int numberRows = tensor.getSize(0);
        Tensor result = new Tensor(numberRows);
        log.println("tensor:" + tensor);
        log.println("result:" + result);
        for (int rowNumber = 0; rowNumber < numberRows; rowNumber++)
            result.set(rowNumber, tensor.get(rowNumber, columnNumber));
        return result;
    }

}
