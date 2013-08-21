package com.roylowrance.util;
// overview: write a csv file
// t = CsvWriter(filepath, delimiter);
// t.close();
// t.writeRow(Double...values);
// t.writeRow(String[] values);
// t.writeRow(Tensor t1D);
// t.writeRows(Tensor t); t can be 1D or 2D

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;

// write a comma separated values file
// mimic the API for Python's csvwriter class
public class CsvWriter {
    private String delimiter;
    private File file;
    private PrintWriter printWriter;
    
    public CsvWriter(String filePath, String delimiter) {
        this.delimiter = delimiter;
        this.file = new File(filePath);
        try {this.printWriter = new PrintWriter(file);}
        catch (IOException e){e.printStackTrace(); throw new RuntimeException();}
    }
    
    public void close() {
        this.printWriter.close();
    }
    
    // write row of double value
    public void writeRow(Double...values) {
        boolean firstElementInRow = true;
        for (double value : values) {
            if (firstElementInRow) 
                firstElementInRow = false;
            else
                printWriter.print(delimiter);
            printWriter.print(value);
        }
        printWriter.println();  // write final new line
    }
    
    // write row that the caller has formatted into one string
    public void writeRow(String value) {
        printWriter.println(value);
    }
    
    // write row of ascii values, for example, the header record
    public void writeRow(String[] values) {
        final boolean logging = false;
        Log log = new Log("CsvWriter.writeRow", logging);
        log.println("values:" + values);
        if (logging) {
            for (int i = 0; i < values.length; i++)
                log.println("values[" + i + "]:" + values[i]);
        }
        boolean firstElementInRow = true;
        for (String value : values) {
            if (firstElementInRow)
                firstElementInRow = false;
            else
                printWriter.print(delimiter);
            printWriter.print(value);
        }
        printWriter.println();  // write final new line character
    }
    
    // write row of value from a 1D Tensor, for example, a data line
    public void writeRow(Tensor t) {
        if (t.getNDimensions() != 1)
            throw new IllegalArgumentException("t must be 1D; t=" + t);
        boolean firstElementInRow = true;
        for (int index = 0; index < t.getSize(0); index++) {
            if (firstElementInRow)
                firstElementInRow = false;
            else
                printWriter.print(delimiter);
            printWriter.print(t.get(index));
        }
        printWriter.println(); // write final new line character
    }
    
    // write rows of doubles, each converted to its ascii representation
    // usually call writeRow(fieldNames) first to write the header
    public void writeRows(Tensor tensor) {
        Log log = new Log("CsvWriter.writeRows", true);
        if (tensor.getNDimensions() == 1)
            writeRows1D(tensor);
        else if (tensor.getNDimensions() == 2)
            writeRows2D(tensor);
        else 
            throw new IllegalArgumentException("tensor not 1D or 1D; tensor=" + tensor);
    }
    
    private void writeRows1D(Tensor tensor1D) {
        Log log = new Log ("CsvWriter.writeRows1D", false);
        log.format("%17.15f%n", tensor1D.get(0));
        final int numberRows = tensor1D.getSize(0);
        for (int rowNumber = 0; rowNumber < numberRows; rowNumber++) {
            // printWrite.println(double) uses the E notation, so that
            // values will not be printed correctly
            printWriter.println(tensor1D.get(rowNumber));
        }
    }
    
    private void writeRows2D(Tensor tensor2D) {
        final int numberRows = tensor2D.getSize(0);
        final int numberColumns = tensor2D.getSize(1);
        for (int rowNumber = 0; rowNumber < numberRows; rowNumber++) {
            boolean firstElementInRow = true;
            for (int columnNumber = 0; columnNumber < numberColumns; columnNumber++) {
                if (firstElementInRow)
                    firstElementInRow = false;
                else
                    printWriter.print(delimiter);
                printWriter.print(tensor2D.get(rowNumber, columnNumber));
            }
            printWriter.println();
        }
    }

}
