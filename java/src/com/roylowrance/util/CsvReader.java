package com.roylowrance.util;

import java.io.IOException;
import java.util.ArrayList;

// read from a comma separated values file
// mimic the API for Python's csvreader class
public class CsvReader {
    private String separatorRegex;
    private LineScanner lineScanner; // avoid bug in java's scanner class
 
    public CsvReader(String filePath, String separatorRegex) {
        Log log = new Log("CsvReader.CsvReader", false);
        log.println("filePath:" + filePath);
        this.separatorRegex = separatorRegex;
        this.lineScanner = new LineScanner(filePath);
    }
    
    public void close() {
        try {lineScanner.close();}
        catch (IOException e) {e.printStackTrace(); throw new RuntimeException();}
    }
    
    // return all the rows as a 2D tensor and field names
    public DataFrame readAll() {
        if (!this.hasNext())
            throw new RuntimeException("csv file has no header record");
        ArrayList<String> header = this.next();
        
        ArrayList<Tensor> rows = new ArrayList<Tensor>();
        int numberRead = 0;
        while (this.hasNext()) {
            ArrayList<String> elements = this.next();
            numberRead = elements.size();
            Tensor row = new Tensor(numberRead);
            for (int i = 0; i < numberRead; i++) 
                row.set(i, Double.valueOf(elements.get(i)));
            rows.add(row);
        }
        
        Tensor tensor = new Tensor(rows.size(), numberRead);
        for (int i = 0; i < rows.size(); i++)
            for (int j = 0; j < numberRead; j++)
                tensor.set(i, j, rows.get(i).get(j));
        
        return new DataFrame(header, tensor);
    }
    
    // return the only columns as a tensor and field name
    public DataFrame readOnlyColumn() {
        if (!this.hasNext())
            throw new RuntimeException("csv file has no header record");
        ArrayList<String> header = this.next();
        if (header.size() != 1)
            throw new RuntimeException("should be only 1 field in header but are " + header.size());
        
        // read the data into a list
        ArrayList<Double> rows = new ArrayList<Double>();
        int numberRead = 0;
        while (this.hasNext()) {
            ArrayList<String> elements = this.next();
            numberRead = elements.size();
            if (numberRead != 1)
                throw new RuntimeException("should be only 1 field in data row but are " + numberRead);
            rows.add(Double.valueOf(elements.get(0)));
        }
        
        // convert the list to a 1D tensor
        Tensor tensor = new Tensor(rows.size());
        for (int i = 0; i < rows.size(); i++)
            tensor.set(i, rows.get(i));
        
        return new DataFrame(header, tensor);
    }
    
    // return next row (as list of Strings) parsing out the delimiter
    public ArrayList<String> next() {
        String nextRow = null;
        nextRow = lineScanner.nextLine();
        
        String[] fields = nextRow.split(separatorRegex, -1); // -1 forces return of trailing empty fields
        ArrayList<String> result = new ArrayList<String> ();
        for (String field : fields) 
            result.add(field);
        return result;
    }
    
    // return true iff there is another row
    // each row has its own line
    public boolean hasNext() {
        return lineScanner.hasNextLine(); 
    }

}
