package com.roylowrance.util.test;

import static org.junit.Assert.*;

import org.junit.Before;
import org.junit.Test;

import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.ArrayList;

import com.roylowrance.util.CsvReader;
import com.roylowrance.util.CsvWriter;
import com.roylowrance.util.DataFrame;
import com.roylowrance.util.Tensor;

public class CsvReaderWriterTest {

    @Before
    public void setUp() throws Exception {
    }

    private String[] makeHeader() {
        String[] result = {"a", "b", "c"};
        return result;
    }
    
    private Tensor makeData() {
        Tensor result = new Tensor(2,3);
        for (int row = 0; row < 2; row++)
            for (int column = 0; column < 3; column++)
                result.set(row, column, 10 * row + column);
        return result;
    }
    
    @Test // write csv then read it back in
    public void testCsvReaderWriter() throws FileNotFoundException, IOException {
        String filePath = "/home/roy/temp_files/CsvReaderWriterTest.csv";
        String delimiter = "|";
        CsvWriter csvWriter = new CsvWriter(filePath, delimiter);
        String[] header = makeHeader();
        csvWriter.writeRow(header);
        
        Tensor data = makeData();
        csvWriter.writeRows(data);
        csvWriter.close();
        System.out.println("check file:" + filePath);
        
        // read a row at a time
        String separatorRegex = "\\|";
        {
            CsvReader csvReader = new CsvReader(filePath, separatorRegex);

            ArrayList<String> headers = csvReader.next();
            assertEquals("a", headers.get(0));
            assertEquals("b", headers.get(1));
            assertEquals("c", headers.get(2));

            assertTrue(csvReader.hasNext());
            ArrayList<String> row = csvReader.next();
            assertEquals("0.0", row.get(0));
            assertEquals("1.0", row.get(1));
            assertEquals("2.0", row.get(2));

            assertTrue(csvReader.hasNext());
            row = csvReader.next();
            assertEquals("10.0", row.get(0));
            assertEquals("11.0", row.get(1));
            assertEquals("12.0", row.get(2));

            assertFalse(csvReader.hasNext());
        }
        
        // read all at once
        {
            CsvReader csvReader = new CsvReader(filePath, separatorRegex);
            DataFrame df = csvReader.readAll();
            
            ArrayList<String> headers = df.getNames();
            assertEquals("a", headers.get(0));
            assertEquals("b", headers.get(1));
            assertEquals("c", headers.get(2));
            
            Tensor tensor = df.getTensor();
            for (int i = 0; i < tensor.getSize(0); i++)
                for (int j = 0; j < tensor.getSize(1); j++)
                    assertEquals(10 * i + j, tensor.get(i,j), 0);
        }
        
        
        
    }

}
